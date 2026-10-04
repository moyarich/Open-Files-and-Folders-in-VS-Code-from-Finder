#!/bin/zsh
# @file Open in VS Code Installer
# @brief Installs, inspects, and removes the Finder "Open in VS Code" Quick Action.
# @description
#   Supports explicit CLI commands and an optional fzf-driven interactive mode.
#   The script is sourceable for tests when OPEN_IN_VSCODE_SOURCE_ONLY=1.

set -euo pipefail

# =============================================================================
# Open in VS Code — Finder Quick Action installer
#
# Interactive mode:
#   zsh ./open-in-vscode-installer.sh
#
# Command mode:
#   zsh ./open-in-vscode-installer.sh install
#   zsh ./open-in-vscode-installer.sh status
#   zsh ./open-in-vscode-installer.sh uninstall
#
# If fzf is available, interactive mode uses it to choose an action and, when
# multiple VS Code variants are installed, which one the Quick Action opens.
# Explicit commands remain non-interactive and automation-friendly.
# =============================================================================

NAME="Open in VS Code"
DEST="$HOME/Library/Services/$NAME.workflow"

STABLE_BUNDLE_ID="com.microsoft.VSCode"
INSIDERS_BUNDLE_ID="com.microsoft.VSCodeInsiders"

MODE=""
REQUESTED_BUNDLE_ID=""

# @description Prints an informational message to stdout.
# @arg info() { string Message to display.
# @stdout A blue-prefixed informational message.
info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
# @description Prints a success message to stdout.
# @arg ok()   { string Message to display.
# @stdout A green-prefixed success message.
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$1"; }
# @description Prints a warning message to stderr.
# @arg warn() { string Message to display.
# @stderr A yellow-prefixed warning message.
warn() { printf "\033[1;33m!\033[0m %s\n" "$1" >&2; }
# @description Prints an error message and terminates the script.
# @arg fail() { string Error message to display.
# @stderr A red-prefixed error message.
# @exitcode 1 Always exits with failure.
fail() { printf "\033[1;31m✗\033[0m %s\n" "$1" >&2; exit 1; }

# @description Verifies that the installer is running on macOS.
# @noargs
# @exitcode 0 When the host operating system is Darwin.
# @exitcode 1 When the host operating system is not macOS.
check_macos() {
    [[ "$(uname -s)" == "Darwin" ]] ||
        fail "This installer only works on macOS."
}

# @description Checks whether fzf is available on PATH.
# @noargs
# @exitcode 0 When fzf is installed and discoverable.
# @exitcode 1 When fzf is unavailable.
has_fzf() {
    command -v fzf >/dev/null 2>&1
}

# @description Checks whether stdin is attached to an interactive terminal.
# @noargs
# @exitcode 0 When stdin is a TTY.
# @exitcode 1 Otherwise.
is_interactive_terminal() {
    [[ -t 0 ]]
}

# @description Validates a macOS application bundle identifier before interpolation.
# @arg validate_bundle_id() { string Bundle identifier to validate.
# @exitcode 0 When the identifier contains only allowed characters.
# @exitcode 1 When the identifier is empty or unsafe.
validate_bundle_id() {
    local bundle_id="$1"

    [[ -n "$bundle_id" ]] || return 1
    [[ "$bundle_id" =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]]
}

# @description Finds an installed application path for a validated bundle identifier.
# @arg find_app_by_bundle_id() { string macOS application bundle identifier.
# @stdout The discovered application path when found.
# @exitcode 0 When a matching application is found.
# @exitcode 1 When the identifier is invalid or no application is found.
find_app_by_bundle_id() {
    local bundle_id="$1"
    local result=""

    validate_bundle_id "$bundle_id" ||
        return 1

    case "$bundle_id" in
        "$STABLE_BUNDLE_ID")
            [[ -d "/Applications/Visual Studio Code.app" ]] &&
                { print -r -- "/Applications/Visual Studio Code.app"; return 0; }
            [[ -d "$HOME/Applications/Visual Studio Code.app" ]] &&
                { print -r -- "$HOME/Applications/Visual Studio Code.app"; return 0; }
            ;;
        "$INSIDERS_BUNDLE_ID")
            [[ -d "/Applications/Visual Studio Code - Insiders.app" ]] &&
                { print -r -- "/Applications/Visual Studio Code - Insiders.app"; return 0; }
            [[ -d "$HOME/Applications/Visual Studio Code - Insiders.app" ]] &&
                { print -r -- "$HOME/Applications/Visual Studio Code - Insiders.app"; return 0; }
            ;;
    esac

    if command -v mdfind >/dev/null 2>&1; then
        result="$(
            mdfind "kMDItemCFBundleIdentifier == '${bundle_id}'" |
                head -n 1 ||
                true
        )"

        if [[ -n "$result" && -d "$result" ]]; then
            print -r -- "$result"
            return 0
        fi
    fi

    return 1
}

