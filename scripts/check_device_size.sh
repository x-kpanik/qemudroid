#!/bin/bash

get_devices() {
  adb devices | grep -v devices | grep device | cut -f 1
}

devices=$(get_devices)

echo Found devices $devices

for device in $devices; do
  adb -s $device shell wm density
  adb -s $device shell wm size
done

exit 0
