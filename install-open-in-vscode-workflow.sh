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

DISPLAY_NAME="Open in VS Code"
QUICK_ACTION_DIR="${HOME}/Library/Services/${DISPLAY_NAME}.workflow"
MODE="${1:-install}"

# -----------------------------------------------------------------------------
# Output helpers
# -----------------------------------------------------------------------------

info() {
    printf "\033[1;34m==>\033[0m %s\n" "$1"
}

ok() {
    printf "\033[1;32m✓\033[0m %s\n" "$1"
}

warn() {
    printf "\033[1;33m!\033[0m %s\n" "$1"
}

fail() {
    printf "\033[1;31m✗\033[0m %s\n" "$1" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------

check_macos() {
    [[ "$(uname -s)" == "Darwin" ]] || fail "This installer only works on macOS."
}

check_tools() {
    require_command plutil
}

find_vscode() {
    local found=""

    if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        echo "/Applications/Visual Studio Code.app"
        return 0
    fi

    if [[ -d "${HOME}/Applications/Visual Studio Code.app" ]]; then
        echo "${HOME}/Applications/Visual Studio Code.app"
        return 0
    fi

    if command -v mdfind >/dev/null 2>&1; then
        found="$(mdfind 'kMDItemCFBundleIdentifier == "com.microsoft.VSCode"' | head -n 1 || true)"

        if [[ -n "${found}" && -d "${found}" ]]; then
            echo "${found}"
            return 0
        fi
    fi

    return 1
}

refresh_services() {
    if [[ -x "/System/Library/CoreServices/pbs" ]]; then
        "/System/Library/CoreServices/pbs" -flush >/dev/null 2>&1 || true
    fi

    # Finder caches Services/Quick Actions.
    killall Finder >/dev/null 2>&1 || true
}

# -----------------------------------------------------------------------------
# Install Quick Action
# -----------------------------------------------------------------------------

install_workflow() {
    local vscode_path=""

    check_tools

    vscode_path="$(find_vscode || true)"

    if [[ -n "${vscode_path}" ]]; then
        ok "Found VS Code: ${vscode_path}"
    else
        warn "Visual Studio Code was not found."
        warn "The Quick Action will install, but it will not work until VS Code is installed."
    fi

    info "Installing Quick Action"

    rm -rf "${QUICK_ACTION_DIR}"
    mkdir -p "${QUICK_ACTION_DIR}/Contents"

    cat > "${QUICK_ACTION_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSBackgroundColorName</key>
			<string>background</string>
			<key>NSIconName</key>
			<string>NSActionTemplate</string>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Open in VS Code</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSRequiredContext</key>
			<dict>
				<key>NSApplicationIdentifier</key>
				<string>com.apple.finder</string>
			</dict>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.item</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

    cat > "${QUICK_ACTION_DIR}/Contents/document.wflow" <<'WFLOW'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>521.1</string>

    <key>AMApplicationVersion</key>
    <string>2.10</string>

    <key>AMDocumentVersion</key>
    <string>2</string>

    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>

                    <key>Optional</key>
                    <true/>

                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>

                <key>AMActionVersion</key>
                <string>2.0.3</string>

                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>

                <key>AMParameterProperties</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <dict/>

                    <key>CheckedForUserDefaultShell</key>
                    <dict/>

                    <key>inputMethod</key>
                    <dict/>

                    <key>shell</key>
                    <dict/>

                    <key>source</key>
                    <dict/>
                </dict>

                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>

                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>

                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>

                <key>ActionName</key>
                <string>Run Shell Script</string>

                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>/usr/bin/open -b com.microsoft.VSCode "$@"</string>

                    <key>CheckedForUserDefaultShell</key>
                    <true/>

                    <key>inputMethod</key>
                    <integer>1</integer>

                    <key>shell</key>
                    <string>/bin/zsh</string>

                    <key>source</key>
                    <string></string>
                </dict>

                <key>BundleIdentifier</key>
                <string>com.apple.automator.runShellScript</string>

                <key>CFBundleVersion</key>
                <string>2.0.3</string>

                <key>CanShowSelectedItemsWhenRun</key>
                <false/>

                <key>CanShowWhenRun</key>
                <true/>
            </dict>

            <key>isViewVisible</key>
            <true/>
        </dict>
    </array>

    <key>connectors</key>
    <dict/>

    <key>workflowMetaData</key>
    <dict>
        <key>applicationBundleID</key>
        <string>com.apple.finder</string>

        <key>applicationPath</key>
        <string>/System/Library/CoreServices/Finder.app</string>

        <key>applicationPaths</key>
        <array>
            <string>/System/Library/CoreServices/Finder.app</string>
        </array>

        <key>inputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>

        <key>outputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>

        <key>processesInput</key>
        <integer>0</integer>

        <key>serviceApplicationBundleID</key>
        <string>com.apple.finder</string>

        <key>serviceApplicationPath</key>
        <string>/System/Library/CoreServices/Finder.app</string>

        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>

        <key>serviceOutputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>

        <key>serviceProcessesInput</key>
        <integer>0</integer>

        <key>useAutomaticInputType</key>
        <integer>0</integer>

        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
WFLOW

    plutil -lint "${QUICK_ACTION_DIR}/Contents/Info.plist" >/dev/null
    plutil -lint "${QUICK_ACTION_DIR}/Contents/document.wflow" >/dev/null

    refresh_services

    ok "Quick Action installed"
}

# -----------------------------------------------------------------------------
# Status
# -----------------------------------------------------------------------------

show_status() {
    echo
    echo "Open in VS Code — Quick Action"
    echo "------------------------------"

    if [[ -d "${QUICK_ACTION_DIR}" ]]; then
        echo "Status: installed"
        echo "Path:   ${QUICK_ACTION_DIR}"
    else
        echo "Status: not installed"
    fi

    echo
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------

uninstall_workflow() {
    check_macos

    if [[ -d "${QUICK_ACTION_DIR}" ]]; then
        info "Removing Quick Action"
        rm -rf "${QUICK_ACTION_DIR}"
        refresh_services
        ok "Quick Action removed"
    else
        ok "Quick Action is already not installed"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

case "${MODE}" in
    install)
        check_macos

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
        check_macos
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
