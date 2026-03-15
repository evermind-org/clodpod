#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "${BASH_SOURCE[0]}: line $LINENO: $BASH_COMMAND: exitcode $?"' ERR
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


###############################################################################
# Functions
###############################################################################
[[ "${VERBOSE:-0}" =~ ^[0-9]+$ ]] && VERBOSE="${VERBOSE:-0}" || VERBOSE=1
trace () {
    [[ "$VERBOSE" -lt 2 ]] || echo >&2 -e "🔬 \033[36m$*\033[0m"
}
debug () {
    [[ "$VERBOSE" -lt 1 ]] || echo >&2 -e "🔍 \033[36m$*\033[0m"
}
info () {
    echo >&2 -e "ℹ️ \033[36m$*\033[0m"
}
warn () {
    echo >&2 -e "⚠️ \033[33m$*\033[0m"
}
error () {
    echo >&2 -e "❌ \033[31m$*\033[0m"
}
abort () {
    error "$*"
    exit 1
}


###############################################################################
# Preconditions
###############################################################################
if [[ $OSTYPE != 'darwin'* ]]; then
    abort "ERROR: this script is for Mac OSX"
fi


###############################################################################
# Wait for directory services to load (needed after VM clone/boot)
###############################################################################
debug "Waiting for directory services..."
for i in $(seq 1 10); do
    if dscl . -read /Users/clodpod &>/dev/null 2>&1; then
        break
    fi
    sleep 1
done

###############################################################################
# Rename the computer
###############################################################################
sudo scutil --set ComputerName "clodpod-xcode"
sudo scutil --set LocalHostName "clodpod-xcode"
sudo scutil --set HostName "clodpod-xcode"


###############################################################################
# Configure clodpod user
###############################################################################
debug "Configure clodpod user..."

# Copy files to home directory
DIST_DIR="/Volumes/My Shared Files/__install"
sudo mkdir -p "/Users/clodpod"
sudo cp -rf "$DIST_DIR/home/." "/Users/clodpod/"

# Make clodpod the owner of the files
# Use numeric UID:GID — directory services may not resolve names after clone
CLODPOD_UID=$(dscl . -read /Users/clodpod UniqueID 2>/dev/null | awk '{print $2}' || true)
CLODPOD_GID=$(dscl . -read /Groups/clodpod PrimaryGroupID 2>/dev/null | awk '{print $2}' || true)
if [[ -n "$CLODPOD_UID" && -n "$CLODPOD_GID" ]]; then
    sudo chown -R "$CLODPOD_UID:$CLODPOD_GID" "/Users/clodpod"
elif id -u clodpod &>/dev/null; then
    sudo chown -R "$(id -u clodpod):$(id -g clodpod)" "/Users/clodpod"
else
    warn "clodpod user not found — skipping chown"
fi

# Fixup file permissions
sudo chmod 755 "/Users/clodpod"
sudo chmod 700 "/Users/clodpod/.ssh"
if [[ -f "/Users/clodpod/.ssh/authorized_keys" ]]; then
    sudo chmod 600 "/Users/clodpod/.ssh/authorized_keys"
fi
if [[ -f "/Users/clodpod/.ssh/known_hosts" ]]; then
    sudo chmod 600 "/Users/clodpod/.ssh/known_hosts"
fi
if [[ -f "/Users/clodpod/.ssh/id_ed25519" ]]; then
    sudo chmod 600 "/Users/clodpod/.ssh/id_ed25519"
fi
if [[ -f "/Users/clodpod/.ssh/id_ed25519.pub" ]]; then
    sudo chmod 644 "/Users/clodpod/.ssh/id_ed25519.pub"
fi


###############################################################################
# Allow clodpod user to update homebrew
###############################################################################
debug "Enable clodpod to update brew files"
if [[ -n "${CLODPOD_UID:-}" && -n "${CLODPOD_GID:-}" ]]; then
    sudo chown -R "$CLODPOD_UID:$CLODPOD_GID" "$(brew --prefix)"
elif id -u clodpod &>/dev/null; then
    sudo chown -R "$(id -u clodpod):$(id -g clodpod)" "$(brew --prefix)"
else
    warn "clodpod user not found — skipping brew chown"
fi
