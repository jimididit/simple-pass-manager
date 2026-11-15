#!/usr/bin/env bash
# Simple Pass Manager: one GPG-encrypted vault, generate/get/list/rm.
# Vault: $PASSVAULT or ~/.passvault.gpg. Format inside: site<TAB>user<TAB>password
set -euo pipefail
umask 077

VAULT=${PASSVAULT:-$HOME/.passvault.gpg}

# gpg with the passphrase handed over via a pipe, never argv. $1 = passphrase.
# We prompt ourselves exactly once per run (no --batch needed, no gpg-agent prompts).
gpgp() { local p=$1; shift; gpg --quiet --pinentry-mode loopback --passphrase-file <(printf %s "$p") "$@"; }

# prompt for a secret without echo -> $REPLY_PW
ask() {
  IFS= read -rsp "$1" REPLY_PW || { echo "Error: no passphrase given." >&2; exit 1; }
  if [[ -t 0 ]]; then echo >&2; fi
  [[ -n $REPLY_PW ]] || { echo "Error: passphrase can't be empty." >&2; exit 1; }
}

# ask for the master passphrase once -> $PASS. A brand-new vault asks twice so a typo can't lock you out.
unlock() {
  if [[ -f $VAULT ]]; then ask "Vault passphrase: "; PASS=$REPLY_PW; return; fi
  ask "New vault passphrase: "; PASS=$REPLY_PW
  ask "Confirm passphrase: "; [[ $REPLY_PW == "$PASS" ]] || { echo "Error: passphrases don't match." >&2; exit 1; }
}

usage() {
  cat >&2 <<EOF
Usage:
  $0 add  <site> [user] [length]   generate + store (default length 20, 8-64)
                                   user is optional; use - as user to set a length without one
  $0 get  <site> [user]            print password (user "-" = entry with no user)
  $0 import <file>                 import old plaintext user:site:password lines
Add -c to add/get to copy to clipboard (cleared after 30s) instead of printing.
Add --no-symbols to add for letters+digits only (some devices reject symbols).
  $0 list [filter]                 list site/user pairs (filter: case-insensitive substring)
  $0 rm   <site> [user]            delete entry
  $0 passwd                        change the master passphrase
Vault: $VAULT (set PASSVAULT to change)
EOF
  exit 1
}

# decrypted vault to stdout; empty only if no vault exists yet.
# A failed decrypt (wrong passphrase, corrupt file) must abort, never look like "empty".
read_vault() { [[ -f $VAULT ]] || return 0; gpgp "$PASS" -d "$VAULT"; }

# stdin -> encrypted vault, atomically
write_vault() {
  local tmp; tmp=$(mktemp "$VAULT.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  gpgp "$PASS" --yes -c --cipher-algo AES256 -o "$tmp" && mv "$tmp" "$VAULT"
}

check_field() {
  [[ -n $1 && $1 != *[$'\t\n\r']* ]] || { echo "Error: fields can't be empty or contain tabs/newlines." >&2; exit 1; }
}

gen() {
  local len=$1 pw chars='A-Za-z0-9!@#$%^&*_+=?-'
  [[ $nosym -eq 1 ]] && chars='A-Za-z0-9'
  while :; do
    pw=$(LC_ALL=C tr -dc "$chars" </dev/urandom | head -c "$len" || true)
    # require every character class so sites with policies accept it
    [[ $pw =~ [a-z] && $pw =~ [A-Z] && $pw =~ [0-9] && ( $nosym -eq 1 || $pw =~ [^A-Za-z0-9] ) ]] && { printf %s "$pw"; return; }
  done
}

# output a secret: stdout, or clipboard with -c
emit() {
  [[ $copy -eq 0 ]] && { printf '%s\n' "$1"; return; }
  local c
  if   [[ -n ${WAYLAND_DISPLAY:-} ]] && command -v wl-copy >/dev/null; then c=(wl-copy)
  elif command -v xclip   >/dev/null; then c=(xclip -selection clipboard)
  elif command -v pbcopy  >/dev/null; then c=(pbcopy)
  else echo "Error: no clipboard tool (wl-copy/xclip/pbcopy)." >&2; exit 1; fi
  printf %s "$1" | "${c[@]}"
  ( sleep 30; printf '' | "${c[@]}" ) >/dev/null 2>&1 & disown
  echo "Copied to clipboard (clears in 30s)." >&2
}

copy=0 nosym=0; args=()
for a in "$@"; do
  case $a in -c) copy=1 ;; --no-symbols) nosym=1 ;; *) args+=("$a") ;; esac
