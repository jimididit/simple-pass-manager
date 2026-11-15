#!/usr/bin/env bash
# Smoke test: throwaway vault; passphrases are fed to the script's own prompt via stdin.
set -euo pipefail
cd "$(dirname "$0")"
export PASSVAULT=$(mktemp -u); trap 'rm -f "$PASSVAULT"*' EXIT
PW=testpw
# 2nd line is only consumed when a new vault asks for confirmation
s() { printf '%s\n%s\n' "$PW" "$PW" | bash ./passgen.sh "$@"; }
S=s
fail() { echo "FAIL: $*"; exit 1; }

pw=$($S add github me 24 2>/dev/null)
[[ ${#pw} -eq 24 ]]
[[ $($S get github me) == "$pw" ]]
$S add github me 2>/dev/null && fail "dup allowed"
$S add "github2" me >/dev/null 2>&1          # prefix must not collide
[[ $($S list | wc -l) -eq 2 ]]
$S rm github me >/dev/null
$S get github me 2>/dev/null && fail "rm failed"
[[ $(stat -c %a "$PASSVAULT") == 600 ]]

# wrong passphrase must fail closed: no write, vault untouched
before=$(sha256sum <"$PASSVAULT")
printf 'wrongpw\n' | bash ./passgen.sh add evil me >/dev/null 2>&1 && fail "wrong passphrase add succeeded"
[[ $(sha256sum <"$PASSVAULT") == "$before" ]] || fail "vault changed on wrong passphrase"
[[ $($S list | wc -l) -eq 1 ]]

# one prompt per run: a single passphrase line is enough for a write on an existing vault
printf '%s\n' "$PW" | bash ./passgen.sh add once me >/dev/null 2>&1 || fail "add needed more than one passphrase entry"
printf '%s\n' "$PW" | bash ./passgen.sh rm once me >/dev/null 2>&1 || fail "rm needed more than one passphrase entry"

# new vault: mismatched confirmation must not create anything
printf 'a\nb\n' | PASSVAULT=$PASSVAULT.new bash ./passgen.sh add x y >/dev/null 2>&1 && fail "mismatch accepted"
[[ ! -e $PASSVAULT.new ]] || fail "vault created despite mismatch"

# import: old format, one dup of existing entry, one new
printf 'me:github2:abc!1\nbob:site.com:p@ss#9\n\n' >"$PASSVAULT.old"
$S import "$PASSVAULT.old" 2>/dev/null
[[ $($S get site.com bob) == 'p@ss#9' ]]
[[ $($S list | wc -l) -eq 2 ]]          # github2/me was already there

# list filter: case-insensitive, literal substring on site or user, never shows passwords
[[ $($S list GIT) == $'github2\tme' ]]
[[ $($S list SITE) == $'site.com\tbob' ]]
[[ $($S list .) == $'site.com\tbob' ]]      # "." is literal, not a regex wildcard
[[ -z $($S list zzz) ]]
[[ $($S list | wc -l) -eq 2 ]]
# optional user + --no-symbols (the Wi-Fi SSID case)
pw=$($S add Net10 --no-symbols 2>/dev/null)
[[ $pw =~ ^[A-Za-z0-9]{20}$ ]]
[[ $($S get Net10) == "$pw" && $($S get Net10 -) == "$pw" ]]
$S add Net10 2>/dev/null && fail "dup no-user allowed"
pw2=$($S add Net20 - 12 2>/dev/null); [[ ${#pw2} -eq 12 ]]
[[ $($S list | grep -c -- $'\t-$') -eq 2 ]]
$S rm Net10 >/dev/null; $S rm Net20 - >/dev/null
[[ $($S list | wc -l) -eq 2 ]]

# passwd: mismatch changes nothing and makes no backup
before=$($S list)
printf '%s\nnewpw\nother\n' "$PW" | bash ./passgen.sh passwd >/dev/null 2>&1 && fail "passwd mismatch accepted"
[[ $($S list) == "$before" ]]
[[ ! -e $(ls "$PASSVAULT".bak.* 2>/dev/null | head -1) ]] || fail "backup made on mismatch"
# passwd: real change; old passphrase stops working, new one opens the same data
printf '%s\nnewpw\nnewpw\n' "$PW" | bash ./passgen.sh passwd >/dev/null 2>&1
printf '%s\n' "$PW" | bash ./passgen.sh list >/dev/null 2>&1 && fail "old passphrase still works"
PW=newpw
[[ $($S list) == "$before" ]]
[[ $(ls "$PASSVAULT".bak.* | wc -l) -eq 1 ]]
echo OK
