**SSH Menu (sshm)**

A standalone Bash script providing an interactive SSH menu for connecting to hosts defined in your `~/.ssh/config`. The script, `sshm.sh`, parses SSH configurations, validates environment prerequisites, and presents a user-friendly selection interface—all in a single file.

-- Small, simple, and effective! Out of all the scripts I have written, this is the one I use the most. It is a single file that works on both macOS and Linux. It is a great way to quickly SSH into servers without having to remember their hostnames or IP addresses.

---

## Table of Contents

1. [Features](#features)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Usage](#usage)

   * [Interactive Mode](#interactive-mode)
   * [Display Config (`-d` / `--display`)](#display-config--d----display)
6. [Script Details](#script-details)

---

## Features

* Parses your `~/.ssh/config` to list known hosts.
* Interactive menu to select and SSH into a host.
* Option to display the entire SSH config.
* Single-file implementation for easy installation.
* Cross-platform support (Linux & macOS).

---

## Prerequisites

* **Operating System:** macOS or Linux (requires Bash).
* **SSH:** Ensure the `ssh` command is installed and available in your `$PATH`.
* **Permissions:** Read/write access to your SSH config file (`~/.ssh/config`).

---

## Installation

1. Clone this repository or download the script:

   ```bash
   git clone https://github.com/yourusername/sshm.git
   cd sshm
   ```

2. Ensure the script is executable:

   ```bash
   chmod +x sshm.sh
   ```

3. (Optional) Move it to a directory in your `$PATH`, e.g.:

   ```bash
   mv sshm.sh /usr/local/bin/sshm
   ```

---

## Configuration

The script relies on your SSH configuration file located at `${HOME}/.ssh/config`. A sample entry in the config:

<details>
<summary>Example `~/.ssh/config` entry</summary>

```text
Host myserver
    HostName server.example.com
    User gituser
    Port 22
    .....

Host anotherserver
    HostName another.example.com
    User anotheruser
    Port 2222
    .....

```

Multiple `Host` entries can be defined; each will appear as a menu option.

</details>

---

## Usage

### Interactive Mode

Run the script without arguments to see an interactive menu:

1. The script checks your OS, SSH binary, and the SSH config file.
2. It parses the `~/.ssh/config` and lists all known hosts.
3. Select a host by its number.
4. The script connects via `ssh <host>`.
5. Upon exit, the menu is re-displayed.


```bash
./sshm.sh
# or if installed globally
sshm


Select a server to SSH into:
1) Root-Centos7-Linux  4) Root-MacbookPro     7) Kali-Linux
2) Root-Kali-Linux     5) Root-Rocky-Linux    8) MacbookPro-MeshNet
3) Rocky-Linux         6) MacbookPro          9) Centos7-Linux
Server #: <number>

# After selecting a server, it will connect via SSH while requesting your password if necessary.

```


### Display Config (`-d` / `--display`)

To print the contents of your SSH config and exit:

```bash
./sshm.sh -d
# or
./sshm.sh --display
```

---

## Script Details

The `sshm.sh` script includes all helper functions inline:

* **Environment Checks:**

  * `check_machine()` — Ensures OS is `darwin` (macOS) or `linux`.
  * `check_ssh()` — Verifies the `ssh` binary is available.
  * `ssh_config()` — Confirms that `~/.ssh/config` exists and is readable.
* **Config Parsing:**

  * `parse_config()` — Reads `SSH_CONFIG_FILE`, extracts `Host` entries into an array.
* **Menu & Arguments:**

  * `parse_arguments()` — Handles `-d`/`--display` flag.
  * `sshMenu()` — Displays an interactive prompt (using `select`) to choose a host.
* **Main Flow:**

  1. `parse_arguments "$@"` to check for display mode.
  2. If display flagged, show config and exit.
  3. Otherwise, run `sshMenu`.

---