#!/usr/bin/env bash

#
# SSHM - SSHMenu
#
# Description: Interactive SSH host selector that reads from ~/.ssh/config.
# Version: 1.0.0
# Author: Yousef Abuzahrieh
# GitHub: https://github.com/yousefabuz17/SSHMenu.git
# Requirements: bash 4+, ssh client, ~/.ssh/config file | /etc/ssh/ssh_config
# Compatibility: macOS, Linux
#
# Notes:
# - Not tested on Windows (contributions welcome)
# - Easily extendable with aliasing or remote command execution


SSHM_VERSION=1.0.3


function check_machine(){
    OS_MACHINE="$(awk -F- '{gsub(/[0-9.]/, "", $1); print $1}' <<< "$OSTYPE")"
    
    [[ $OS_MACHINE != 'darwin' && $OS_MACHINE != 'linux' ]] && 
        {
            echo "Error: Detected OS '$OS_MACHINE' - this script requires MacOS (darwin) or Linux"
            exit 1
        }

    if ((BASH_VERSINFO[0] < 4)); then
        echo "Error: This script requires Bash version 4.0 or higher." >&2
        exit 1
    fi

    export OS_MACHINE
}


function get_home(){
    [[ -z "$OS_MACHINE" ]] && check_machine

    HOME_DIR=""
    PARENT_HOME=""

    function find_user(){
        local home_dir="$1"

        HOME_DIR=$(find "$home_dir" -maxdepth 1 -type d ! -path "$home_dir" | head -n 1)
        MAIN_USER="${HOME_DIR##*/}"
    }


    case $OS_MACHINE in
        darwin)
            { [[ -n "$HOME" ]] && HOME_DIR="$HOME" ;}
            PARENT_HOME="/Users"
            ;;
        linux)
            { [[ -n "$XDG_DESKTOP_DIR" ]] && HOME_DIR="$XDG_DESKTOP_DIR" ;}
            PARENT_HOME="/home"
            ;;
    esac

    [[ -z "$HOME_DIR" ]] && find_user "$PARENT_HOME"

    export HOME_DIR MAIN_USER
}


function ansi_codes(){
    UNDERLINE="$(tput smul)"
    BOLD="$(tput bold)"
    RESET="$(tput sgr0)"
    export UNDERLINE BOLD RESET
}


function help_page() {
    ansi_codes

    cat <<EOF

${UNDERLINE}${BOLD}Usage:${RESET} sshm.sh [OPTIONS]

${UNDERLINE}${BOLD}Options:${RESET}
    ${BOLD}-c, --config${RESET} <CONFIG>...
            Specify a custom SSH config file path (Default: ~/.ssh/config | /etc/ssh/ssh_config)
    ${BOLD}-d, --display${RESET}
            Display contents of (~/.ssh/config | /etc/ssh/ssh_config)
    ${BOLD}-V, --version${RESET}
            Show script version
    ${BOLD}-E, --exit${RESET}
            Exit the SSH menu after connecting to a server
    ${BOLD}-h, --help${RESET}
            Show this help message
EOF
}



function validate_file(){
    local config_file="$1"
    local raise_err="${2:-true}"
    local msg=""
    local -i exitCode=0

    [[ ! -f "$config_file" ]] && {
        msg="'($SSH_CONFIG_FILE)' was not found in the home directory. Script cannot proceed without it." 2>&1
        exitCode=1
    }

    [[ ! -r "$config_file" || ! -w "$config_file" ]] && {
        msg="'($config_file)' is not readable or writable. Please check permissions." 2>&1
        exitCode=1
    }

    [[ ! -s "$config_file" ]] && {
        msg="'($config_file)' is empty. Please add SSH configurations." 2>&1
        exitCode=1
    }

    if [[ "$raise_err" == true ]]; then
        echo "$msg"
        exit $exitCode
    else
        return $exitCode
    fi

}



