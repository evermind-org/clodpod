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

# Ensure Homebrew is on PATH (packer provisioner shells don't pick up /etc/paths.d)
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi


###############################################################################
# Ensure clodpod user and group exist (may be lost during tart clone)
###############################################################################
if ! id -u clodpod &>/dev/null 2>&1; then
    debug "clodpod user missing — creating..."

    NEXT_UID=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
    NEXT_UID=$((NEXT_UID + 1))

    # Create group
    sudo dscl . -create /Groups/clodpod
    sudo dscl . -create /Groups/clodpod PrimaryGroupID "$NEXT_UID"
    sudo dscl . -create /Groups/clodpod RealName "clodpod Group"

    # Create user
    sudo dscl . -create /Users/clodpod
    sudo dscl . -create /Users/clodpod UniqueID "$NEXT_UID"
    sudo dscl . -create /Users/clodpod PrimaryGroupID "$NEXT_UID"
    sudo dscl . -create /Users/clodpod RealName "clodpod User"
    sudo dscl . -create /Users/clodpod NFSHomeDirectory "/Users/clodpod"
    sudo dscl . -create /Users/clodpod UserShell "/bin/zsh"
    sudo dscl . -create /Users/clodpod IsHidden 1

    # Set password and SSH access
    CLODPOD_PASSWORD=$(openssl rand -base64 32)
    sudo dscl . -passwd /Users/clodpod "$CLODPOD_PASSWORD"
    sudo dseditgroup -o edit -a clodpod -t user com.apple.access_ssh

    # Create login keychain
    sudo mkdir -p /Users/clodpod/Library/Keychains
    sudo -u clodpod security create-keychain -p "clodpod-keychain" \
        /Users/clodpod/Library/Keychains/login.keychain-db 2>/dev/null || true
    sudo -u clodpod security set-keychain-settings \
        /Users/clodpod/Library/Keychains/login.keychain-db 2>/dev/null || true

    debug "clodpod user created with UID $NEXT_UID"
else
    debug "clodpod user exists (UID $(id -u clodpod))"
fi

# Ensure SSH access group membership (tart clone may strip group memberships)
sudo dseditgroup -o edit -a clodpod -t user com.apple.access_ssh


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

# Make clodpod the owner of the files (use numeric IDs for reliability)
sudo chown -R "$(id -u clodpod):$(id -g clodpod)" "/Users/clodpod"

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
sudo chown -R "$(id -u clodpod):$(id -g clodpod)" "$(brew --prefix)"
