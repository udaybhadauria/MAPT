#!/bin/bash
# Deletes all .log files in /root/ui_jool

TARGET_DIR="/root/ui_jool"

echo "Cleaning log files in $TARGET_DIR at $(date)"

find "$TARGET_DIR" -maxdepth 1 -type f -name "*.log" -exec rm -f {} \;

echo "Log cleanup done at $(date)"