done
set -- ${args[@]+"${args[@]}"}
cmd=${1:-}; shift || true
case $cmd in
  add)
    [[ $# -ge 1 && $# -le 3 ]] || usage
    site=$1 user=${2:-} len=${3:-20}
    [[ $user == - ]] && user=""          # "-" = no user
    check_field "$site"; [[ -z $user ]] || check_field "$user"
    [[ $len =~ ^[0-9]+$ && $len -ge 8 && $len -le 64 ]] || { echo "Error: length must be 8-64." >&2; exit 1; }
    unlock
    data=$(read_vault)
    if awk -F'\t' -v s="$site" -v u="$user" '$1==s && $2==u {f=1} END{exit !f}' <<<"$data"; then
      echo "Error: entry for ${user:-(no user)} at $site already exists." >&2; exit 1
    fi
    pw=$(gen "$len")
    { [[ -n $data ]] && printf '%s\n' "$data"; printf '%s\t%s\t%s\n' "$site" "$user" "$pw"; } | write_vault
    echo "Saved ${user:+$user at }$site." >&2
    emit "$pw"
    ;;
  get)
    [[ $# -ge 1 && $# -le 2 ]] || usage
    unlock
    u=${2:-}; ex=0; [[ $# -eq 2 ]] && ex=1; [[ $u == - ]] && u=""   # explicit user (incl. "-") matches exactly
    out=$(read_vault | awk -F'\t' -v s="$1" -v u="$u" -v ex="$ex" '$1==s && (!ex && u=="" || $2==u) {print $2 "\t" $3}')
    [[ -n $out ]] || { echo "Not found." >&2; exit 1; }
    if [[ $(wc -l <<<"$out") -gt 1 ]]; then   # several users: show names only, ask to narrow
      echo "Multiple users for $1, specify one:" >&2; cut -f1 <<<"$out" >&2; exit 1
    fi
    emit "$(cut -f2 <<<"$out")"
    ;;
  import)
    [[ $# -eq 1 && -f $1 ]] || usage
    unlock
    data=$(read_vault)
    # old format user:site:password (password may not contain ':'); skip blanks/dups
    # existing site/user keys only (never passwords) arrive via fd, not argv
    new=$(awk -F: -v OFS='\t' '
      FNR==NR { split($0,f,"\t"); seen[f[1]"\t"f[2]]=1; next }
      NF>=3 && $1!="" && $2!="" { k=$2"\t"$1; if(!(k in seen)){seen[k]=1; print $2,$1,substr($0,length($1)+length($2)+3)} }' \
      <(printf '%s\n' "$data" | cut -f1,2) "$1")
    [[ -n $new ]] || { echo "Nothing new to import." >&2; exit 1; }
    { [[ -n $data ]] && printf '%s\n' "$data"; printf '%s\n' "$new"; } | write_vault
    echo "Imported $(wc -l <<<"$new") entries. Delete the plaintext file: shred -u $1" >&2
    ;;
  passwd)
    [[ -f $VAULT ]] || { echo "Error: no vault yet." >&2; exit 1; }
    unlock                                   # current passphrase
    data=$(read_vault)                       # aborts if wrong
    ask "New passphrase: "; np=$REPLY_PW
    ask "Confirm new passphrase: "; [[ $REPLY_PW == "$np" ]] || { echo "Error: passphrases don't match; vault unchanged." >&2; exit 1; }
    bak=$VAULT.bak.$(date +%s); cp -p "$VAULT" "$bak"
    tmp=$(mktemp "$VAULT.XXXXXX"); trap 'rm -f "$tmp"' EXIT
    printf '%s\n' "$data" | gpgp "$np" --yes -c --cipher-algo AES256 -o "$tmp"
    [[ $(gpgp "$np" -d "$tmp") == "$data" ]] || { echo "Error: verification failed; vault unchanged." >&2; exit 1; }
    mv "$tmp" "$VAULT"
    echo "Passphrase changed. Old vault (old passphrase) kept at $bak - delete it once the new one works: shred -u $bak" >&2
    ;;
  list)
    [[ $# -le 1 ]] || usage
    unlock
    read_vault | awk -F'\t' -v f="${1:-}" '
      BEGIN{f=tolower(f)}
      f=="" || index(tolower($1),f) || index(tolower($2),f) {print $1 "\t" ($2=="" ? "-" : $2)}' | sort
    ;;
  rm)
    [[ $# -ge 1 && $# -le 2 ]] || usage
    u=${2:--}; [[ $u == - ]] && u=""
    unlock
    data=$(read_vault)
    new=$(awk -F'\t' -v s="$1" -v u="$u" '!($1==s && $2==u)' <<<"$data")
    [[ $new != "$data" ]] || { echo "Not found." >&2; exit 1; }
    { [[ -n $new ]] && printf '%s\n' "$new" || true; } | write_vault
    echo "Removed."
    ;;
  *) usage ;;
esac
