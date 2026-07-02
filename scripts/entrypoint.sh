#!/usr/bin/env bash

set -ex

readonly SDK_VERSION=${SDK_VERSION:-36}
readonly EMULATOR_ARCH=${EMULATOR_ARCH:-x86_64}
readonly CONSOLE_PORT=${CONSOLE_PORT:-5554}
readonly ADB_PORT=${ADB_PORT:-5555}

readonly SNAPSHOT_ENABLED=false
./adb_redirect.sh
./run_emulator.sh "$SDK_VERSION" "$EMULATOR_ARCH" "$CONSOLE_PORT" "$ADB_PORT"