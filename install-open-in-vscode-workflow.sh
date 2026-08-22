#!/bin/zsh

set -euo pipefail

# =============================================================================
# Open in VS Code — Finder Quick Action installer
#
# Installs ONLY:
#   Finder -> Right-click -> Quick Actions -> Open in VS Code
#
# Commands:
#   zsh ./install-open-in-vscode-workflow.sh install
#   zsh ./install-open-in-vscode-workflow.sh status
#   zsh ./install-open-in-vscode-workflow.sh uninstall
# =============================================================================


NAME="Open in VS Code"
DEST="$HOME/Library/Services/$NAME.workflow"
MODE="${1:-install}"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$1"; }
fail() { printf "\033[1;31m✗\033[0m %s\n" "$1" >&2; exit 1; }

check_macos() {
    [[ "$(uname -s)" == "Darwin" ]] ||
        fail "This installer only works on macOS."
}

find_vscode() {
    [[ -d "/Applications/Visual Studio Code.app" ]] && return 0
    [[ -d "$HOME/Applications/Visual Studio Code.app" ]] && return 0

    command -v mdfind >/dev/null 2>&1 &&
        mdfind 'kMDItemCFBundleIdentifier == "com.microsoft.VSCode"' |
        grep -q .
}

refresh_services() {
    [[ -x "/System/Library/CoreServices/pbs" ]] &&
        /System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

    killall Finder >/dev/null 2>&1 || true
}

install_workflow() {
    local tmp src saved_path automator_was_running

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/open-in-vscode.XXXXXX")"
    src="$tmp/$NAME.workflow"

    trap "rm -rf -- ${(q)tmp}" EXIT

    if pgrep -x Automator >/dev/null 2>&1; then
        automator_was_running=1
    else
        automator_was_running=0
        open -gj -a Automator
    fi

    if ! find_vscode; then
        warn "Visual Studio Code was not found."
        warn "The Quick Action will still be installed."
    fi

    info "Creating Quick Action"

    mkdir -p "$src/Contents" "$HOME/Library/Services"

    cat >"$src/Contents/document.wflow" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>

<key>actions</key><array><dict><key>action</key><dict>
<key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
<key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
<key>ActionParameters</key><dict>
<key>COMMAND_STRING</key><string>/usr/bin/open -b com.microsoft.VSCode "$@"</string>
<key>inputMethod</key><integer>1</integer>
<key>shell</key><string>/bin/zsh</string>
</dict></dict></dict></array>

<key>workflowMetaData</key><dict>
<key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string>
<key>serviceInputTypeIdentifier</key><string>com.apple.Automator.fileSystemObject</string>
<key>applicationPaths</key><array><string>/System/Library/CoreServices/Finder.app</string></array>
</dict>

</dict></plist>
EOF

    cat >"$src/Contents/Info.plist" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>NSServices</key><array><dict>
<key>NSMenuItem</key><dict><key>default</key><string>Open in VS Code</string></dict>
<key>NSMessage</key><string>runWorkflowAsService</string>
<key>NSRequiredContext</key><dict>
<key>NSApplicationIdentifier</key><string>com.apple.finder</string>
</dict>
<key>NSSendFileTypes</key><array><string>public.item</string></array>
</dict></array>
</dict></plist>
EOF

    rm -rf "$DEST"

    saved_path="$(
        osascript - "$src" "$NAME" <<'APPLESCRIPT'
on run argv
    set src to item 1 of argv
    set workflowName to item 2 of argv

    set savePath to ¬
        (POSIX path of (path to services folder from user domain)) & ¬
        workflowName & ".workflow"

    tell application "Automator"
        set w to open POSIX file src
        save w in POSIX file savePath

        try
            close w saving no
        end try
    end tell

    return savePath
end run
APPLESCRIPT
    )"

    [[ -d "$saved_path" ]] ||
        fail "Automator did not create the Quick Action."

    # Only close Automator if this installer launched it.
    if [[ "$automator_was_running" == "0" ]]; then
        killall Automator >/dev/null 2>&1 || true
    fi

    rm -rf "$tmp"
    trap - EXIT

    refresh_services

    ok "Quick Action installed"
    echo "  $saved_path"
}

show_status() {
    echo
    echo "$NAME — Quick Action"
    echo "------------------------------"

    if [[ -d "$DEST" ]]; then
        echo "Status:  installed"
        echo "Path:    $DEST"
    else
        echo "Status:  not installed"
    fi

    if find_vscode; then
        echo "VS Code: installed"
    else
        echo "VS Code: not found"
    fi

    echo
}

uninstall_workflow() {
    if [[ ! -d "$DEST" ]]; then
        ok "Quick Action is already not installed"
        return
    fi

    info "Removing Quick Action"

    rm -rf "$DEST"
    refresh_services

    ok "Quick Action removed"
}


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
check_macos


case "${MODE}" in
    install)
        echo
        echo "Open in VS Code — Quick Action installer"
        echo "========================================"
        echo
        echo "This installs:"
        echo "  • Finder -> Right-click -> Quick Actions -> Open in VS Code"
        echo

        install_workflow

        echo
        ok "Installation complete"
        echo
        echo "Try:"
        echo "  Right-click a file or folder"
        echo "  -> Quick Actions"
        echo "  -> Open in VS Code"
        echo
        ;;

    status)
        show_status
        ;;

    uninstall)
        uninstall_workflow
        ;;

    *)
        echo "Usage:"
        echo "  zsh $0 install"
        echo "  zsh $0 status"
        echo "  zsh $0 uninstall"
        exit 2
        ;;
esac
