# Automating User and Group Management with a Bash Script

Managing user accounts and groups is a common task for system administrators. Automating this process not only saves time but also reduces the risk of errors. In this article, we will walk through a bash script that automates the creation of users and groups on a Linux system. This script reads from a text file, creates users and their respective groups, sets up home directories with appropriate permissions, generates random passwords, and logs all actions.

## Script Overview

Our script, `create_users.sh`, performs the following tasks:
1. Checks if the script is run as root.
2. Reads a text file containing usernames and groups.
3. Creates users and their groups as specified.
4. Sets up home directories with proper permissions.
5. Generates random passwords for the users.
6. Logs all actions to `/var/log/user_management.log`.
7. Stores the generated passwords securely in `/var/secure/user_passwords.csv`.

## Script Breakdown

### Ensure Script is Run as Root

```bash
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi
```
This ensures that the script is executed with root privileges, which are necessary for creating users and groups.

### Input File Check
```bash
if [ -z "$1" ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi
```
This checks if the input file containing usernames and groups is provided.

### Setup Directories and Files
```bash
mkdir -p /var/secure
chmod 700 /var/secure
> "/var/log/user_management.log"
> "/var/secure/user_passwords.csv"
chmod 600 "/var/secure/user_passwords.csv"
```
We create the necessary directories and files, setting appropriate permissions to ensure security.

### Logging Function
```bash
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "/var/log/user_management.log"
}
```
This function logs actions with a timestamp to /var/log/user_management.log.

### Create User Function
```bash
create_user() {
    local user="$1"
    local groups="$2"
    local password

    if id "$user" &>/dev/null; then
        log_action "User $user already exists."
        return
    fi

    groupadd "$user"
    IFS=',' read -ra group_array <<< "$groups"
    log_action "User $user will be added to groups: ${group_array[*]}"

    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)
        if ! getent group "$group" > /dev/null; then
            groupadd "$group"
            log_action "Group $group created."
        fi
    done

    useradd -m -s /bin/bash -g "$user" "$user"
    if [ $? -eq 0 ]; then
        log_action "User $user created with primary group: $user"
    else
        log_action "Failed to create user $user."
        return
    fi

    for group in "${group_array[@]}"; do
        usermod -aG "$group" "$user"
    done
    log_action "User $user added to groups: ${group_array[*]}"

    password=$(</dev/urandom tr -dc A-Za-z0-9 | head -c 12)
    echo "$user:$password" | chpasswd
    echo "$user,$password" >> "/var/secure/user_passwords.csv"
    chmod 700 "/home/$user"
    chown "$user:$user" "/home/$user"

    log_action "Password for user $user set and stored securely."
}
```
This function handles user and group creation, password generation, and logging.

### Process Input File
```bash
while IFS=';' read -r user groups; do
    user=$(echo "$user" | xargs)
    groups=$(echo "$groups" | xargs | tr -d ' ')
    groups=$(echo "$groups" | tr ',' ' ')
    create_user "$user" "$groups"
done < "$1"

echo "User creation process completed. Check /var/log/user_management.log for details."
```
This section reads the input file line by line, processes each user and their groups, and calls the create_user function.
