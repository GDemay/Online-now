import Foundation
import Combine

/// Configuration for network retry behavior
public struct NetworkRetryConfiguration: Sendable {
    /// Maximum number of attempts, including the initial attempt
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
        // Keep invalid input from producing an invalid range or a UInt64 conversion trap.
        self.maxRetries = max(1, maxRetries)
        self.baseDelay = baseDelay.isFinite ? max(0, baseDelay) : 0
        self.maxDelay = maxDelay.isFinite ? max(0, maxDelay) : 30
        self.waitForConnectivity = waitForConnectivity
        self.timeout = timeout.map { $0.isFinite ? max(0, $0) : 0 }
    }

    /// Default configuration for quick operations
    public static let quick = NetworkRetryConfiguration(
        maxRetries: 2,
        baseDelay: 0.5,
        maxDelay: 5.0,
        waitForConnectivity: true,
        timeout: 30
    )

    /// Configuration for operations that can safely be repeated.
    /// Use an idempotency key for remote writes; never retry an unprotected payment.
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

/// Retries operations that are safe to repeat, including while waiting for connectivity.
/// Operations must cooperate with Swift task cancellation (as URLSession does) so a
/// timeout or cancellation can stop in-flight work. Remote writes need idempotency.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor NetworkRetry {
    private let reachabilityService: any ReachabilityChecking
    private var pendingOperations: [UUID: PendingOperation] = [:]
    private let queueSubject = PassthroughSubject<Int, Never>()

    public var queueCountPublisher: AnyPublisher<Int, Never> {
        queueSubject.eraseToAnyPublisher()
    }

    public var queuedCount: Int { pendingOperations.count }

    public init(reachabilityService: any ReachabilityChecking = ReachabilityService()) {
        self.reachabilityService = reachabilityService
    }

    deinit {
        for operation in pendingOperations.values { operation.task?.cancel() }
    }

    /// Execute with a single timeout budget covering connectivity, attempts, and backoff.
    public func execute<T: Sendable>(
        description: String,
        configuration: NetworkRetryConfiguration = .quick,
        operation: @escaping @Sendable () async throws -> T
    ) async -> NetworkRetryResult<T> {
        await Self.performExecution(
            reachabilityService: reachabilityService, configuration: configuration,
            operation: operation)
    }

    private static func performExecution<T: Sendable>(
        reachabilityService: any ReachabilityChecking,
        configuration: NetworkRetryConfiguration,
        operation: @escaping @Sendable () async throws -> T
    ) async -> NetworkRetryResult<T> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard let timeout = configuration.timeout else {
            return await executeWithRetry(
                reachabilityService: reachabilityService, configuration: configuration,
                operation: operation)
        }
        guard timeout > 0 else { return .failure(.timeout) }

        return await withTaskGroup(of: NetworkRetryResult<T>.self) { group in
            group.addTask {
                await executeWithRetry(
                    reachabilityService: reachabilityService, configuration: configuration,
                    operation: operation)
            }
            group.addTask {
                do {
                    try await Self.sleep(seconds: timeout)
                    return .failure(.timeout)
                } catch {
                    return .failure(.cancelled)
                }
            }
            let result = await group.next() ?? .failure(.cancelled)
            group.cancelAll()
            return result
        }
    }

    /// Queue an operation using the same cancellation, retry, and timeout rules as execute.
    /// Each monitoring period includes connectivity waiting in its timeout budget.
    @discardableResult
    public func queue<T: Sendable>(
        description: String,
        configuration: NetworkRetryConfiguration = .quick,
        operation: @escaping @Sendable () async throws -> T
    ) -> UUID {
        let id = UUID()
        let reachability = reachabilityService
        pendingOperations[id] = PendingOperation(run: {
            _ = await Self.performExecution(
                reachabilityService: reachability, configuration: configuration, operation: operation)
        })
        queueSubject.send(pendingOperations.count)
        startMonitoringIfNeeded()
        return id
    }

    /// Cancel queued or in-flight work. Cancellation prevents any later retry attempt.
    @discardableResult
    public func cancel(operationId id: UUID) -> Bool {
        guard let operation = pendingOperations.removeValue(forKey: id) else { return false }
        operation.task?.cancel()
        queueSubject.send(pendingOperations.count)
        return true
    }

    public func cancelAll() {
        let operations = pendingOperations.values
        pendingOperations.removeAll()
        for operation in operations { operation.task?.cancel() }
        queueSubject.send(0)
    }

    /// Resume monitoring queued operations after an explicit stop.
    public func startMonitoringIfNeeded() {
        guard !pendingOperations.isEmpty else { return }
        for id in Array(pendingOperations.keys) {
            guard var operation = pendingOperations[id], operation.task == nil else { continue }
            let generation = UUID()
            operation.generation = generation
            let run = operation.run
            operation.task = Task { [weak self] in
                guard !Task.isCancelled else { return }
                await run()
                await self?.didFinish(id: id, generation: generation)
            }
            pendingOperations[id] = operation
        }
    }

    /// Stop queued work. Entries remain available for explicit resumption.
    public func stopMonitoring() {
        for id in Array(pendingOperations.keys) {
            guard var operation = pendingOperations[id] else { continue }
            operation.task?.cancel()
            operation.task = nil
            operation.generation = UUID()
            pendingOperations[id] = operation
        }
    }

    private func didFinish(id: UUID, generation: UUID) {
        // An old cancelled worker must never remove a newly resumed entry.
        guard pendingOperations[id]?.generation == generation else { return }
        pendingOperations.removeValue(forKey: id)
        queueSubject.send(pendingOperations.count)
    }

    private static func executeWithRetry<T: Sendable>(
        reachabilityService: any ReachabilityChecking,
        configuration: NetworkRetryConfiguration,
        operation: @escaping @Sendable () async throws -> T
    ) async -> NetworkRetryResult<T> {
        var lastError: Error?
        var delay = min(configuration.baseDelay, configuration.maxDelay)
        for attempt in 1...configuration.maxRetries {
            do {
                try Task.checkCancellation()
                if configuration.waitForConnectivity {
                    try await waitForConnectivity(using: reachabilityService)
                }
                try Task.checkCancellation()
                let result = try await operation()
                try Task.checkCancellation()
                return .success(result)
            } catch is CancellationError {
                return .failure(.cancelled)
            } catch {
                guard !Task.isCancelled else { return .failure(.cancelled) }
                lastError = error
                guard attempt < configuration.maxRetries else { break }
                do {
                    try await Self.sleep(seconds: delay)
                } catch {
                    return .failure(.cancelled)
                }
                delay = min(delay * 2, configuration.maxDelay)
            }
        }
        return .failure(.maxRetriesExceeded(attempts: configuration.maxRetries, lastError: lastError))
    }

    private static func waitForConnectivity(using reachabilityService: any ReachabilityChecking) async throws {
        while true {
            try Task.checkCancellation()
            let result = await reachabilityService.checkReachability()
            try Task.checkCancellation()
            if result.isReachable { return }
            try await Self.sleep(seconds: 1)
        }
    }

    private static func sleep(seconds: TimeInterval) async throws {
        // Chunk long waits so large (but finite) input cannot overflow nanoseconds.
        var remaining = seconds
        repeat {
            try Task.checkCancellation()
            let interval = min(remaining, 3_600)
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            remaining -= interval
        } while remaining > 0
    }

    private struct PendingOperation {
        let run: @Sendable () async -> Void
        var generation = UUID()
        var task: Task<Void, Never>?
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
