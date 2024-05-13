#!/bin/bash
# Directory to search
DIRECTORY="/tmp/Ecosis/sessions"

# Find and delete files older than 1 day
find "$DIRECTORY" -type f -mtime +1 -exec rm {} +