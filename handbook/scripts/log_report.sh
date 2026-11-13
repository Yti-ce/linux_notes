#!/bin/bash
# Summarise the nginx access log: total requests, status codes, top 3 client IPs.
# Usage: ./log_report.sh
log=/var/log/nginx/access.log

if [ ! -f "$log" ]; then
    echo "Log file not found: $log"
    exit 1
fi

echo "Total requests:"
cat "$log" | wc -l

echo "Status codes:"
cat "$log" | awk '{print $9}' | sort | uniq -c

echo "Top 3 IPs:"
cat "$log" | awk '{print $1}' | sort | uniq -c | sort -rn | head -n 3
