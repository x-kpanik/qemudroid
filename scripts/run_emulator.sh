#!/usr/bin/env bash

# Script for running emulator using default emulator tool

echo_error() {
  echo >&2 "$@"
}

set -ex

if [[ "$#" -ne 4 ]]; then    # Modified: Changed the expected number of arguments to 4
    echo "ERROR: Wrong number of arguments $#. Expected ones:
    SDK version, emulator architecture, console port, adb port.  # Modified: Updated error message

    For example:
    ./run_emulator.sh 24 x86 5554 5555   # Modified: Updated example usage
    "
    exit 1
fi

if ! [[ $1 =~ ^[0-9]+$ ]]; then
    echo_error "ERROR: Incorrect SDK version passed. An integer value expected, see https://developer.android.com/studio/releases/platforms"
    exit 1
fi

if ! [[ $2 =~ ^x86(_64)?$ ]]; then
    echo_error "ERROR: Incorrect emulator architecture passed. x86 and x86_64 are supported."
    exit 1
fi

readonly SDK_VERSION=$1
readonly EMULATOR_ARCH=$2
readonly CONSOLE_PORT=$3   # Modified: Added console port variable
readonly ADB_PORT=$4       # Modified: Added adb port variable

emulator_name="emulator_${SDK_VERSION}"
sd_card_name="/sdcard.img"

emulator_arguments=(-avd ${emulator_name} -sdcard ${sd_card_name} -verbose -ports ${CONSOLE_PORT},${ADB_PORT}) # Modified: Added port arguments

if [[ ${WINDOW} == "true" ]]; then
    binary_name="qemu-system-x86_64"

    if [[ -z "${DISPLAY}" ]]; then
        export DISPLAY=":0"
    fi

    echo "Rendering: Window swiftshader (software) rendering mode is enabled on ${DISPLAY} display (make sure, that you pass X11 socket)"
    emulator_arguments+=(-gpu swiftshader_indirect)
else
    binary_name="qemu-system-x86_64-headless"

    echo "Rendering: Headless swiftshader (software) rendering mode is enabled"
    emulator_arguments+=(-no-window -gpu swiftshader_indirect)
fi

if [ "${SNAPSHOT_ENABLED}" == "true" ]; then
    echo "Snapshots: Emulator will be ran with loading snapshot (for using emulator with snapshot on CI)"
    emulator_arguments+=(-snapshot ci -no-snapshot-save)
else
    echo "Snapshots: Emulator will be ran without snapshot feature"
    emulator_arguments+=(-no-snapshot)
fi

emulator_arguments+=(-no-boot-anim -no-audio -partition-size 2048)

# emulator uses adb so we make sure that server is running
adb start-server

cd /opt/android-sdk/emulator
echo "Run ${binary_name} binary for emulator ${emulator_name} with abi: $EMULATOR_ARCH (Version: ${SDK_VERSION}) on ports ${CONSOLE_PORT} and ${ADB_PORT}" # Modified: Updated log message
echo "no" | ./qemu/linux-x86_64/${binary_name} "${emulator_arguments[@]}"