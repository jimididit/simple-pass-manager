#!/usr/bin/env bash
# Smoke test: uses a throwaway vault + passphrase.
set -euo pipefail
cd "$(dirname "$0")"
export PASSVAULT=$(mktemp -u) ; trap 'rm -f "$PASSVAULT"*' EXIT
export GPG_TTY= ; PF=$(mktemp); echo testpw >"$PF"
# inject passphrase for the test only
sed 's|--pinentry-mode loopback|--pinentry-mode loopback --passphrase-file '"$PF"'|' passgen.sh >"$PF.sh"
S="bash $PF.sh"
pw=$($S add github me 24 | tail -1)
[[ ${#pw} -eq 24 ]]
[[ $($S get github me) == "$pw" ]]
$S add github me 2>/dev/null && { echo "dup allowed"; exit 1; }
$S add "github2" me >/dev/null          # prefix must not collide
[[ $($S list | wc -l) -eq 2 ]]
$S rm github me >/dev/null
$S get github me 2>/dev/null && { echo "rm failed"; exit 1; }
[[ $(stat -c %a "$PASSVAULT") == 600 ]]
# wrong passphrase must fail closed: no write, vault untouched
echo wrongpw >"$PF.bad"
sed 's|--passphrase-file [^ )]*|--passphrase-file '"$PF.bad"'|' "$PF.sh" >"$PF.bad.sh"
before=$(sha256sum <"$PASSVAULT")
bash "$PF.bad.sh" add evil me >/dev/null 2>&1 && { echo "wrong passphrase add succeeded"; exit 1; }
[[ $(sha256sum <"$PASSVAULT") == "$before" ]] || { echo "vault changed on wrong passphrase"; exit 1; }
[[ $($S list | wc -l) -eq 1 ]]
rm -f "$PF.bad" "$PF.bad.sh"
# import: old format, one dup of existing entry, one new
printf 'me:github2:abc!1\nbob:site.com:p@ss#9\n\n' >"$PF.old"
$S import "$PF.old" 2>/dev/null
[[ $($S get site.com bob) == 'p@ss#9' ]]
[[ $($S list | wc -l) -eq 2 ]]          # github2/me was already there
# optional user + --no-symbols (the Wi-Fi SSID case)
pw=$($S add Net10 --no-symbols 2>/dev/null)
[[ $pw =~ ^[A-Za-z0-9]{20}$ ]]
[[ $($S get Net10) == "$pw" && $($S get Net10 -) == "$pw" ]]
$S add Net10 2>/dev/null && { echo "dup no-user allowed"; exit 1; }
pw2=$($S add Net20 - 12 2>/dev/null); [[ ${#pw2} -eq 12 ]]
[[ $($S list | grep -c -- $'\t-$') -eq 2 ]]
$S rm Net10 >/dev/null; $S rm Net20 - >/dev/null
[[ $($S list | wc -l) -eq 2 ]]
rm -f "$PF" "$PF.sh" "$PF.old"; echo OK