function ssh_config(){
    [[ -z "$HOME_DIR" ]] && get_home

    function check_file(){ validate_file "$1" false ;}
    
    if check_file "${HOME_DIR}/.ssh/config"; then
        SSH_CONFIG_FILE="${HOME_DIR}/.ssh/config"
    elif check_file "/etc/ssh/ssh_config"; then
        SSH_CONFIG_FILE="/etc/ssh/ssh_config"
    else
        echo "Error: No valid SSH config file found. Please create one at ~/.ssh/config or /etc/ssh/ssh_config." >&2
        exit 1
    fi

    export SSH_CONFIG_FILE
}

function check_ssh(){
    ssh -V &>/dev/null || {
        echo "Error: SSH is not installed. Please install SSH to proceed."
        exit 1
    }
}


function source_config(){ [[ -z "$SSH_CONFIG_FILE" ]] && ssh_config ;}


function parse_config(){
    function get_value(){
        awk '{print $2}' <<< "$1"
    }

    declare -gA KNOWN_HOSTS
    declare -gA KH_SETTINGS
    
    source_config

    while IFS= read -r line; do
        [[ -z $line || $line =~ ^# ]] && continue

        if [[ $line =~ ^Host ]]; then
                current_host=$(get_value "$line")
                KNOWN_HOSTS["$current_host"]="${KH_SETTINGS[*]}"

                for key in "User" "HostName" "Port"; do
                    if [[ $line =~ $key ]]; then
                        value=$(get_value "$line")
                        KH_SETTINGS[$key]=$value
                    fi
                done
            fi
    done < "$SSH_CONFIG_FILE"

    if [[ ${#KNOWN_HOSTS[@]} -eq 0 ]]; then
        echo "No valid SSH hosts found in '$SSH_CONFIG_FILE'. Please add SSH configurations." >&2
        exit 1
    fi
}


function view_ssh_cf(){
    source_config
    cat "$SSH_CONFIG_FILE"
}


function parse_arguments(){
    local args=("$@")

    [[ "${#args}" -eq 0 ]] && sshMenu

    SSH_CONFIG_FILE=""
    EXIT_SSH=false

    for arg in "${args[@]}";
    do
        if [[ -n $arg && $arg = -* ]]; then
            case $arg in
                -d|--display)
                    view_ssh_cf
                    exit 0
                    ;;
                -V|--version) echo "$SSHM_VERSION" ;;
                -c|--config)
                    SSH_CONFIG_FILE="$(eval echo "$2")"
                    shift 2
                    ;;
                -E|--exit) EXIT_SSH=true ;;
                -h|--help)
                    help_page
                    exit 0
                    ;;
                *)
                    echo "'($arg)' is an invalid argument. Please use flag (-h|--help) for further assistance." >&2
                    exit 1
                    ;;
            esac
        fi
    done

    export EXIT_SSH

    source_config

    [[ -n "$SSH_CONFIG_FILE" ]] && {
        validate_file "$SSH_CONFIG_FILE"
        sshMenu
    }
}


sshMenu(){
    trap 'echo -e "\nSSHMenu Terminated."; exit 0' SIGINT
    
    local PS3=$"Server #: "
    local server
    local -i server_num
    local -i num_hosts="${#KNOWN_HOSTS[@]}"

    check_ssh
    parse_config

    echo -e "\nSelect a server to SSH into (1-$num_hosts):\n"
    
    select server in "${!KNOWN_HOSTS[@]}"
    do
        server_num="${REPLY//[^0-9]/}"
        num_hosts="${#KNOWN_HOSTS[@]}"
        
        if ((server_num < 1 || server_num > num_hosts)); then
            echo "${server_num} is out of range. Please try again. (CTRL+C to quit)" >&2
            continue
        fi

        if [[ -n $server ]]; then
            ssh "$server"
            [[ "$EXIT_SSH" == true ]] && exit 0
            echo -e "\nSelect another server. (CTRL+C to quit)"
            continue
        else
            echo "Invalid option. Please try again. (CTRL+C to quit)" >&2
        fi
    done
}


if [[ "$0" != "${BASH_SOURCE[0]}" ]]; then
    export -f sshMenu
else
    parse_arguments "$@"
fi