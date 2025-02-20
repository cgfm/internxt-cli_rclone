#!/bin/bash

# Check if the DEBUG environment variable is set
if [ "$DEBUG" == "true" ]; then
    echo "Debug mode activated. Dropping into a shell."
    tail -f /dev/null
else
    echo "Running internxt_script.sh..."
    exec /usr/local/bin/internxt_script.sh  # Replace with the actual path to the internxt_script.sh
fi
