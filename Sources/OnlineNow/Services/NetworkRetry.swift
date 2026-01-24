import Foundation
import Combine

/// Configuration for network retry behavior
public struct NetworkRetryConfiguration: Sendable {
    /// Maximum number of retry attempts
    public let maxRetries: Int

    /// Base delay between retries (exponential backoff applied)
    public let baseDelay: TimeInterval

    /// Maximum delay between retries
    public let maxDelay: TimeInterval

    /// Whether to wait for verified connectivity before retrying
    public let waitForConnectivity: Bool

    /// Timeout for the entire retry operation
    public let timeout: TimeInterval?

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        waitForConnectivity: Bool = true,
        timeout: TimeInterval? = nil
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.waitForConnectivity = waitForConnectivity
        self.timeout = timeout
    }

    /// Default configuration for quick operations
    public static let quick = NetworkRetryConfiguration(
        maxRetries: 2,
        baseDelay: 0.5,
        maxDelay: 5.0,
        waitForConnectivity: true,
        timeout: 30
    )

    /// Configuration for critical operations (payments, sync)
    public static let critical = NetworkRetryConfiguration(
        maxRetries: 5,
        baseDelay: 1.0,
        maxDelay: 60.0,
        waitForConnectivity: true,
        timeout: 300
    )

    /// Configuration for background operations
    public static let background = NetworkRetryConfiguration(
        maxRetries: 10,
        baseDelay: 5.0,
        maxDelay: 300.0,
        waitForConnectivity: true,
        timeout: nil
    )
}

/// Result of a network retry operation
public enum NetworkRetryResult<T: Sendable>: Sendable {
    case success(T)
    case failure(NetworkRetryError)

    public var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    public var error: NetworkRetryError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

/// Errors that can occur during network retry operations
public enum NetworkRetryError: Error, Sendable {
    case noConnectivity
    case maxRetriesExceeded(attempts: Int, lastError: Error?)
    case timeout
    case cancelled
    case operationFailed(Error)

    public var localizedDescription: String {
        switch self {
        case .noConnectivity:
            return "No network connectivity available"
        case .maxRetriesExceeded(let attempts, let lastError):
            return "Failed after \(attempts) attempts. Last error: \(lastError?.localizedDescription ?? "Unknown")"
        case .timeout:
            return "Operation timed out"
        case .cancelled:
            return "Operation was cancelled"
        case .operationFailed(let error):
            return "Operation failed: \(error.localizedDescription)"
        }
    }
}

/// A queued operation waiting for connectivity
public struct QueuedOperation<T: Sendable>: Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let description: String
    public let configuration: NetworkRetryConfiguration
    internal let operation: @Sendable () async throws -> T

    public init(
        id: UUID = UUID(),
        description: String,
        configuration: NetworkRetryConfiguration = .quick,
        operation: @escaping @Sendable () async throws -> T
    ) {
        self.id = id
        self.createdAt = Date()
        self.description = description
        self.configuration = configuration
        self.operation = operation
    }
}

