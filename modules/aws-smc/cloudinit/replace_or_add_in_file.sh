#!/bin/bash

set -euo pipefail

FILENAME=$1
ENTRY=$2
KEY=$(echo "$ENTRY"|cut -d'=' -f1)
grep -vP "^$KEY"=.* "$FILENAME" > "$FILENAME.tmp"
echo "Adding $ENTRY in $FILENAME"
echo "$ENTRY" >> "$FILENAME.tmp"
mv "$FILENAME.tmp" "$FILENAME"
