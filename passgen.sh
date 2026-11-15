#!/usr/bin/env bash
# Simple Pass Manager: one GPG-encrypted vault, generate/get/list/rm.
# Vault: $PASSVAULT or ~/.passvault.gpg. Format inside: site<TAB>user<TAB>password
set -euo pipefail
umask 077

VAULT=${PASSVAULT:-$HOME/.passvault.gpg}
GPG=(gpg --quiet --batch --pinentry-mode loopback)  # ponytail: passphrase prompt per call; gpg-agent caches it

usage() {
  cat >&2 <<EOF
Usage:
  $0 add  <site> <user> [length]   generate + store (default length 20, 8-64)
  $0 get  <site> [user]            print password
  $0 import <file>                 import old plaintext user:site:password lines
Add -c to add/get to copy to clipboard (cleared after 30s) instead of printing.
  $0 list                          list site/user pairs
  $0 rm   <site> <user>            delete entry
Vault: $VAULT (set PASSVAULT to change)
EOF
  exit 1
}

# decrypted vault to stdout (empty if no vault yet)
read_vault() { [[ -f $VAULT ]] && "${GPG[@]}" -d "$VAULT" || true; }

# stdin -> encrypted vault, atomically
write_vault() {
  local tmp; tmp=$(mktemp "$VAULT.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  "${GPG[@]}" --yes -c --cipher-algo AES256 -o "$tmp" && mv "$tmp" "$VAULT"
}

check_field() {
  [[ -n $1 && $1 != *[$'\t\n\r']* ]] || { echo "Error: fields can't be empty or contain tabs/newlines." >&2; exit 1; }
}

gen() {
  local len=$1 pw
  while :; do
    pw=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*_+=?-' </dev/urandom | head -c "$len" || true)
    # require every character class so sites with policies accept it
    [[ $pw =~ [a-z] && $pw =~ [A-Z] && $pw =~ [0-9] && $pw =~ [^A-Za-z0-9] ]] && { printf %s "$pw"; return; }
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

copy=0; args=()
for a in "$@"; do [[ $a == -c ]] && copy=1 || args+=("$a"); done
set -- ${args[@]+"${args[@]}"}
cmd=${1:-}; shift || true
case $cmd in
  add)
    [[ $# -ge 2 && $# -le 3 ]] || usage
    site=$1 user=$2 len=${3:-20}
    check_field "$site"; check_field "$user"
    [[ $len =~ ^[0-9]+$ && $len -ge 8 && $len -le 64 ]] || { echo "Error: length must be 8-64." >&2; exit 1; }
    data=$(read_vault)
    if awk -F'\t' -v s="$site" -v u="$user" '$1==s && $2==u {f=1} END{exit !f}' <<<"$data"; then
      echo "Error: entry for $user at $site already exists." >&2; exit 1
    fi
    pw=$(gen "$len")
    { [[ -n $data ]] && printf '%s\n' "$data"; printf '%s\t%s\t%s\n' "$site" "$user" "$pw"; } | write_vault
    echo "Saved $user at $site." >&2
    emit "$pw"
    ;;
  get)
    [[ $# -ge 1 && $# -le 2 ]] || usage
    out=$(read_vault | awk -F'\t' -v s="$1" -v u="${2:-}" '$1==s && (u=="" || $2==u) {print $2 "\t" $3}')
    [[ -n $out ]] || { echo "Not found." >&2; exit 1; }
    if [[ $(wc -l <<<"$out") -gt 1 ]]; then   # several users: show names only, ask to narrow
      echo "Multiple users for $1, specify one:" >&2; cut -f1 <<<"$out" >&2; exit 1
    fi
    emit "$(cut -f2 <<<"$out")"
    ;;
  import)
    [[ $# -eq 1 && -f $1 ]] || usage
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
  list) read_vault | awk -F'\t' '{print $1 "\t" $2}' | sort ;;
  rm)
    [[ $# -eq 2 ]] || usage
    data=$(read_vault)
    new=$(awk -F'\t' -v s="$1" -v u="$2" '!($1==s && $2==u)' <<<"$data")
    [[ $new != "$data" ]] || { echo "Not found." >&2; exit 1; }
    { [[ -n $new ]] && printf '%s\n' "$new" || true; } | write_vault
    echo "Removed."
    ;;
  *) usage ;;
esac