/// Network retry helper that automatically queues and retries operations
/// when connectivity is restored
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor NetworkRetry {

    // MARK: - Properties

    private let reachabilityService: ReachabilityService
    private var pendingOperations: [UUID: any QueuedOperationProtocol] = [:]
    private var connectivityTask: Task<Void, Never>?
    private var isMonitoring = false

    /// Publisher for operation queue changes - use from actor context
    private let queueSubject = PassthroughSubject<Int, Never>()

    /// Get a publisher for queue count changes
    /// Note: Access this property from actor context or use async access
    public var queueCountPublisher: AnyPublisher<Int, Never> {
        queueSubject.eraseToAnyPublisher()
    }

    /// Current number of queued operations
    public var queuedCount: Int {
        pendingOperations.count
    }

    // MARK: - Initialization

    public init(reachabilityService: ReachabilityService = ReachabilityService()) {
        self.reachabilityService = reachabilityService
    }

    // MARK: - Public Methods

    /// Execute an operation with automatic retry on failure
    /// - Parameters:
    ///   - description: Human-readable description of the operation
    ///   - configuration: Retry configuration
    ///   - operation: The async operation to execute
    /// - Returns: Result of the operation
    public func execute<T: Sendable>(
        description: String,
        configuration: NetworkRetryConfiguration = .quick,
        operation: @escaping @Sendable () async throws -> T
    ) async -> NetworkRetryResult<T> {

        // First, check if we have connectivity
        let reachability = await reachabilityService.checkReachability()

        if !reachability.isReachable && configuration.waitForConnectivity {
            // Queue the operation and wait for connectivity
            return await queueAndWait(
                description: description,
                configuration: configuration,
                operation: operation
            )
        }

        // Attempt the operation with retries
        return await executeWithRetry(
            configuration: configuration,
            operation: operation
        )
    }

    /// Queue an operation to be executed when connectivity returns
    /// Returns immediately with the operation ID for tracking
    /// - Parameters:
    ///   - description: Human-readable description
    ///   - configuration: Retry configuration
    ///   - operation: The async operation to queue
    /// - Returns: The operation ID for tracking
    public func queue<T: Sendable>(
        description: String,
        configuration: NetworkRetryConfiguration = .quick,
        operation: @escaping @Sendable () async throws -> T
    ) -> UUID {
        let queuedOp = QueuedOperation(
            description: description,
            configuration: configuration,
            operation: operation
        )

        let wrapper = QueuedOperationWrapper(operation: queuedOp)
        pendingOperations[queuedOp.id] = wrapper
        queueSubject.send(pendingOperations.count)

        startMonitoringIfNeeded()

        return queuedOp.id
    }

    /// Cancel a queued operation
    /// - Parameter id: The operation ID to cancel
    /// - Returns: True if the operation was found and cancelled
    @discardableResult
    public func cancel(operationId id: UUID) -> Bool {
        if pendingOperations.removeValue(forKey: id) != nil {
            queueSubject.send(pendingOperations.count)
            return true
        }
        return false
    }

    /// Cancel all queued operations
    public func cancelAll() {
        pendingOperations.removeAll()
        queueSubject.send(0)
        stopMonitoring()
    }

    /// Start monitoring for connectivity to process queued operations
    public func startMonitoringIfNeeded() {
        guard !isMonitoring && !pendingOperations.isEmpty else { return }

        isMonitoring = true
        connectivityTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                let reachability = await self.reachabilityService.checkReachability()

                if reachability.isReachable {
                    await self.processQueuedOperations()
                }

                // Check every 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    /// Stop monitoring for connectivity
    public func stopMonitoring() {
        connectivityTask?.cancel()
        connectivityTask = nil
        isMonitoring = false
    }

    // MARK: - Private Methods

    private func queueAndWait<T: Sendable>(
        description: String,
        configuration: NetworkRetryConfiguration,
        operation: @escaping @Sendable () async throws -> T
    ) async -> NetworkRetryResult<T> {

        // Create a continuation to wait for the result
        return await withCheckedContinuation { continuation in
            let wrappedOperation: @Sendable () async throws -> T = {
                let result = try await operation()
                return result
            }

            Task {
                // Poll for connectivity
                var waited: TimeInterval = 0
                let pollInterval: TimeInterval = 1.0

                while waited < (configuration.timeout ?? .infinity) {
                    let reachability = await self.reachabilityService.checkReachability()

                    if reachability.isReachable {
                        let result = await self.executeWithRetry(
                            configuration: configuration,
                            operation: wrappedOperation
                        )
                        continuation.resume(returning: result)
                        return
                    }

                    try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                    waited += pollInterval
                }

                continuation.resume(returning: .failure(.timeout))
            }
        }
    }

    private func executeWithRetry<T: Sendable>(
        configuration: NetworkRetryConfiguration,
        operation: @escaping @Sendable () async throws -> T
    ) async -> NetworkRetryResult<T> {

        var lastError: Error?
        var currentDelay = configuration.baseDelay

        for attempt in 1...configuration.maxRetries {
            do {
                let result = try await operation()
                return .success(result)
            } catch {
                lastError = error

                // Check if this is the last attempt
                if attempt == configuration.maxRetries {
                    break
                }

                // Wait before retrying (exponential backoff)
                try? await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                currentDelay = min(currentDelay * 2, configuration.maxDelay)

                // If configured to wait for connectivity, check before retrying
                if configuration.waitForConnectivity {
                    let reachability = await reachabilityService.checkReachability()
                    if !reachability.isReachable {
                        // Wait for connectivity
                        while true {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            let check = await reachabilityService.checkReachability()
                            if check.isReachable { break }
                        }
                    }
                }
            }
        }

        return .failure(.maxRetriesExceeded(attempts: configuration.maxRetries, lastError: lastError))
    }

    private func processQueuedOperations() async {
        let operations = pendingOperations

        for (id, wrapper) in operations {
            await wrapper.execute()
            pendingOperations.removeValue(forKey: id)
            queueSubject.send(pendingOperations.count)
        }

        if pendingOperations.isEmpty {
            stopMonitoring()
        }
    }
}

// MARK: - Internal Helpers

/// Protocol for type-erased queued operations
private protocol QueuedOperationProtocol: Sendable {
    func execute() async
}

/// Wrapper to type-erase QueuedOperation
private struct QueuedOperationWrapper<T: Sendable>: QueuedOperationProtocol, Sendable {
    let operation: QueuedOperation<T>

    func execute() async {
        do {
            _ = try await operation.operation()
        } catch {
            // Operation failed, could add callback here
        }
    }
}

// MARK: - Convenience Extensions

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public extension NetworkRetry {
    /// Execute a simple closure with retry
    func retry<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async -> NetworkRetryResult<T> {
        await execute(description: "Operation", operation: operation)
    }

    /// Execute with custom configuration
    func retry<T: Sendable>(
        using config: NetworkRetryConfiguration,
        _ operation: @escaping @Sendable () async throws -> T
    ) async -> NetworkRetryResult<T> {
        await execute(description: "Operation", configuration: config, operation: operation)
    }
}
