#!/usr/bin/env bash

# Appium sidecar entrypoint: wait for the emulator, connect adb, run Appium.

set -e

readonly EMULATOR_HOST=${EMULATOR_HOST:-emulator}
readonly EMULATOR_ADB_PORT=${EMULATOR_ADB_PORT:-5555}
readonly APPIUM_PORT=${APPIUM_PORT:-4723}
readonly DEVICE="${EMULATOR_HOST}:${EMULATOR_ADB_PORT}"

echo "Waiting for adb at ${DEVICE}"
until adb connect "$DEVICE" 2>/dev/null | grep -q "connected"; do
    sleep 2
done
adb -s "$DEVICE" wait-for-device

echo "Waiting for boot to complete"
until [ "$(adb -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
done

# Animations off: UiAutomator2 misses elements under a live animation.
echo "Disabling animations"
for s in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb -s "$DEVICE" shell settings put global "$s" 0 || true
done

echo "Starting Appium on 0.0.0.0:${APPIUM_PORT}"
# adb_shell lets suites run device shell commands through the session when
# the runner has no adb of its own. Disposable CI emulator, nothing to protect.
exec appium --address 0.0.0.0 --port "$APPIUM_PORT" --allow-insecure=uiautomator2:adb_shell
