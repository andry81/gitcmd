#!/usr/bin/env bash

file="$1"

while IFS=$'\r\n' read line; do
  if [[ "$line" =~ ^[^$'\r\n'\:]+::$ ]]; then
    echo "$line"
  fi
done < "$file"
