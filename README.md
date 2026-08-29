# Android Apps — Termux + XFCE

A native-looking **Android application launcher and shortcut manager for Termux + XFCE**.

The project discovers Android applications dynamically from the Android package manager, resolves their real launcher activities, and gives you a graphical interface for launching apps and managing XFCE application-menu entries and desktop shortcuts.

No application package names are hard-coded.


---

## 🖥️ Screenshot

```markdown

```

---


## 🚀 Installation

Clone the repository:

```bash
git clone https://github.com/computerauditor/Termux-Android-Apps
cd Termux-Android-Apps
```

Make the launcher script executable:

```bash
chmod +x android-apps.sh
```

Run it:

```bash
./android-apps.sh
```

If the script is being launched from another directory, you can also run:

```bash
bash android-apps.sh
```

---

## ▶️ Running

Start the manager:

```bash
./android-apps.sh
```

The graphical interface will discover the Android applications available to the current Android user.

Select an application to view its:

- Application name
- Package name
- Launcher activity
- Generated launch command
- XFCE menu status
- Desktop shortcut status

---

---

## ✨ Features

- 🔎 **Dynamic Android app discovery**
  - Reads installed Android packages directly from the Android package manager.
  - Does not rely on a hard-coded application list.
  - Detects newly installed and removed applications when refreshed.

- 🚀 **Launch Android applications**
  - Resolves each application's actual launcher activity.
  - Builds the appropriate Android Activity Manager command dynamically.
  - Uses commands such as:
    ```bash
    am start --user 0 -n PACKAGE/ACTIVITY
    ```

- 🏷️ **Real application names**
  - Displays application labels such as:
    - `WhatsApp`
    - `Gmail`
    - `Grand Theft Auto: San Andreas`
  - Package IDs such as `com.whatsapp` are used internally rather than being presented as the primary application name.

- 🖼️ **Application icons**
  - Attempts to obtain the original Android application icon dynamically.
  - Uses the discovered Android application information rather than a manually maintained icon list.

- 📋 **XFCE Application Menu integration**
  - Add Android applications to the XFCE application menu.
  - Entries are grouped under:
    **Android Apps**
  - Remove previously created menu entries.

- 🖥️ **XFCE Desktop shortcuts**
  - Create desktop shortcuts for Android applications.
  - Remove shortcuts individually or in bulk.

- ☑️ **Multi-selection**
  - Select one application.
  - Select multiple applications.
  - Select all applications.
  - Unselect all applications.
  - Perform menu/desktop operations on the selected applications.

- 🔄 **Refresh**
  - Refreshes the Android application list.
  - Detects installed/uninstalled applications without manually editing a configuration file.

- 💾 **Local application cache**
  - Stores discovered application information locally.
  - Reduces unnecessary repeated discovery work.
  - Refresh can update the cached application database.

- 🌑 **Dark graphical interface**
  - Designed for a clean XFCE desktop workflow.
  - Built with Python/Tkinter.

## 📦 Requirements

### Android / Termux

You need:

- Android
- Termux
- `am`
- `pm`
- `cmd`
- Python 3.14
- Tkinter
- Termux-X11/XFCE if you want the graphical interface on your XFCE desktop

The project uses **Python 3.14**.

Install the required Termux packages:

```bash
pkg update
pkg install python tk python-tkinter
```

```bash
python3.14 -c 'import tkinter as tk; print(tk.TkVersion)'
```

retaining the correct application name and launch command.

---

## 🔄 Refreshing applications

Use **Refresh** inside the application manager after installing or uninstalling Android applications.

The refresh process updates the local application information so the GUI can reflect the current Android application list.

This avoids having to manually maintain a list of installed applications.

---

## ☑️ Bulk operations

Multiple applications can be selected at once.

Available selection operations include:

- Select all
- Unselect all
- Individual selection
- Multiple selection

Bulk actions can then be applied to the selected applications, including:

- Add to Android Apps menu
- Remove from Android Apps menu
- Create desktop shortcuts
- Remove desktop shortcuts

---

## ⭐ Contributing

Issues, bug reports, improvements, and pull requests are welcome.

When reporting an Android-specific problem, include:

```bash
python3.14 --version
pm list packages | head
cmd package resolve-activity --user 0 --brief \
  -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER \
  PACKAGE_NAME
```

Do not include private account information or other sensitive device data in issue reports.

---

Linux/XFCE desktop experience.
