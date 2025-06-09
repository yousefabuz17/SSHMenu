#!/usr/bin/env bash

function check_machine(){
    OS_MACHINE="$(awk -F- '{gsub(/[0-9.]/, "", $1); print $1}' <<< "$OSTYPE")"
    [[ $OS_MACHINE != 'darwin' && $OS_MACHINE != 'linux' ]] && 
    {
        echo "Error: Detected OS '$OS_MACHINE' - this script requires MacOS (darwin) or Linux"
        exit 1
    }
    export OS_MACHINE
}


function get_home(){
    [[ -z "$OS_MACHINE" ]] && check_machine

    function find_user(){
        local home_dir="$1"

        HOME_DIR=$(find "$home_dir" -maxdepth 1 -type d ! -path "$home_dir" | head -n 1)
        MAIN_USER="${HOME_DIR##*/}"
        export HOME_DIR MAIN_USER
    }

    case $OS_MACHINE in
        darwin) find_user /Users ;;
        linux) find_user /home ;;
    esac
}



function ssh_config(){
    { [[ -n "$HOME" ]] && HOME_DIR="$HOME" ;} || get_home

    SSH_CONFIG_FILE="${HOME_DIR}/.ssh/config"

    [[ ! -f "$SSH_CONFIG_FILE" ]] && {
        echo "'($SSH_CONFIG_FILE)' was not found in the home directory. Script cannot proceed without it." 2>&1
        exit 1
    }

    [[ ! -r "$SSH_CONFIG_FILE" || ! -w "$SSH_CONFIG_FILE" ]] && {
        echo "'($SSH_CONFIG_FILE)' is not readable or writable. Please check permissions." 2>&1
        exit 1
    }

    [[ ! -s "$SSH_CONFIG_FILE" ]] && {
        echo "'($SSH_CONFIG_FILE)' is empty. Please add SSH configurations." 2>&1
        exit 1
    }
    export SSH_CONFIG_FILE
}

function check_ssh(){
    ssh -V &>/dev/null || {
        echo "Error: SSH is not installed. Please install SSH to proceed."
        exit 1
    }
}


function parse_config(){
    function get_value(){
        awk '{print $2}' <<< "$1"
    }

    declare -g -A KNOWN_HOSTS
    declare -g -A KH_SETTINGS
    
    [[ -z "$SSH_CONFIG_FILE" ]] && ssh_config

    while IFS= read -r line; do
        [[ -z $line || $line =~ ^# ]] && continue

        if [[ $line =~ ^Host ]]; then
            current_host=$(get_value "$line")
            KNOWN_HOSTS["$current_host"]="${KH_SETTINGS[*]}"
        fi

        for key in "User" "HostName" "Port"; do
            if [[ $line =~ $key ]]; then
                value=$(get_value "$line")
                KH_SETTINGS[$key]=$value
            fi
        done
    done < "$SSH_CONFIG_FILE"

    export KNOWN_HOSTS
}


function view_ssh_cf(){
    [[ -z "$SSH_CONFIG_FILE" ]] && ssh_config
    cat "$SSH_CONFIG_FILE"
}


function parse_arguments(){
    local args=("$@")

    [[ "${#args}" -eq 0 ]] && sshMenu

    for arg in "${args[@]}";
    do
        if [[ -n $arg && $arg = -* ]]; then
            case $arg in
                -d|--display) view_ssh_cf ;;
                *)
                    echo "'($arg)' is an invalid argument." >&2
                    exit 1
                    ;;
            esac
        fi
    done
}


sshMenu(){
    trap 'echo -e "\nSSHManager Terminated."; exit 1' SIGINT
    
    local PS3=$"Server #: "

    parse_config
    echo -e "\nSelect a server to SSH into:"
    
    select server in "${!KNOWN_HOSTS[@]}"
    do
        if [[ -n $server ]]; then
            ssh "$server"
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