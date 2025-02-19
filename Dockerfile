# Use a base image with bash and necessary tools
FROM ubuntu:20.04

# Set environment variables
ENV CRON_COMMAND=""
ENV CRON_SCHEDULE=""  # Default value is an empty string
ENV INTERNXT_CONFIG_DIR="/config"
ENV INTERNXT_EMAIL=""
ENV INTERNXT_HTTPS=false
ENV INTERNXT_PASSWORD=""
ENV INTERNXT_TOTP=""
ENV INTERNXT_WEB_PORT=3005
ENV PUID=1000  # Default user ID
ENV PGID=1000  # Default group ID
ENV TZ=Etc/UTC  # Default timezone
ENV RCLONE_CONFIG="/config/rclone.conf"
ENV RCLONE_GUI_PASS="rclone_password"
ENV RCLONE_GUI_USER="rclone_user"
ENV RCLONE_SSL_CERT=""
ENV RCLONE_SSL_KEY=""
ENV RCLONE_WEB_GUI_PORT=5572

# Install required packages including Node.js and npm
RUN apt-get update && \
    apt-get install -y curl gnupg2 tzdata && \
    curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
    apt-get install -y nodejs rclone cron && \
    npm install -g @internxt/cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create a directory for Internxt CLI configuration
RUN mkdir -p /config

# Copy the Internxt CLI script into the container
COPY internxt_script.sh /usr/local/bin/internxt_script.sh

# Make the script executable
RUN chmod +x /usr/local/bin/internxt_script.sh

# Set user permissions
RUN groupadd -g $PGID usergroup && \
    useradd -u $PUID -g usergroup -m user

# Switch to the non-root user
USER user

# Set the entry point to run the script
ENTRYPOINT ["/usr/local/bin/internxt_script.sh"]

# Add a health check that checks if the Internxt CLI is functioning
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /usr/local/bin/health_check.sh || exit 1