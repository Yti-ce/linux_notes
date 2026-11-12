#!/bin/bash
# disk_alert.sh - warn when the root filesystem is fuller than a threshold
# Usage: disk_alert.sh <percent>    exit 0 = OK, 1 = alert or bad usage
threshold="$1"

if [ -z "$threshold" ]; then
    echo "Usage: disk_alert.sh <percent>"
    exit 1
fi

usage=$(df --output=pcent / | tail -n 1 | tr -d ' %')

if [ "$usage" -gt "$threshold" ]; then
    echo "ALERT: disk usage $usage% is above $threshold%"
    exit 1
else
    echo "OK: disk usage $usage%"
fi
