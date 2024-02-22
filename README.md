# Simple Pass Manager

## Project Overview

Simple Pass Manager is a Bash script project that helps users generate secure, unique passwords for various services and websites. This tool is designed to enforce strong password practices by incorporating a mix of upper and lowercase letters, numbers, and special characters into the passwords it generates. Users can specify the desired password length, ensuring flexibility and security tailored to individual needs.

## Features

- Customizable password complexity with a mix of characters, numbers, and symbols.
- Unique password generation for each username and service combination.
- Adjustable password length, with a default of 8 and a maximum of 32 characters.
- Error handling to guide users through correct script usage.

## Prerequisites

Before you begin, ensure you have the following:
- A Bash shell environment.
- Permission to execute scripts on your system.

## Installation Instructions

1. **Clone the Repository:**
    ```bash
    git clone https://github.com/jimididit/simple-pass-manager.git
    ```
    This command downloads the project to your local machine.

2. **Navigate to the Project Directory:**
    ```bash
    cd simple-pass-manager
    ```
    Change into the project directory to execute script commands.

3. **Make the Script Executable:**
    ```bash
    chmod +x generate_password.sh
    ```
    This command updates the script's permissions, allowing it to be run.

## How to Use

The script accepts up to four arguments: length (optional), username, website, and the path to the `pass.txt` file.

- **Length**: Specify the desired password length. If not provided, defaults to 8 characters.
- **Username**: Your username or email associated with the service.
- **Website**: The website or service name.
- **File Path**: The relative path to the `pass.txt` file where the password will be stored.

### Example Command

```bash
./generate_password.sh 12 john.doe@example.com github ./pass.txt
```

This command generates a 12-character password for john.doe@example.com on github and saves it to ./pass.txt.

## Contributing
Your contributions are welcome! If you have suggestions for improvements or encounter any issues, feel free to fork the repository, make your changes, and submit a pull request.

## License
Simple Pass Manager is released under the MIT License. See the LICENSE file in the repository for more details.

## Acknowledgments
A big thank you to all contributors and those who have provided feedback and suggestions.
This project was inspired by the need for a user-friendly, secure password management solution.

## Disclaimer
Please note that this script is provided "as is" without warranty of any kind. Use it at your own risk. Always follow best practices for password management and security.
