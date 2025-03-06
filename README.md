# Internxt CLI with rclone

This repository contains a Docker setup to run the Internxt CLI with rclone support. It allows you to synchronize files between your local filesystem and Internxt using WebDAV.

## Development ##
This is still in development and not ready for production use.

### Known issues ###
The rClone web gui isn't reachable and if `RCLONE_WEB_GUI_SERVE` is true the health check will fail.

## Environment Variables

The following environment variables can be set when running the Docker container. You can define up to 20 pairs of remote and local paths. Note that for each local path, a corresponding remote path is necessary.

| Environment Variable                                    | Description                                                                                                                                        |
|---------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| `INTERNXT_EMAIL`                                        | Email address for Internxt login.  ![Static Badge](https://img.shields.io/badge/mandatory-red)                                                     | 
| `INTERNXT_PASSWORD`                                     | Password for Internxt login.  ![Static Badge](https://img.shields.io/badge/mandatory-red)                                                          |
| `INTERNXT_HTTPS`                                        | Set to `true` to enable HTTPS for WebDAV. Default is `false`.                                                                                      |
| `INTERNXT_SSL_CERT`                                     | Path to the SSL certificate for HTTPS (if enabled).                                                                                                |
| `INTERNXT_SSL_KEY`                                      | Path to the SSL key for HTTPS (if enabled).                                                                                                        |
| `INTERNXT_TOTP`                                         | TOTP secret for two-factor authentication (optional).                                                                                              |
| `INTERNXT_HOST`                                         | The host of the Internxt WebDAV to connect to (optional). Default is 0.0.0.0                                                                       |
| `INTERNXT_WEB_PORT`                                     | Port for Internxt WebDAV service. Default is `3005`.                                                                                               |
| `RCLONE_CONFIG`                                         | Path to the rclone configuration file. Default is `/config/rclone.conf`.                                                                           |
| `RCLONE_WEB_GUI_SERVE`                                  | Set to false to disable the rClone Web GUI. Default is `true`.                                                                                     |
| `RCLONE_WEB_GUI_PORT`                                   | Port for rclone Web GUI. Default is `5572`.                                                                                                        |
| `RCLONE_WEB_GUI_USER`                                   | Username for the rclone Web GUI (optional). If not user and pass are set it won't be used.                                                         |
| `RCLONE_WEB_GUI_PASS`                                   | Password for the rclone Web GUI (optional). If not user and pass are set it won't be used.                                                         |
| `RCLONE_WEB_GUI_SSL_CERT`                               | Path to the SSL certificate for HTTPS (if enabled).                                                                                                |
| `RCLONE_WEB_GUI_SSL_KEY`                                | Path to the SSL key for HTTPS (if enabled).                                                                                                        |
| `RCLONE_WEB_GUI_EXTRA_PARAMS`                           | Additional parameters for rclone Web GUI (optional). Default is an empty string.                                                                   |
| `CRON_COMMAND`                                          | Command to be executed by cron (optional). Default is `rclone copy`. The command will be run with each pair of local and remote paths.<br>If remote files should be deleted if the don't exists locally anymore set this to `rclone sync`. **WARNING:** This will delete files on the remote if they are not present locally. **This could cause data loss!**  |
| `CRON_COMMAND_FLAGS`                                    | The Flags appended to the command above  (optional). Default is ` --create-empty-src-dirs --retries 5 --verbose`. The command will be run with each pair of local and remote paths. |
| `CRON_SCHEDULE`                                         | Cron schedule for running the specified command. Default is */15 * * * *. If an empty String is set no cron job  will be executed.                                   |
| `LOCAL_PATH_1` to `LOCAL_PATH_20`                       | Up to 20 local paths where files will be synchronized. Each local path must have a corresponding remote path.                                      |
| `REMOTE_PATH_1` to `REMOTE_PATH_20`                     | Up to 20 remote paths for synchronization with the Internxt service.                                                                               |
| `CUSTOM_CRON_COMMAND_1` to `CUSTOM_CRON_COMMAND_20`     | Up to 20 custom commands can be set. Details are explained at [Building and Executing Cron Commands](#custom-cron-command).                        |
| `ROOT_CA`                                               | If the path to a root ca is set it will be appended to the ca-certificates.crt file to avoid "Unknown CA" errors (optional).                       |
| `TZ`                                                    | Timezone for the application. Default is `Etc/UTC`.                                                                                                |
| `DEBUG`                                                 | If set to `true`, the container will run in debug mode. Default is `false`.                                                                        |
| `STOPATSTART`                                           | If set to `true`, the container will stop after the initial synchronization. Default is `false`.                                                   |

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
           -e TZ="America/New_York" \
           -p 3005:3005 \
           -p 5572:5572 \
           -p 53682:53682 \
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
      TZ: "Europe/Berlin"
    ports:
      # Internxt WebDAV 
      - "3005:3005"
      # rClone webgui 
      - "5572:5572"
      # rClone ssh
      - "53682:53682"
    volumes:
      - /local/config/dir:/config
    restart: unless-stopped
```

## Building and Executing Cron Commands
### Cron Command
The `CRON_COMMAND` environment variable allows you to specify a custom command that will be executed by cron based on the defined schedule. If no command is provided, the default command used is:

```
rclone copy
```

The `CRON_COMMAND_FLAGS` environment variable allows you to specify additional flags for the command. If no flags are provided, the default flags used are:

```
 --create-empty-src-dirs --retries 5 --verbose
```

The cron command will be built to include all pairs of local and remote paths defined. For example, if you define `LOCAL_PATH_1` and `REMOTE_PATH_1`, the command will be constructed to run the sync between these two paths.

```
rclone copy LOCAL_PATH_1 REMOTE_PATH_1 --create-empty-src-dirs --retries 5 --verbose
rclone copy LOCAL_PATH_2 REMOTE_PATH_2 --create-empty-src-dirs --retries 5 --verbose
...
rclone copy LOCAL_PATH_n<=20 REMOTE_PATH_n<=20 --create-empty-src-dirs --retries 5 --verbose 
```

### Custom Cron Command
The `CUSTOM_CRON_COMMAND_[1-20]` environment variables allow you to define custom cron commands. These commands will be executed in the order of the added number where numbers can be skiped. To run multiple commands before the sync commands just skip the definition of the local and remote Path.

```yaml
environment:
  ...
  REMOTE_PATH_1: remote:path1
  LOCAL_PATH_1: /local/path1
  REMOTE_PATH_2: remote:path2
  LOCAL_PATH_2: /local/path2
  CUSTOM_CRON_COMMAND_2: command 2
  CUSTOM_CRON_COMMAND_3: command 3
  CUSTOM_CRON_COMMAND_4: command 4
  REMOTE_PATH_4: remote:path4
  LOCAL_PATH_4: /local/path4
  CUSTOM_CRON_COMMAND_5: command 5
  ...
```

Will result in the following cron jobs:
```
rclone copy /local/path1 remote:path1 --create-empty-src-dirs --retries 5 --verbose
command 2
rclone copy /local/path2 remote:path2 --create-empty-src-dirs --retries 5 --verbose
command 3
command 4
rclone copy /local/path4 remote:path4 --create-empty-src-dirs --retries 5 --verbose
command 5
```

## rClone Configuration

This project includes a default rClone WebDAV remote named **Internxt**, which is configured to connect to the local Internxt CLI. This setup enables seamless file management within the Internxt service.

### Default Remote Configuration

The default **Internxt** remote is configured with the following settings:
- **Type**: WebDAV
- **Vendor**: Other
- **URL**: `http://<INTERNXT_HOST>:<INTERNXT_WEB_PORT>/` or `https://<INTERNXT_HOST>:<INTERNXT_WEB_PORT>/` (depending on the value of the `INTERNXT_HTTPS` environment variable)
- **User**: Set to the value of the `INTERNXT_EMAIL` environment variable.
- **Password**: Set to the value of the `INTERNXT_PASSWORD` environment variable.

### Setting Up Additional Remotes

To set up additional remotes in rClone, you can follow these steps:

1. Open a terminal and run the following command to access the rClone configuration menu:
   ```bash
   rclone config
   ```

2. Follow the prompts to create a new remote. You will be asked to specify the type of storage and provide the necessary authentication details.

3. After completing the configuration, your new remote will be available for use in rClone commands.

### Configuring Remotes via Web GUI

If you prefer a graphical user interface, you can configure new remotes using the rClone web GUI. Here’s how:

1. Open your web browser and go to the rClone web GUI, typically at `http://<Your server IP>:<RCLONE_WEB_GUI_PORT>`.

2. Log in with your credentials if authentication is enabled.

3. Navigate to the **Configuration** section in the web GUI.

4. Select the option to add a new remote, and follow the prompts to specify the remote type and connection details.

5. Save your configuration, and the new remote will be ready for use in your rClone commands.

With the web GUI, managing your remotes becomes a straightforward process without needing to use the command line.

## SSL Configuration

### Use Case for Internxt WebDAV Certificate

The Internxt WebDAV certificate is used to secure communication between your client application (such as a web browser or another application) and the Internxt WebDAV server. This certificate ensures that the data being transmitted is encrypted and protects against potential eavesdropping or man-in-the-middle attacks. 

When you set up your Internxt WebDAV server, you should obtain a valid SSL certificate that matches the designated hostname. This certificate allows users to securely connect to the WebDAV server over HTTPS, ensuring that their credentials and data are protected during transit.

### Use Case for rclone Certificate

The rclone certificate is utilized when you run the rclone remote control daemon (rcd) with SSL enabled. This certificate secures the connection between the rclone client and the rclone server, allowing you to execute commands and transfer files securely over HTTPS. 

When configuring rclone for use with Internxt or any other service, it’s important to provide a valid SSL certificate that corresponds to the hostname specified in your rclone configuration. This ensures that the communication remains encrypted and secure.

### Important Note on Certificates

In addition to being valid for the designated hostname, the provided SSL certificates must also be valid for `localhost`. This is crucial to allow a secure connection between rclone and the Internxt CLI when running locally. Since both services can only operate over HTTP or HTTPS, having valid certificates for `localhost` ensures that you can successfully establish a secure connection without encountering SSL errors.

Make sure to test your SSL configuration thoroughly to confirm that all services can communicate securely using the specified certificates.

## Health Check Script

The `health_check.sh` script ensures the operational status of the Internxt application and the rclone Web GUI. It performs the following checks:

- Verifies if the Internxt service is running.
- Checks the accessibility of the rclone Web GUI over HTTP or HTTPS.
- Confirms the cron service is active and verifies that the specified cron jobs are configured (only if `CRON_SCHEDULE` is set).

This script provides essential diagnostics for maintaining system health and service availability.

## License

This code was generated with the help of Workik AI. The licensing model for the code generated with Workik AI is set to be permissive, allowing for modification and redistribution.

## Links

- [Internxt CLI Documentation](https://github.com/internxt/cli)
- [rclone Documentation](https://rclone.org/docs/)
