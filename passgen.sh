#!/bin/bash

# Set minimum and maximum length for the password
MIN_LENGTH=8
MAX_LENGTH=32

# Assigning input arguments to variables with defaults
length=${1:-8}
username=$2
website=$3
file_path=$4

# Check if the length argument is within the allowed range
if [[ $length -lt $MIN_LENGTH || $length -gt $MAX_LENGTH ]]; then
  echo "Error: Password length must be between $MIN_LENGTH and $MAX_LENGTH."
  exit 1
fi

# Check for mandatory fields
if [[ -z "$username" || -z "$website" || -z "$file_path" ]]; then
    echo "Usage: $0 [length] <username> <website> <file_path>"
    exit 1
fi

# Generating a random password
generate_password() {
    tr -dc 'A-Za-z0-9_!@#$%^&*' </dev/urandom | head -c $length
}

# Check if the username and website combination already exists
check_duplicate() {
    grep -q "$username:$website" "$file_path"
}

# Main function
main() {
    if check_duplicate; then
        echo "A password for this user and website/service already exists."
        exit 1
    else
        password=$(generate_password)
        echo "$username:$website:$password" >> "$file_path"
        echo "Password for $username at $website has been generated and saved."
    fi
}

# Execute main function
main
