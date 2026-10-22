#!/bin/bash
# Xcode Cloud's Archive action must pass the native unit/UI suite before shipping.
# A future dedicated Test action owns its own tests and must not run this gate twice.
# Apple hook/failure semantics: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
set -euo pipefail

case "${CI_XCODEBUILD_ACTION:-}" in
    archive) ;;
    analyze|build|build-for-testing|test-without-building)
        echo "Online Now archive test gate: not applicable to ${CI_XCODEBUILD_ACTION}."
        exit 0
        ;;
    *)
        echo "error: Online Now archive test gate requires a recognized CI_XCODEBUILD_ACTION." >&2
        exit 1
        ;;
esac

if [[ "${CI_XCODEBUILD_EXIT_CODE:-}" != "0" ]]; then
    echo "error: The archive did not succeed; preserving its failure without starting tests." >&2
    exit 1
fi

: "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud did not provide the primary repository path}"
cd "$CI_PRIMARY_REPOSITORY_PATH"
if [[ ! -d OnlineNow.xcodeproj || ! -f OnlineNow.xcodeproj/xcshareddata/xcschemes/OnlineNow.xcscheme ]]; then
    echo "error: Native test project or shared OnlineNow scheme is missing." >&2
    exit 1
fi

test_workdir=$(mktemp -d "${TMPDIR:-/tmp}/online-now-native-tests.XXXXXX")
test_log="$test_workdir/xcodebuild-test.log"
echo "ONLINE_NOW_NATIVE_TEST_GATE_START: Debug unit and UI tests; overall deadline 1800 seconds."
echo "Native test workspace: $test_workdir"
# Preserve the full transcript in this action's custom-script build log. Apple
# does not automatically publish custom-script-created xcresult/log files as artifacts.
python3 - "$CI_PRIMARY_REPOSITORY_PATH" "$test_workdir" <<'PY' 2>&1 | tee "$test_log"
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

repository, workspace = map(Path, sys.argv[1:])
result_path = workspace / "NativeTests.xcresult"
try:
    devices = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        text=True, timeout=60
    ))["devices"]
    candidates = [device for runtime, items in devices.items() if ".iOS-" in runtime
                  for device in items if device.get("isAvailable", True)
                  and device["name"].startswith("iPhone")]
    if not candidates:
        raise RuntimeError("No available iPhone simulator: native tests cannot be skipped.")
    device = candidates[0]
    print("Native simulator: " + device["name"] + " (" + device["udid"] + ")", flush=True)
    command = [
        "xcodebuild", "test", "-project", str(repository / "OnlineNow.xcodeproj"),
        "-scheme", "OnlineNow", "-configuration", "Debug",
        "-destination", "platform=iOS Simulator,id=" + device["udid"],
        "-destination-timeout", "120",
        "-derivedDataPath", str(workspace / "DerivedData"),
        "-resultBundlePath", str(result_path),
        "-only-testing:OnlineNowTests", "-only-testing:OnlineNowUITests",
        "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES",
        "-default-test-execution-time-allowance", "60",
        "-maximum-test-execution-time-allowance", "120",
        "CODE_SIGNING_ALLOWED=NO"
    ]
    # Python is supplied in Xcode Cloud. A bounded subprocess avoids depending
    # on GNU timeout, which macOS does not provide. All xcodebuild output streams
    # directly into the action log and tee; no captured environment is printed.
    process = subprocess.Popen(command, start_new_session=True)
    try:
        status = process.wait(timeout=1800)
    except subprocess.TimeoutExpired:
        print("error: Native tests exceeded the 1800-second deadline.", flush=True)
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=15)
        sys.exit(124)
    if status:
        sys.exit(status if status > 0 else 1)
    if not result_path.is_dir():
        raise RuntimeError("xcodebuild produced no test results; refusing to pass the gate.")

    def read_result(identifier=None):
        arguments = ["--path", str(result_path), "--format", "json"]
        if identifier is not None:
            arguments += ["--id", identifier]
        # Xcode 16+ requires --legacy for the typed result tree. Xcode 15 uses
        # the original get command. Either failure is fatal if neither works.
        failures = []
        for prefix in (["get", "object", "--legacy"], ["get"]):
            result = subprocess.run(["xcrun", "xcresulttool"] + prefix + arguments,
                                    text=True, capture_output=True, timeout=60)
            if result.returncode == 0:
                return json.loads(result.stdout)
            failures.append(result.stderr.strip())
        raise RuntimeError("Could not inspect native test results: " + " | ".join(failures))

    def walk(value):
        if isinstance(value, dict):
            yield value
            for child in value.values():
                yield from walk(child)
        elif isinstance(value, list):
            for child in value:
                yield from walk(child)

    root = read_result()
    successful = {"OnlineNowTests": 0, "OnlineNowUITests": 0}
    references = {node["testsRef"]["id"]["_value"] for node in walk(root)
                  if isinstance(node.get("testsRef"), dict) and "id" in node["testsRef"]}
    for reference in references:
        for node in walk(read_result(reference)):
            name = node.get("targetName", {}).get("_value")
            if name in successful:
                successful[name] += sum(
                    child.get("_type", {}).get("_name") == "ActionTestMetadata"
                    and child.get("testStatus", {}).get("_value") == "Success"
                    for child in walk(node)
                )
    for target, count in successful.items():
        if count == 0:
            raise RuntimeError("No successful executed tests for " + target + "; refusing to archive.")
        print("Verified native test execution: " + target + " (" + str(count) + " passed).", flush=True)
except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
    print("error: " + str(error), file=sys.stderr, flush=True)
    sys.exit(1)
PY

echo "ONLINE_NOW_NATIVE_TEST_GATE_PASS: both native unit and UI tests executed successfully."