# @description Converts a known VS Code bundle identifier to a display label.
# @arg bundle_label() { string Bundle identifier.
# @stdout A human-readable label, or the original identifier when unknown.
bundle_label() {
    case "$1" in
        "$STABLE_BUNDLE_ID") print -r -- "Visual Studio Code" ;;
        "$INSIDERS_BUNDLE_ID") print -r -- "Visual Studio Code - Insiders" ;;
        *) print -r -- "$1" ;;
    esac
}

# @description Resolves the requested installer action.
# @noargs
# @set MODE string Selected action: install, status, or uninstall.
# @stderr Warns when fzf is unavailable in an interactive terminal.
# @exitcode 130 When the user cancels the fzf picker.
select_mode() {
    local selection

    if [[ -n "$MODE" ]]; then
        return
    fi

    if is_interactive_terminal && has_fzf; then
        selection="$(
            printf '%s\n' \
                $'install\tInstall or replace the Finder Quick Action' \
                $'status\tShow installer and VS Code status' \
                $'uninstall\tRemove the Finder Quick Action' |
                fzf \
                    --height=40% \
                    --layout=reverse \
                    --border \
                    --prompt='Action > ' \
                    --header='Open in VS Code — Finder Quick Action' \
                    --with-nth=1,2
        )" || exit 130

        MODE="${selection%%$'\t'*}"
        return
    fi

    if is_interactive_terminal && ! has_fzf; then
        warn "fzf is not installed; defaulting to install."
        warn "Install fzf for the interactive picker, or pass install/status/uninstall explicitly."
    fi

    MODE="install"
}

