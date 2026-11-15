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
# import: old format, one dup of existing entry, one new
printf 'me:github2:abc!1\nbob:site.com:p@ss#9\n\n' >"$PF.old"
$S import "$PF.old" 2>/dev/null
[[ $($S get site.com bob) == 'p@ss#9' ]]
[[ $($S list | wc -l) -eq 2 ]]          # github2/me was already there
rm -f "$PF" "$PF.sh" "$PF.old"; echo OK
