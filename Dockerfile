FROM ubuntu:24.04

# Set environment variables
ENV STOPATSTART="false"
ENV TZ=Etc/UTC

RUN apt-get update && \
    apt-get install -y curl gnupg2 tzdata jq gzip unzip cron && \
    curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl https://rclone.org/install.sh | bash

# Install the Internxt CLI
RUN npm install -g @internxt/cli
RUN npm update -g axios

# Create directories for the rclone configuration and SSL certs
RUN mkdir -p /logs/internxt /config/internxt/certs /root/.internxt-cli /root/.cache /data/internxt/certs /data/rclone && \
    touch /logs/rclone.log

# Set the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Copy the internxt_script.sh and health_check.sh into the container
COPY health_check.sh /usr/local/bin/health_check.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY rclone_cron.sh /usr/local/bin/rclone_cron.sh

# Make the scripts executable
RUN chmod +x /usr/local/bin/health_check.sh /usr/local/bin/entrypoint.sh /usr/local/bin/rclone_cron.sh

# Create the SSH directory and set permissions to allow SSH key authentication
RUN mkdir -p /root/.ssh/id_rsa
RUN chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/id_rsa

# Expose necessary ports
# Internxt WebDAV port
EXPOSE 3005
# rClone Web GUI
EXPOSE 5572
# rClone SSH
EXPOSE 53682

# Set the entry point to run the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

VOLUME [ "/data" ]
VOLUME [ "/config" ]
VOLUME [ "/logs" ]

# Only needed if SFTP with key is used
VOLUME [ "/root/.ssh" ]

# Add a health check that checks if the Internxt CLI is functioning
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /usr/local/bin/health_check.sh || exit 1
