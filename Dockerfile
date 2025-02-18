# Use a base image with bash and necessary tools
FROM ubuntu:20.04

# Set environment variables
ENV INTERNXT_EMAIL=""
ENV INTERNXT_PASSWORD=""
ENV INTERNXT_TOTP=""
ENV INTERNXT_WEB_PORT=3005
ENV INTERNXT_HTTPS=false
ENV INTERNXT_SSL_CERT=""
ENV INTERNXT_SSL_KEY=""
ENV RCLONE_WEB_GUI_PORT=5572
ENV RCLONE_CONFIG="/config/rclone.conf"
ENV CRON_COMMAND=""
ENV CRON_SCHEDULE="*/15 * * * *"

# Install required packages
RUN apt-get update && \
    apt-get install -y curl totp rclone cron && \
    curl -sSL https://cli.internxt.com/install.sh | bash && \
    apt-get clean

# Create a directory for Internxt CLI configuration
RUN mkdir -p /config

# Copy the Internxt CLI script into the container
COPY internxt_script.sh /usr/local/bin/internxt_script.sh

# Make the script executable
RUN chmod +x /usr/local/bin/internxt_script.sh

# Set the entry point to run the script
ENTRYPOINT ["/usr/local/bin/internxt_script.sh"]

# Add a health check that runs the specified CRON_COMMAND
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /bin/bash -c "$CRON_COMMAND" || exit 1