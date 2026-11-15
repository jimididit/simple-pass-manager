# Simple Pass Manager

## Project Overview

Simple Pass Manager is a Bash script project that helps users generate secure, unique passwords for various services and websites, then lets users save new passwords to a local destination (preferably on an encrypted drive). This tool is designed to enforce strong password practices by incorporating a mix of upper and lowercase letters, numbers, and special characters into the passwords it generates, and elimate saving passwords on the cloud, which brings numerous risks. Users can specify the desired password length, ensuring flexibility and security tailored to individual needs, as well as the path of their passwords text file.

## Features

- Random passwords from `/dev/urandom`, always containing upper, lower, digit and symbol (default 20 chars, 8-64).
- Everything is stored in **one GPG-encrypted vault** (AES256, passphrase-protected) at `~/.passvault.gpg` (override with `PASSVAULT=/path`).
- `add`, `get`, `list`, `rm`, `import`, `passwd`. Exact-match duplicate detection per site + user.
- User is optional (e.g. Wi-Fi SSIDs), and `--no-symbols` gives letters+digits only for devices that reject symbols.

## Prerequisites

Bash, `gpg`, `awk` (all standard on Linux/macOS).

## Usage

```bash
chmod +x passgen.sh
./passgen.sh add github me@example.com 24   # generate, store, print
./passgen.sh add Net10 --no-symbols         # no user needed (e.g. Wi-Fi SSIDs); letters+digits only
./passgen.sh add Net20 - 12                 # "-" = no user, so you can still set a length
./passgen.sh get github me@example.com      # print password (user optional if only one)
./passgen.sh get -c github                  # copy to clipboard, auto-clears in 30s
./passgen.sh import old_pass.txt            # import old user:site:password lines
./passgen.sh list                           # site<TAB>user
./passgen.sh rm  github me@example.com      # user optional here too; use - for entries with no user
./passgen.sh passwd                         # change the master passphrase (keeps a timestamped backup)
./test.sh                                   # smoke test (throwaway vault)
```

Each command asks for the vault passphrase once (the very first `add` asks twice to confirm it). Nothing is cached between commands. **Don't lose it - there is no recovery.** Back up the vault file; it's safe to copy anywhere since it's encrypted.

> Note: this replaces the old plaintext `user:site:password` format. Use `import` to bring old entries in, then `shred -u` the plaintext file.

## Recovery

There is deliberately no backdoor: a lost passphrase means a lost vault.

1. Write the passphrase on paper and keep it somewhere physically secure (home safe, safe-deposit box), away from your computer and backups.
2. Keep copies of `~/.passvault.gpg` in a second place (USB drive, private cloud folder). It is safe to sync because it is encrypted.
3. Test once that a backup opens: `gpg -d backup.gpg`.

For shared/family vaults, consider splitting the passphrase with Shamir sharing (`ssss-split -t 2 -n 3`).

## Contributing
Your contributions are welcome! If you have suggestions for improvements or encounter any issues, feel free to fork the repository, make your changes, and submit a pull request.

## License
Simple Pass Manager is released under the MIT License. See the LICENSE file in the repository for more details.

## Acknowledgments
A big thank you to all contributors and those who have provided feedback and suggestions.
This project was inspired by the need for a user-friendly, secure password management solution.

## Disclaimer
Please note that this script is provided "as is" without warranty of any kind. Use it at your own risk. Always follow best practices for password management and security.

![Jimi Dab](./jimi_dab_cropped.png "Jimi Doing a Dab")
