# Internxt CLI with rclone

This repository contains a Docker setup to run the Internxt CLI with rclone support. It allows you to synchronize files between your local filesystem and Internxt using WebDAV.

## Environment Variables

The following environment variables can be set when running the Docker container. You can define up to 20 pairs of remote and local paths. Note that for each local path, a corresponding remote path is necessary.

| Environment Variable                   | Description                                                                                  |
|----------------------------------------|----------------------------------------------------------------------------------------------|
| `INTERNXT_EMAIL`                       | Email address for Internxt login.                                                           |
| `INTERNXT_HTTPS`                       | Set to `true` to enable HTTPS for WebDAV. Default is `false`.                              |
| `INTERNXT_PASSWORD`                    | Password for Internxt login.                                                                 |
| `INTERNXT_SSL_CERT`                   | Path to the SSL certificate for HTTPS (if enabled).                                         |
| `INTERNXT_SSL_KEY`                    | Path to the SSL key for HTTPS (if enabled).                                               |
| `INTERNXT_TOTP`                        | TOTP secret for two-factor authentication (optional).                                       |
| `INTERNXT_WEB_PORT`                    | Port for Internxt WebDAV service. Default is `3005`.                                        |
| `RCLONE_CONFIG`                        | Path to the rclone configuration file. Default is `/config/rclone.conf`.                    |
| `RCLONE_GUI_PASS`                      | Password for the rclone Web GUI. Default is `rclone_password`.                              |
| `RCLONE_GUI_USER`                      | Username for the rclone Web GUI. Default is `rclone_user`.                                  |
| `RCLONE_SSL_CERT`                      | Path to the SSL certificate for HTTPS (if enabled).                                        |
| `RCLONE_SSL_KEY`                       | Path to the SSL key for HTTPS (if enabled).                                               |
| `RCLONE_WEB_GUI_PORT`                  | Port for rclone Web GUI. Default is `5572`.                                                |
| `CRON_COMMAND`                         | Command to be executed by cron. Default is `rclone sync --create-empty-src-dirs --retries 5 --differ --verbose`. The command will be run with each pair of local and remote paths. |
| `CRON_SCHEDULE`                        | Cron schedule for running the specified command. Default is an empty string.                |
| `LOCAL_PATH_1` to `LOCAL_PATH_20`     | Up to 20 local paths where files will be synchronized. Each local path must have a corresponding remote path. |
| `REMOTE_PATH_1` to `REMOTE_PATH_20`   | Up to 20 remote paths for synchronization with the Internxt service.                       |
| `PUID`                                 | User ID to run the application. Default is `1000`.                                          |
| `PGID`                                 | Group ID to run the application. Default is `1000`.                                        |
| `TZ`                                   | Timezone for the application. Default is `Etc/UTC`.                                        |

## Docker Image

The Docker image is available on Docker Hub under the name `cgfm/internxt-cli_rclone`.

## Running the Container

### Docker Run Command

You can run the Docker container using the following command:

```bash
docker run -e INTERNXT_EMAIL="your_email@example.com" \
           -e INTERNXT_PASSWORD="your_password" \
           -e CRON_SCHEDULE="*/15 * * * *" \
           -e REMOTE_PATH_1="remote:path1" \
           -e LOCAL_PATH_1="/local/path1" \
           -e PUID=1000 \
           -e PGID=1000 \
           -e TZ="America/New_York" \
           -p 3005:3005 \
           -p 5572:5572 \
           --rm cgfm/internxt-cli_rclone
```

### Docker Compose Example

Here’s an example of how to use Docker Compose to run the container:

```yaml
version: '3.8'

services:
  internxt-cli:
    container_name: internxt-cli_rclone 
    image: cgfm/internxt-cli_rclone
    environment:
      INTERNXT_EMAIL: your_email@example.com
      INTERNXT_PASSWORD: your_password
      CRON_SCHEDULE: '*/15 * * * *'
      REMOTE_PATH_1: remote:path1
      LOCAL_PATH_1: /local/path1
      PUID: 1000
      PGID: 1000
      TZ: "America/New_York"
    ports:
      - "3005:3005"
      - "5572:5572"
    volumes:
      - /local/config/dir:/config
    restart: unless-stopped
```

## Building and Executing Cron Commands

The `CRON_COMMAND` environment variable allows you to specify a custom command that will be executed by cron based on the defined schedule. If no command is provided, the default command used is:

```
rclone sync --create-empty-src-dirs --retries 5 --differ --verbose
```

The cron command will be built to include all pairs of local and remote paths defined. For example, if you define `LOCAL_PATH_1` and `REMOTE_PATH_1`, the command will be constructed to run the sync between these two paths.

## Health Check

The health check for the container ensures that:
- The Internxt service is running.
- The rclone Web GUI is accessible.
- The cron service is running and, if a cron schedule is defined, that the specified cron job is set correctly.

If `CRON_SCHEDULE` is not defined (i.e., it is empty), the health check will skip checking the cron service and job presence, allowing the container to remain healthy if the other checks pass.

If any of the checks related to the Internxt service or rclone Web GUI fail, the container will be marked as unhealthy.

## License

This code was generated with the help of Workik AI. The licensing model for the code generated with Workik AI is set to be permissive, allowing for modification and redistribution.

## Links

- [Internxt CLI Documentation](https://github.com/internxt/cli)
- [rclone Documentation](https://rclone.org/docs/)