#!/usr/bin/env bash
# Portable zsh installer: works from a git checkout or straight from curl.
set -euo pipefail

REPO_SLUG="${ZSH_CONFIG_REPO:-chao2hang/zsh-config}"
BRANCH="${ZSH_CONFIG_BRANCH:-main}"
RAW_BASE="${ZSH_CONFIG_RAW_BASE:-https://raw.githubusercontent.com/${REPO_SLUG}/${BRANCH}}"

SCRIPT_DIR=""
if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

WITH_OMZ=1
WITH_STARSHIP=1
CHANGE_SHELL=1
ASSUME_YES=0
[[ -t 0 ]] || ASSUME_YES=1

usage() {
  cat <<'EOF'
Usage: install.sh [options]

  --minimal        skip oh-my-zsh and starship (plain zsh only)
  --no-omz         skip oh-my-zsh
  --no-starship    skip starship
  --no-chsh        leave the login shell unchanged
  -y, --yes        do not prompt before installing packages
  -h, --help       show this help

Existing ~/.zshrc is backed up to ~/.zshrc.bak.<timestamp>.
When stdin is not a terminal, prompts are skipped automatically.
EOF
}

for arg in "$@"; do
  case $arg in
    --minimal) WITH_OMZ=0; WITH_STARSHIP=0 ;;
    --no-omz) WITH_OMZ=0 ;;
    --no-starship) WITH_STARSHIP=0 ;;
    --no-chsh) CHANGE_SHELL=0 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $arg" >&2; usage; exit 1 ;;
  esac
done

SUDO=""
if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

RESOLVED_ZSHRC=""
TMP_ZSHRC=""

run() { echo "+ $*"; "$@"; }

warn() { echo "warning: $*" >&2; }

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local reply=""
  read -r -p "$1 [y/N] " reply < /dev/tty || true
  [[ $reply == [yY]* ]]
}

cleanup() {
  if [[ -n ${TMP_ZSHRC:-} ]]; then
    rm -f "$TMP_ZSHRC"
  fi
  return 0
}
trap cleanup EXIT

# Installing into /root because of "sudo ./install.sh" is almost never intended.
if [[ $EUID -eq 0 && -n ${SUDO_USER:-} && ${SUDO_USER} != root ]]; then
  echo "error: run as ${SUDO_USER}, not through sudo (otherwise config lands in /root)" >&2
  exit 1
fi

install_packages() {
  local pkgs=(zsh git curl)
  if command -v apt-get >/dev/null 2>&1; then
    confirm "Install ${pkgs[*]} with apt-get?" || return 1
    $SUDO apt-get update -y || true
    run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    confirm "Install ${pkgs[*]} with dnf?" || return 1
    run $SUDO dnf install -y "${pkgs[@]}"
  elif command -v yum >/dev/null 2>&1; then
    confirm "Install ${pkgs[*]} with yum?" || return 1
    run $SUDO yum install -y "${pkgs[@]}"
  elif command -v apk >/dev/null 2>&1; then
    confirm "Install ${pkgs[*]} with apk?" || return 1
    run $SUDO apk add --no-cache "${pkgs[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    confirm "Install ${pkgs[*]} with pacman?" || return 1
    run $SUDO pacman -Sy --noconfirm "${pkgs[@]}"
  elif command -v zypper >/dev/null 2>&1; then
    confirm "Install ${pkgs[*]} with zypper?" || return 1
    run $SUDO zypper --non-interactive install "${pkgs[@]}"
  else
    warn "no supported package manager; install zsh/git/curl manually"
    return 1
  fi
}

ensure_base_tools() {
  local missing=0 cmd
  for cmd in zsh git curl; do
    command -v "$cmd" >/dev/null 2>&1 || missing=1
  done
  [[ $missing -eq 0 ]] && return 0
  if ! install_packages; then
    command -v zsh >/dev/null 2>&1 || { echo "error: zsh is required" >&2; exit 1; }
  fi
}

install_omz() {
  if [[ -f $HOME/.oh-my-zsh/oh-my-zsh.sh ]]; then
    return 0
  fi
  if [[ -d $HOME/.oh-my-zsh ]]; then
    warn "$HOME/.oh-my-zsh exists but looks incomplete; skipping"
    return 0
  fi
  command -v git >/dev/null 2>&1 || { warn "git missing; skipping oh-my-zsh"; return 0; }
  run git clone --depth=1 --quiet https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" \
    || warn "oh-my-zsh clone failed; config falls back to plain zsh"
}

install_starship() {
  command -v starship >/dev/null 2>&1 && return 0
  command -v curl >/dev/null 2>&1 || { warn "curl missing; skipping starship"; return 0; }
  local bindir="$HOME/.local/bin"
  [[ $EUID -eq 0 ]] && bindir="/usr/local/bin"
  mkdir -p "$bindir"
  if ! run curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$bindir"; then
    warn "starship install failed; config falls back to a plain prompt"
  fi
}

resolve_zshrc() {
  if [[ -n $SCRIPT_DIR && -f $SCRIPT_DIR/zshrc ]]; then
    RESOLVED_ZSHRC="$SCRIPT_DIR/zshrc"
    return 0
  fi
  local url="$RAW_BASE/zshrc"
  TMP_ZSHRC="$(mktemp "${TMPDIR:-/tmp}/zshrc.XXXXXX")"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$TMP_ZSHRC" || { echo "error: cannot download $url" >&2; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP_ZSHRC" "$url" || { echo "error: cannot download $url" >&2; return 1; }
  else
    echo "error: need curl or wget to fetch zshrc" >&2
    return 1
  fi
  if ! grep -q 'Portable zsh config' "$TMP_ZSHRC"; then
    echo "error: $url did not return a valid config" >&2
    return 1
  fi
  RESOLVED_ZSHRC="$TMP_ZSHRC"
}

install_config() {
  local source
  resolve_zshrc
  source="$RESOLVED_ZSHRC"
  local target="$HOME/.zshrc"
  if [[ -f $target && ! -L $target ]]; then
    local backup="$target.bak.$(date +%Y%m%d-%H%M%S)"
    run cp "$target" "$backup"
    echo "backed up old config to $backup"
  fi
  run cp "$source" "$target.tmp"
  run mv "$target.tmp" "$target"
}

set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ ${SHELL:-} == "$zsh_path" ]]; then
    return 0
  fi
  if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null
  fi
  if command -v chsh >/dev/null 2>&1; then
    if $SUDO chsh -s "$zsh_path" "$(id -un)"; then
      echo "default shell changed to $zsh_path (re-login to apply)"
      return 0
    fi
  fi
  warn "could not change login shell; run: chsh -s $zsh_path"
}

ensure_base_tools
if [[ $WITH_OMZ -eq 1 ]]; then install_omz; fi
if [[ $WITH_STARSHIP -eq 1 ]]; then install_starship; fi
install_config
if [[ $CHANGE_SHELL -eq 1 ]]; then set_default_shell; fi

echo
echo "done: $(zsh --version), config at $HOME/.zshrc"
echo "start a new login shell or run: exec zsh"
