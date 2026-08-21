# Open Files and Folders in VS Code from Finder on macOS

You probably already know that you can open the current directory in Visual Studio Code from Terminal with:

```bash
code .
```

That works well when you're already in Terminal.

But if you're browsing a project in **Finder**, opening Terminal, navigating to the same directory, and typing `code .` can feel like unnecessary work.

Instead, you can add **Open in VS Code** directly to Finder.

In this guide, I'll show you two ways to set it up:

* **Manually:** create a macOS Quick Action with the Automator app.
* **Automatically:** use a shell script to create the same Quick Action for you.

Both methods create a Finder action that opens selected files or folders in VS Code. The difference is that the manual method requires you to create and save the Quick Action yourself, while the shell script automates those same steps.

The manual method also shows you how to assign a keyboard shortcut, so you can open a selected file or folder in VS Code without using Finder's context menu.

You can still use `code .` whenever you're already working in Terminal and want to open the current directory in VS Code quickly.

---

## Table of Contents

* [Option 1: Create the Quick Action Manually with the Automator App](#option-1-create-the-quick-action-manually-with-the-automator-app)

  * [1. Open the Automator App](#1-open-the-automator-app)
  * [2. Add the Shell Script](#2-add-the-shell-script)
  * [3. Save and Test the Quick Action](#3-save-and-test-the-quick-action)
  * [4. Add a Keyboard Shortcut](#4-add-a-keyboard-shortcut)
* [Option 2: Install the Automator Quick Action Automatically with a Shell Script](#option-2-install-the-automator-quick-action-automatically-with-a-shell-script)

  * [Download the Installer](#download-the-installer)
  * [Install](#install)
  * [Check the Installation Status](#check-the-installation-status)
  * [Uninstall](#uninstall)
* [How the Automator Command Works](#how-the-automator-command-works)

  * [`/usr/bin/open`](#usrbinopen)
  * [`-b com.microsoft.VSCode`](#-b-commicrosoftvscode)
  * [Passing Finder Selections](#passing-finder-selections)
* [Keep Using ](#keep-using-code--in-terminal)[`code .`](#keep-using-code--in-terminal)[ in Terminal](#keep-using-code--in-terminal)

---

## Option 1: Create the Quick Action Manually with the Automator App

The manual method creates a Finder action using macOS's built-in **Automator** app.

If you'd rather use macOS's built-in tools and avoid running an installer script, you can create a **Quick Action** with the Automator app.

The entire workflow only requires one shell command.

### 1. Open the Automator App

Start by opening the **Automator** app.

You can find it in the **Applications** folder or launch it from Terminal:

```bash
open -a Automator
```

When Automator opens, choose:

**New Document → Quick Action**

At the top of the workflow, configure:

* **Workflow receives current:** `files or folders`
* **in:** `Finder`

This tells macOS to make the Quick Action available whenever you select files or folders in Finder.

---

### 2. Add the Shell Script

In the Automator app's **Actions** panel, search for:

**Run Shell Script**

Drag it into the workflow.

Configure the action with:

* **Shell:** `/bin/zsh`
* **Pass input:** `as arguments`

Automator adds a default shell script to the action.

Delete it and replace it with:

```bash
/usr/bin/open -b com.microsoft.VSCode "$@"
```

That's the entire script.

It tells macOS to open the Finder selection with Visual Studio Code.

---

### 3. Save and Test the Quick Action

Save the workflow by choosing:

**File → Save**

Name it:

**Open in VS Code**

Now open Finder and test it.

1. Select a file or folder.
2. Right-click the selection.
3. Choose **Quick Actions → Open in VS Code**.

VS Code should open the selected item.

> Depending on your macOS version and configuration, **Open in VS Code** may appear under **Services** instead of **Quick Actions**.

The action also works when multiple Finder items are selected.

---

### 4. Add a Keyboard Shortcut

If you use the Quick Action frequently, you can assign it a keyboard shortcut.

Open:

**System Settings → Keyboard → Keyboard Shortcuts → Services**

Find the **Files and Folders** section, then locate:

**Open in VS Code**

Double-click the key combination `none` shown next to the service to record a custom keyboard shortcut. After double-clicking, press the desired shortcut keys on your keyboard, such as: Shift + Command + V.

**⇧⌘V**

After that, your workflow becomes:

```text
Select a file or folder in Finder
        ↓
Press ⇧⌘V
        ↓
Open in VS Code
```

Now you can jump directly from Finder to VS Code without opening the context menu.

---

## Option 2: Install the Automator Quick Action Automatically with a Shell Script

Use this shell script if you want to automate the setup or repeat it on another Mac.

The installer creates the same Quick Action described in the manual method and provides commands to check its status or remove it later.

Your workflow is still:

```text
Select a file or folder in Finder
  ↓
Quick Actions → Open in VS Code
```

Instead of setting up the workflow yourself, the script creates the Quick Action, adds the shell command, configures Finder as the input location, and registers the workflow with macOS.

The installer is available in my GitHub repository:

[Open Files and Folders in VS Code from Finder](https://github.com/moyarich/Open-Files-and-Folders-in-VS-Code-from-Finder)

The installer file is:

```text
install-open-in-vscode-plugin.sh
```

### Download the Installer

Clone the repository:

```bash
git clone https://github.com/moyarich/Open-Files-and-Folders-in-VS-Code-from-Finder.git
```

Then enter the project directory:

```bash
cd Open-Files-and-Folders-in-VS-Code-from-Finder
```

You can also download the `install-open-in-vscode-plugin.sh` file directly from the repository if you don't want to clone the entire project.

### Install

First, make the installer executable:

```bash
chmod +x ./install-open-in-vscode-plugin.sh
```

Then run:

```bash
zsh ./install-open-in-vscode-plugin.sh install
```

The script creates the Automator Quick Action, adds the VS Code command, configures it to receive files and folders from Finder, and registers the workflow with macOS.

After the installation finishes, try right-clicking a file or folder in Finder.

You should see:

**Open in VS Code**

### Check the Installation Status

The installer also includes a status command:

```bash
zsh ./install-open-in-vscode-plugin.sh status
```

This checks whether the Automator Quick Action has been created and registered.

### Uninstall

To remove the automatically installed Quick Action:

```bash
zsh ./install-open-in-vscode-plugin.sh uninstall
```

This removes the Automator workflow from your system.

---

## How the Automator Command Works

The entire Automator Quick Action is powered by one command:

```bash
/usr/bin/open -b com.microsoft.VSCode "$@"
```

When you create the Quick Action manually, you add this command yourself. When you use the installer, the script adds the same command to the Automator workflow automatically.

There are three important parts:

```text
/usr/bin/open  -b com.microsoft.VSCode  "$@"
│              │                        │
│              │                        └─ Finder selections
│              └─ Application to use
└─ macOS open command
```

Let's look at each one.

### `/usr/bin/open`

`open` is a built-in macOS command for opening files, directories, URLs, and applications.

For example:

```bash
open .
```

opens the current directory in Finder.

You can also use it to open a specific file:

```bash
open README.md
```

or launch an application:

```bash
open -a "Visual Studio Code"
```

In the Automator workflow, we're using the full executable path:

```bash
/usr/bin/open
```

This ensures that the Automator app calls the macOS `open` command directly instead of depending on the shell's `PATH`.

---

### `-b com.microsoft.VSCode`

The next part is:

```bash
-b com.microsoft.VSCode
```

The `-b` option tells `open` which application should handle the item by specifying the application's **bundle identifier**.

Visual Studio Code's bundle identifier is:

```text
com.microsoft.VSCode
```

So this:

```bash
open -b com.microsoft.VSCode
```

essentially means:

> Open this with Visual Studio Code.

Using the bundle identifier is useful because the command doesn't have to depend on the exact location of `Visual Studio Code.app`.

---

### Passing Finder Selections

The final part is:

```bash
"$@"
```

This represents the arguments passed to the shell script.

Earlier, we configured the Automator app to:

**Pass input: as arguments**

When you select files or folders in Finder, Automator passes those paths to the script as command-line arguments.

For example, imagine selecting these two folders:

```text
~/Projects/project-one
~/Projects/project-two
```

Conceptually, Automator ends up running something similar to:

```bash
/usr/bin/open -b com.microsoft.VSCode \
  "/Users/your-name/Projects/project-one" \
  "/Users/your-name/Projects/project-two"
```

You don't have to construct that command yourself.

`"$@"` forwards all of the arguments Automator received.

The quotes are important.

Consider a folder named:

```text
My React Project
```

Without proper quoting, a shell could interpret that as three separate values:

```text
My
React
Project
```

Using:

```bash
"$@"
```

preserves every selected path as its own argument.

That's why the Quick Action works with:

* one file
* one folder
* multiple files
* multiple folders
* files and folders whose names contain spaces

---

## Keep Using `code .` in Terminal

If you're already in Terminal:

```bash
code .
```

is usually the fastest option.

If you're already browsing files in Finder, the Quick Action saves you from opening Terminal, navigating back to the same directory, and running another command.

It's a small macOS customization, but if you regularly move between **Finder**, **Terminal**, and **Visual Studio Code**, it removes a repetitive step from your development workflow.