# @description Selects the VS Code bundle identifier to store in the Quick Action.
# @noargs
# @stdout The validated bundle identifier selected for installation.
# @stderr Warnings for missing editors or fallback behavior.
# @exitcode 130 When the user cancels the fzf picker.
select_vscode_bundle() {
    local -a choices
    local path selection

    if [[ -n "$REQUESTED_BUNDLE_ID" ]]; then
        validate_bundle_id "$REQUESTED_BUNDLE_ID" ||
            fail "Invalid VS Code bundle identifier: $REQUESTED_BUNDLE_ID"

        print -r -- "$REQUESTED_BUNDLE_ID"
        return
    fi

    if path="$(find_app_by_bundle_id "$STABLE_BUNDLE_ID" 2>/dev/null)"; then
        choices+=("Visual Studio Code"$'\t'"$STABLE_BUNDLE_ID"$'\t'"$path")
    fi

    if path="$(find_app_by_bundle_id "$INSIDERS_BUNDLE_ID" 2>/dev/null)"; then
        choices+=("Visual Studio Code - Insiders"$'\t'"$INSIDERS_BUNDLE_ID"$'\t'"$path")
    fi

    if (( ${#choices[@]} == 0 )); then
        warn "No supported VS Code installation was found."
        warn "The Quick Action will target Visual Studio Code stable."
        print -r -- "$STABLE_BUNDLE_ID"
        return
    fi

    if (( ${#choices[@]} == 1 )); then
        print -r -- "${choices[1]}" | cut -f2
        return
    fi

    if is_interactive_terminal && has_fzf; then
        selection="$(
            printf '%s\n' "${choices[@]}" |
                fzf \
                    --height=40% \
                    --layout=reverse \
                    --border \
                    --prompt='VS Code > ' \
                    --header='Choose which VS Code app Finder should open' \
                    --with-nth=1,3
        )" || exit 130

        print -r -- "$selection" | cut -f2
        return
    fi

    warn "Multiple VS Code variants are installed; using stable VS Code."
    warn "Run without arguments in a terminal with fzf to choose interactively."
    print -r -- "$STABLE_BUNDLE_ID"
}

# @description Reads the configured VS Code bundle identifier from the installed workflow.
# @noargs
# @stdout The configured bundle identifier when it can be parsed safely.
# @exitcode 0 When a valid bundle identifier is found.
# @exitcode 1 When the workflow is missing or cannot be parsed safely.
configured_bundle_id() {
    local workflow="$DEST/Contents/document.wflow"
    local bundle_id=""

    [[ -f "$workflow" ]] || return 1

    bundle_id="$(
        sed -n 's#.*<string>/usr/bin/open -b \([A-Za-z0-9._-]*\) "\$@"</string>.*#\1#p' "$workflow" |
            head -n 1
    )"

    validate_bundle_id "$bundle_id" || return 1
    print -r -- "$bundle_id"
}

# @description Refreshes the macOS Services cache and restarts Finder as a fallback.
# @noargs
# @exitcode 0 Always; refresh failures are intentionally non-fatal.
refresh_services() {
    # Flush the Services cache first. Restarting Finder is intentionally kept as
    # a fallback because Finder can otherwise retain a stale Quick Actions menu.
    [[ -x "/System/Library/CoreServices/pbs" ]] &&
        /System/Library/CoreServices/pbs -flush >/dev/null 2>&1 ||
        true

    killall Finder >/dev/null 2>&1 || true
}

# @description Writes the temporary Automator workflow and service metadata files.
# @arg write_workflow_files() { string Temporary .workflow directory path.
# @arg $2 string Validated target application bundle identifier.
# @exitcode 0 When both workflow files are written successfully.
write_workflow_files() {
    local src="$1"
    local bundle_id="$2"

    mkdir -p "$src/Contents" "$HOME/Library/Services"

    cat >"$src/Contents/document.wflow" <<EOF
<?xml version="1.0"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>

<key>actions</key><array><dict><key>action</key><dict>
<key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
<key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
<key>ActionParameters</key><dict>
<key>COMMAND_STRING</key><string>/usr/bin/open -b ${bundle_id} "\$@"</string>
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
}

# @description Validates the generated Automator plist files with plutil.
# @arg validate_workflow_files() { string Temporary .workflow directory path.
# @exitcode 0 When both plist files are valid.
# @exitcode >0 When plutil rejects either generated file.
validate_workflow_files() {
    local src="$1"

    plutil -lint "$src/Contents/document.wflow" >/dev/null
    plutil -lint "$src/Contents/Info.plist" >/dev/null
}

# @description Opens and saves the generated workflow through Automator.
# @arg save_workflow_with_automator() { string Temporary .workflow directory path.
# @stdout The saved workflow path returned by AppleScript.
# @exitcode 0 When Automator saves the workflow successfully.
save_workflow_with_automator() {
    local src="$1"

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
}

# @description Resolves and validates the final target bundle identifier.
# @noargs
# @stdout The validated bundle identifier.
# @exitcode 1 When the selected identifier is invalid.
resolve_target_bundle() {
    local bundle_id

    bundle_id="$(select_vscode_bundle)"
    validate_bundle_id "$bundle_id" ||
        fail "Invalid VS Code bundle identifier: $bundle_id"

    print -r -- "$bundle_id"
}

# @description Reports the selected editor and whether it is currently installed.
# @arg show_target_editor() { string Validated application bundle identifier.
# @stdout Installed editor label and path when present.
# @stderr A warning when the selected editor is not currently installed.
show_target_editor() {
    local bundle_id="$1"
    local app_path

    app_path="$(find_app_by_bundle_id "$bundle_id" 2>/dev/null || true)"

    if [[ -n "$app_path" ]]; then
        ok "Target: $(bundle_label "$bundle_id")"
        echo "  $app_path"
    else
        warn "$(bundle_label "$bundle_id") is not currently installed."
        warn "The Quick Action will still be installed and will work after the app is installed."
    fi
}

# @description Creates and installs the Finder Quick Action.
# @noargs
# @stdout Installation progress and the saved workflow path.
# @stderr Warnings when the selected editor is not currently installed.
# @exitcode 0 When the Quick Action is installed successfully.
install_workflow() {
    local bundle_id tmp src saved_path automator_was_running

    bundle_id="$(resolve_target_bundle)"
    show_target_editor "$bundle_id"

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/open-in-vscode.XXXXXX")"
    src="$tmp/$NAME.workflow"

    trap 'rm -rf -- "$tmp"' EXIT

    if pgrep -x Automator >/dev/null 2>&1; then
        automator_was_running=1
    else
        automator_was_running=0
    fi

    info "Creating Finder Quick Action"

    write_workflow_files "$src" "$bundle_id"
    validate_workflow_files "$src"

    rm -rf "$DEST"

    saved_path="$(save_workflow_with_automator "$src")"

    [[ -d "$saved_path" ]] ||
        fail "Automator did not create the Quick Action."

    if [[ "$automator_was_running" == "0" ]]; then
        osascript -e 'tell application "Automator" to quit' >/dev/null 2>&1 || true
    fi

    rm -rf "$tmp"
    trap - EXIT

    refresh_services

    ok "Quick Action installed"
    echo "  $saved_path"
    echo "  Opens with: $(bundle_label "$bundle_id") ($bundle_id)"
}

# @description Prints Quick Action, configured target, editor, and fzf status.
# @noargs
# @stdout Human-readable installer status information.
show_status() {
    local stable_path insiders_path configured_bundle=""

    stable_path="$(find_app_by_bundle_id "$STABLE_BUNDLE_ID" 2>/dev/null || true)"
    insiders_path="$(find_app_by_bundle_id "$INSIDERS_BUNDLE_ID" 2>/dev/null || true)"

    echo
    echo "$NAME — Finder Quick Action"
    echo "--------------------------------"

    if [[ -d "$DEST" ]]; then
        echo "Quick Action: installed"
        echo "Path:         $DEST"

        configured_bundle="$(configured_bundle_id 2>/dev/null || true)"
        if [[ -n "$configured_bundle" ]]; then
            echo "Target:       $(bundle_label "$configured_bundle")"
            echo "Bundle ID:    $configured_bundle"
        else
            echo "Target:       unknown"
        fi
    else
        echo "Quick Action: not installed"
    fi

    echo
    echo "VS Code installations:"

    if [[ -n "$stable_path" ]]; then
        echo "  ✓ Visual Studio Code"
        echo "    $stable_path"
    else
        echo "  - Visual Studio Code: not found"
    fi

    if [[ -n "$insiders_path" ]]; then
        echo "  ✓ Visual Studio Code - Insiders"
        echo "    $insiders_path"
    else
        echo "  - Visual Studio Code - Insiders: not found"
    fi

    echo
    if has_fzf; then
        echo "fzf:          installed ($(command -v fzf))"
    else
        echo "fzf:          not installed (optional; explicit commands still work)"
    fi
    echo
}

# @description Removes the installed Finder Quick Action.
# @noargs
# @stdout Removal status.
# @exitcode 0 When removed or already absent.
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

# @description Handles user-facing output for the install command.
# @noargs
# @stdout Installation header, progress, and usage guidance.
run_install() {
    echo
    echo "Open in VS Code — Finder Quick Action installer"
    echo "==============================================="
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
}

# @description Handles the status command.
# @noargs
# @stdout Current Quick Action and editor status.
run_status() {
    show_status
}

# @description Handles the uninstall command.
# @noargs
# @stdout Uninstall progress and result.
run_uninstall() {
    uninstall_workflow
}

# @description Prints command-line usage and bundle-id rules.
# @noargs
# @stdout Installer usage help.
usage() {
    cat <<EOF
Usage:
  zsh $0
  zsh $0 install [bundle-id]
  zsh $0 status
  zsh $0 uninstall

Interactive mode:
  Run with no arguments. If fzf is installed, choose the action from a picker.
  During install, fzf also lets you choose between detected VS Code variants.

Optional environment override:
  OPEN_IN_VSCODE_BUNDLE_ID=$STABLE_BUNDLE_ID zsh $0 install

Bundle IDs may contain only letters, numbers, periods, underscores, and hyphens.
EOF
}

# @description Parses command arguments and dispatches the requested installer action.
# @arg main() { string Optional action: install, status, uninstall, or help.
# @arg $2 string Optional application bundle identifier for install.
# @env OPEN_IN_VSCODE_BUNDLE_ID string Optional default bundle identifier override.
# @exitcode 0 When the requested action completes successfully.
# @exitcode 2 When an unknown action is provided.
main() {
    MODE="${1:-}"
    REQUESTED_BUNDLE_ID="${2:-${OPEN_IN_VSCODE_BUNDLE_ID:-}}"

    check_macos
    select_mode

    case "$MODE" in
        install) run_install ;;
        status) run_status ;;
        uninstall) run_uninstall ;;
        help|-h|--help) usage ;;
        *)
            usage
            exit 2
            ;;
    esac
}

if [[ "${OPEN_IN_VSCODE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
