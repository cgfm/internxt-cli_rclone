# Internxt CLI with rclone

This repository contains a Docker setup to run the Internxt CLI with rclone support. It allows you to synchronize files between your local filesystem and Internxt using WebDAV.

## Development ##
This is still in development and not ready for production use.

## Environment Variables

The following environment variables can be set when running the Docker container. You can define up to 20 pairs of remote and local paths. Note that for each local path, a corresponding remote path is necessary.

| Environment Variable                | JSON Key                      | Description                                                                                                                                        |
|-------------------------------------|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| `CONFIG_FILE`                       |                               | Path to the JSON configuration file for cron jobs. Default is `/config/rclone_cron.json`. If this file does not exist, it will be ignored. Details for creating this file is explained at [JSON Configuration](#json-configuration)        |
| `INTERNXT_EMAIL`                    |  `internxt.email`             | Email address for Internxt login.  ![Static Badge](https://img.shields.io/badge/mandatory-red) if not set in config file.                                                      | 
| `INTERNXT_PASSWORD`                 |  `internxt.password`          | Password for Internxt login.  ![Static Badge](https://img.shields.io/badge/mandatory-red) if not set in config file.                                                          |
| `INTERNXT_HTTPS`                    |  `internxt.https`             | Set to `true` to enable HTTPS for WebDAV. Default is `false`.                                                                                      |
| `INTERNXT_SSL_CERT`                 |  `internxt.ssl_cert`          | Path to the SSL certificate for HTTPS (if enabled).                                                                                                |
| `INTERNXT_SSL_KEY`                  |  `internxt.ssl_key`           | Path to the SSL key for HTTPS (if enabled).                                                                                                        |
| `INTERNXT_TOTP`                     |  `internxt.totp`              | TOTP secret for two-factor authentication (optional).                                                                                              |
| `INTERNXT_HOST`                     |  `internxt.host`              | The host of the Internxt WebDAV to connect to (optional). Default is 0.0.0.0                                                                       |
| `INTERNXT_WEB_PORT`                 |  `internxt.web_port`          | Port for Internxt WebDAV service. Default is `3005`.                                                                                               |
| `RCLONE_CONFIG`                     |  `rclone.config`              | Path to the rclone configuration file. Default is `/config/rclone.conf`.                                                                           |
| `RCLONE_WEB_GUI_SERVE`              |  `rclone.webgui_serve`        | Set to false to disable the rClone Web GUI. Default is `true`.                                                                                     |
| `RCLONE_WEB_GUI_PORT`               |  `rclone.webgui_port`         | Port for rclone Web GUI. Default is `5572`.                                                                                                        |
| `RCLONE_WEB_GUI_USER`               |  `rclone.webgui_user`         | Username for the rclone Web GUI (optional). If not user and pass are set it won't be used.                                                         |
| `RCLONE_WEB_GUI_PASS`               |  `rclone.webgui_pass`         | Password for the rclone Web GUI (optional). If not user and pass are set it won't be used.                                                         |
| `RCLONE_WEB_GUI_SSL_CERT`           |  `rclone.webgui_ssl_cert`     | Path to the SSL certificate for HTTPS (if enabled).                                                                                                |
| `RCLONE_WEB_GUI_SSL_KEY`            |  `rclone.webgui_ssl_key`      | Path to the SSL key for HTTPS (if enabled).                                                                                                        |
| `RCLONE_WEB_GUI_EXTRA_PARAMS`       |  `rclone.webgui_extra_params` | Additional parameters for rclone Web GUI (optional). Default is an empty string.                                                                   |
| `CRON_COMMAND`                      |  `cron.command`               | Default cron command to be executed by cron (optional). Can be overwritten by the `CRON_COMMAND_*` variables. Default is `rclone copy`. The command will be run with each pair of local and remote paths.<br>If remote files should be deleted if the don't exists locally anymore set this to `rclone sync`. **WARNING:** This will delete files on the remote if they are not present locally. **This could cause data loss!**  |
| `CRON_COMMAND_FLAGS`                |  `cron.command_flags`         | The Flags appended to the command above  (optional). Can be overwritten by the `CRON_COMMAND_FLAGS_*` variables. Default is ` --create-empty-src-dirs --retries 5 --verbose`. The command will be run with each pair of local and remote paths. |
| `CRON_SCHEDULE`                     |  `cron.schedule`              | Cron schedule for running the specified command. Can be overwritten by the `CRON_SCHEDULE_*` variables. Default is */15 * * * *.                                    |
| `LOCAL_PATH_1` to `LOCAL_PATH_20`   |                               | Up to 20 local paths where files will be synchronized. Each local path must have a corresponding remote path.                                      |
| `REMOTE_PATH_1` to `REMOTE_PATH_20` |                               | Up to 20 remote paths for synchronization with the Internxt service.                                                                               |
| `CRON_COMMAND_1` to `CRON_COMMAND_20` |                               | Up to 20 custom commands can be set. Details are explained at [Building and Executing Cron Commands](#custom-cron-command).                        |
| `CRON_COMMAND_FLAGS_1` to `CRON_COMMAND_FLAGS_20`  |                               | Up to 20 flags for the associated custom command can be set. Details are explained at [JSON Configuration](#json-configuration).                        |
| `CRON_SCHEDULE_1` to `CRON_SCHEDULE_20` |                               | Up to 20 schedules for the associated custom command and/or the associated local and remote path can be set. Details are explained at [Building and Executing Cron Commands](#custom-cron-command).                        |
| `ROOT_CA`                           |  `root_ca`                    | If the path to a root ca is set it will be appended to the ca-certificates.crt file to avoid "Unknown CA" errors (optional).                       |
| `TZ`                                |  `timezone`                   | Timezone for the application. Default is `Etc/UTC`.                                                                                                |
| `LOG_LEVEL`                         |  `log.level`                  | Set the log level for the application. Default is `info`. Possible values are `fine`, `debug`, `info` and `error`.<br>It's recommend to set the log level by env var. Otherwise the first log entrys will be logged with the default log level `info` until the JSON file is loaded.     |
| `LOG_LOGFILE_COUNT`                  | `log.file_count`          | Set the number of log files to keep. Default is `3`. If its set to a negative value it will keep all log files.         |
| `STOPATSTART`                       |                               | If set to `true`, the container will stop after the initial synchronization. Default is `false`.                                                   |

## Docker Image

The Docker image is available on Docker Hub under the name `cgfm/internxt-cli_rclone`.

## Running the Container

### Docker Run Command

You can run the Docker container using the following command:

```bash
docker run -v /path/to/local/config:/config \
           -v /path/to/local/internxt/data:/data \
           --name internxt-cli_container \
           -e INTERNXT_EMAIL="your_email@example.com" \
           -e INTERNXT_PASSWORD="your_password" \
           -e CRON_SCHEDULE="*/15 * * * *" \
           -e REMOTE_PATH_1="remote:path1" \
           -e LOCAL_PATH_1="/local/path1" \
           -e TZ="Europe/Berlin" \
           -p 3005:3005 \
           -p 5572:5572 \
           -p 53682:53682 \
           cgfm/internxt-cli_rclone
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
      - /local/data/dir:/data
    restart: unless-stopped
```

## Directory Structure: `/config` and `/data`

### Overview

This application utilizes two primary directories—`/config` and `/data`—to manage configurations and persistent data effectively. Understanding the purpose of each directory helps ensure the application runs smoothly and that data is preserved across container restarts.

### `/data` Directory

- **Purpose**: The `/data` directory is used to store persistent data related to the Internxt CLI.
- **Initialization Process**:
  - On the first run of the container, the `entrypoint.sh` script checks for the existence of the `init_done` file in the `/data` directory to determine if the initialization process has already occurred.
  - If the `init_done` file does not exist, the script performs the following actions:
    - Copies the `config.webdav.inxt` file from `/root/.internxt-cli` to `/data`. This file contains the WebDAV configuration for the Internxt service.
    - Copies the `internxt-cli-drive.sqlite` database file from `/root/.internxt-cli` to `/data`. This database stores important data for the Internxt CLI.
    - Copies the entire `logs` directory from `/root/.internxt-cli` to `/config/log/internxt`, allowing for access to logs related to the Internxt CLI.

  - After copying these files, the script creates a file named `init_done` in the `/data` directory to signal that the initialization has been completed.

- **Subsequent Runs**:
  - On subsequent container runs, if the `init_done` file exists, the initialization process will be skipped. This prevents overwriting existing configurations and data.
  
### `/config` Directory

- **Purpose**: The `/config` directory is used to store configuration files and logs for the application.
- **Contents**:
  - **Logs**: The application writes logs to `/config/log`, which allows for monitoring and debugging.
  - **Internxt Logs**: The logs related to the Internxt CLI are specifically stored in `/config/log/internxt`, which is created during the first run if it does not already exist.

### Summary

Using the `/config` and `/data` directories allows the application to maintain a clean separation between configuration and persistent data. This design ensures that important data is not lost between container restarts and provides a straightforward method for managing log files and configurations.

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

## JSON Configuration

### Cron jobs
The cron jobs and commands you define are stored at runtime in a JSON file located at `/working/rclone_cron.json`. You can provide your own JSON file to customize the cron jobs and commands by setting the `CONFIG_FILE` environment variable to the path of your JSON file or by simply storing your JSON file at `/config/rclone_cron.json`. The structure of this JSON file allows for dynamic command execution based on the defined environment variables and the `CONFIG_FILE` file. You can Use the ENV Vars and the JSON file both at the same time. they will be combined in the `/working/rclone_cron.json` file. More about the cron jobs and commands in the [Building and Executing Cron Commands](#custom-cron-command) section.

- **cron_jobs**: This is an array containing objects for each scheduled job. Each object need to have:
  - **schedule**: The cron schedule for the job.
  - **commands**: An array of command objects to execute at the specified schedule.

### Settings
All settings listed in the ENV Vars section can be set in the JSON file as well. If an ENV Var is set, it will override the value in the JSON file. If an ENV Var is not set, the value in the JSON file will be used. If the key is not present in the JSON file, the default value will be used.

- **settings**: This object contains configuration settings that are loaded from environment variables. It's possible containing keys are listed in the [Environment Variables](#environment-variables) section above.

### Example JSON Structure

```json
{
  "cron_jobs": [
    {
      "schedule": "*/15 * * * *",
      "commands": [
        {
          "command": "rclone copy",
          "command_flags": "--create-empty-src-dirs --retries 5 --verbose",
          "local_path": "/local/path1",
          "remote_path": "remote:path1"
        },
        {
          "command": "rclone copy",
          "command_flags": "--create-empty-src-dirs --retries 5 --verbose",
          "local_path": "/local/path2",
          "remote_path": "remote:path2"
        }
      ]
    },
    {
      "schedule": "0 * * * *",
      "commands": [
        {
          "command": "my_backup_script.sh"
        },
        {
          "command": "rclone copy",
          "command_flags": "--create-empty-src-dirs --retries 5 --verbose",
          "local_path": "/local/backup/path",
          "remote_path": "remote:backup/path"
        }
      ]
    }
  ],
  "settings": {
    "internxt": {
      "email": "your_email@example.com",
      "password": "your_password"
    },
    "rclone": {
      "config": "/config/rclone.conf"
    },
    "log": {
      "level": "info"
    }
  }
}
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
