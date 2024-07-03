#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Check for input file argument
if [ -z "$1" ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

INPUT_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure /var/secure directory exists
mkdir -p /var/secure
chmod 700 /var/secure

# Create or clear the log and password files
> "$LOG_FILE"
> "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Function to log actions to log file
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

create_user() {
    local user="$1"
    local groups="$2"
    local password

    # Check if user already exists
    if id "$user" &>/dev/null; then
        log_action "User $user already exists."
        return
    fi

    # Create personal group for the user
    groupadd "$user"

    # Create additional groups if they do not exist
    IFS=',' read -ra group_array <<< "$groups"
    log_action "User $user will be added to groups: ${group_array[*]}"

    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)  # Trim whitespace
        if ! getent group "$group" > /dev/null; then
            groupadd "$group"
            log_action "Group $group created."
        fi
    done

    # Create user with home directory and shell, primary group set to the personal group
    useradd -m -s /bin/bash -g "$user" "$user"
    if [ $? -eq 0 ]; then
        log_action "User $user created with primary group: $user"
    else
        log_action "Failed to create user $user."
        return
    fi

    # Add the user to additional groups
    for group in "${group_array[@]}"; do
        usermod -aG "$group" "$user"
    done
    log_action "User $user added to groups: ${group_array[*]}"

    # Generate password and store it securely in a file
    password=$(</dev/urandom tr -dc A-Za-z0-9 | head -c 12)
    echo "$user:$password" | chpasswd

    # Store user and password securely in a file
    echo "$user,$password" >> "$PASSWORD_FILE"

    # Set permissions and ownership for user home directory
    chmod 700 "/home/$user"
    chown "$user:$user" "/home/$user"

    log_action "Password for user $user set and stored securely."
}

# Read user list file and create users
while IFS=';' read -r user groups; do
    user=$(echo "$user" | xargs)
    groups=$(echo "$groups" | xargs | tr -d ' ')

    # Replace commas with spaces for usermod group format
    groups=$(echo "$groups" | tr ',' ' ')
    create_user "$user" "$groups"
done < "$INPUT_FILE"

echo "User creation process completed. Check $LOG_FILE for details."
