FROM ubuntu:22.04

# Set environment variables
ENV STOPATSTART="false"
ENV CRON_COMMAND=""
ENV CRON_SCHEDULE=""
ENV DEBUG="false"
ENV INTERNXT_EMAIL=""
ENV INTERNXT_HTTPS=false
ENV INTERNXT_PASSWORD=""
ENV INTERNXT_TOTP=""
ENV INTERNXT_WEB_PORT=3005
ENV TZ=Etc/UTC
ENV RCLONE_CONFIG="/config/rclone.conf"
ENV RCLONE_GUI_PASS="rclone_password"
ENV RCLONE_GUI_USER="rclone_user"
ENV RCLONE_SSL_CERT=""
ENV RCLONE_SSL_KEY=""
ENV RCLONE_WEB_GUI_PORT=5572

# Install required packages including Node.js and npm
RUN apt-get update && \
    apt-get install -y curl gnupg2 tzdata jq rclone cron && \
    curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install the Internxt CLI
RUN npm install -g @internxt/cli


# Create directories for the rclone configuration and SSL certs
RUN mkdir -p /config/log /config/internxt/certs && \
    touch /config/log/rclone.log
    
# Move Internxt data folder to /config/internxt and create a symlink
RUN mv /root/.internxt-cli/* /config/internxt && \
    rm -r /root/.internxt-cli && \
    ln -s /config/internxt /root/.internxt-cli

# Set the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Copy the internxt_script.sh and health_check.sh into the container
COPY health_check.sh /usr/local/bin/health_check.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY rclone_cron.sh /usr/local/bin/rclone_cron.sh

# Make the scripts executable
RUN chmod +x /usr/local/bin/health_check.sh /usr/local/bin/entrypoint.sh /usr/local/bin/rclone_cron.sh

# Expose necessary ports
# Internxt WebDAV port
EXPOSE 3005
# rClone Web GUI
EXPOSE 5572
# rClone SSH
EXPOSE 53682

# Set the entry point to run the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Add a health check that checks if the Internxt CLI is functioning
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /usr/local/bin/health_check.sh || exit 1
