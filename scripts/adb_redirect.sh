#!/usr/bin/env bash

# Script for redirecting all traffic for adb connection

# Detect ip and forward ADB ports outside to outside interface
# These ports have to be exposed in docker
ip=$(ifconfig eth0 | grep 'inet' | cut -d: -f2 | awk '{ print $2}')
socat tcp-listen:5037,bind=$ip,fork tcp:127.0.0.1:5037 &
socat tcp-listen:5554,bind=$ip,fork tcp:127.0.0.1:5554 &
socat tcp-listen:5555,bind=$ip,fork tcp:127.0.0.1:5555 &
socat tcp-listen:5556,bind=$ip,fork tcp:127.0.0.1:5556 &
socat tcp-listen:5557,bind=$ip,fork tcp:127.0.0.1:5557 &
socat tcp-listen:5558,bind=$ip,fork tcp:127.0.0.1:5558 &
socat tcp-listen:5559,bind=$ip,fork tcp:127.0.0.1:5559 &
socat tcp-listen:5560,bind=$ip,fork tcp:127.0.0.1:5560 &
socat tcp-listen:5561,bind=$ip,fork tcp:127.0.0.1:5561 &
socat tcp-listen:5562,bind=$ip,fork tcp:127.0.0.1:5562 &
socat tcp-listen:5563,bind=$ip,fork tcp:127.0.0.1:5563 &
socat tcp-listen:5564,bind=$ip,fork tcp:127.0.0.1:5564 &
socat tcp-listen:5565,bind=$ip,fork tcp:127.0.0.1:5565 &
