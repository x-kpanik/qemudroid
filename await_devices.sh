#!/bin/bash

get_devices_count() {
  adb devices | grep -v devices | grep device | cut -f 1 | wc -l
}

sleep_time=10
max_retries=60
retries_count=0
expected_devices_count=$1
devices_count=$(get_devices_count)

check_expected_devices() {
  devices_count=$(get_devices_count)
  echo "Found $devices_count devices - expected $expected_devices_count"
  retries_count=$(($retries_count + 1))
  echo "Current retry is $retries_count sleeping for $sleep_time seconds"
  adb kill-server
  sleep $sleep_time
}

while [[ $devices_count -ne $expected_devices_count && $retries_count -lt $max_retries ]]; do
  adb devices
  check_expected_devices
done

if [[ $retries_count -eq $max_retries ]]; then
  echo "Max retries $max_retries exceeded for waiting $expected_devices_count found only $devices_count devices"
  exit -1
fi

echo "Found $devices_count devices"

exit 0
