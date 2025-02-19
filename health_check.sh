#!/bin/bash

# Check if Internxt is running
if ! pgrep -f "internxt" > /dev/null; then
    echo "Internxt is not running."
    exit 1
fi

# Check if the rclone Web GUI is running and accessible
if ! curl -s --head "http://localhost:$RCLONE_WEB_GUI_PORT" | grep "200 OK" > /dev/null; then
    echo "rclone Web GUI is not accessible."
    exit 1
fi

# Check if cron jobs are enabled and running only if CRON_SCHEDULE is set
if [ -n "$CRON_SCHEDULE" ]; then
    if ! pgrep cron > /dev/null; then
        echo "Cron service is not running."
        exit 1
    fi

    # Check if cron jobs are set correctly
    if ! crontab -l | grep -q "$CRON_SCHEDULE"; then
        echo "No cron jobs found for the specified schedule."
        exit 1
    fi
else
    echo "No CRON_SCHEDULE defined. Skipping cron job checks."
fi

# If all checks pass
echo "Health check passed."
exit 0