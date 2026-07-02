#!/bin/bash

get_devices() {
  adb devices | grep -v devices | grep device | cut -f 1
}

devices=$(get_devices)

echo Found devices $devices

for device in $devices; do
  adb -s $device install -t -r -g app-tst-debug.apk
  adb -s $device install -t -r -g app-tst-debug-androidTest.apk
done

echo Application has been installed

exit 0
