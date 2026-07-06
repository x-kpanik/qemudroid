#!/usr/bin/env bash

# Entrypoint of the appium sidecar container: waits for the emulator
# container, connects adb to it, disables animations, then runs Appium.

set -e

readonly EMULATOR_HOST=${EMULATOR_HOST:-emulator}
readonly EMULATOR_ADB_PORT=${EMULATOR_ADB_PORT:-5555}
readonly APPIUM_PORT=${APPIUM_PORT:-4723}
readonly DEVICE="${EMULATOR_HOST}:${EMULATOR_ADB_PORT}"

echo "=== Waiting for adb at ${DEVICE} ==="
until adb connect "$DEVICE" 2>/dev/null | grep -q "connected"; do
    sleep 2
done
adb -s "$DEVICE" wait-for-device

echo "=== Waiting for sys.boot_completed=1 ==="
until [ "$(adb -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
done

# Animations off: UiAutomator2 cannot locate an element under a live
# animation, producing a false NoSuchElement while the element is on screen.
echo "=== Disabling animations ==="
for s in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb -s "$DEVICE" shell settings put global "$s" 0 || true
done

echo "=== Starting Appium ${APPIUM_VERSION:-} on 0.0.0.0:${APPIUM_PORT} ==="
# adb_shell lets suites reach the device shell through the session
# ("mobile: shell") when the runner has no adb of its own - e.g. to send
# broadcasts or toggle device settings mid-test. This is a disposable CI
# emulator, nothing sensitive to protect.
exec appium --address 0.0.0.0 --port "$APPIUM_PORT" --allow-insecure=uiautomator2:adb_shell
