# Ensure current directory is readable
[[ -r "$PWD" ]] || cd "$HOME"

# Add ~/bin (agent wrappers) and ~/.local/bin (Claude Code) to PATH
# in all shell contexts, including non-interactive SSH commands
export PATH="$HOME/bin:$HOME/.local/bin:/opt/homebrew/bin:$PATH"

# Load user configuration
[[ -f "$HOME/user/.zshenv" ]] && source "$HOME/user/.zshenv"
