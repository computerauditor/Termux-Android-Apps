# Android Apps — Termux + XFCE

A native-looking **Android application launcher and shortcut manager for Termux + XFCE**.

The project discovers Android applications dynamically from the Android package manager, resolves their real launcher activities, and gives you a graphical interface for launching apps and managing XFCE application-menu entries and desktop shortcuts.

No application package names are hard-coded.

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

---

## 🖥️ Screenshot

Add your project screenshot here:

```markdown
![Android Apps Manager](screenshots/android-apps-manager.png)
```

---

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

The Android package-management commands should be available from Termux:

```bash
command -v am
command -v pm
command -v cmd
```

You should see paths for the commands rather than `command not found`.

### Python / Tkinter

The project uses **Python 3.14**.

Install the required Termux packages:

```bash
pkg update
pkg install python tk python-tkinter
```

Verify Python:

```bash
python3.14 --version
```

Verify Tkinter:

```bash
python3.14 -c 'import tkinter as tk; print(tk.TkVersion)'
```

> `tkinter` is not installed with `pip`. It is provided by the Termux `python-tkinter` package.

---

## 🚀 Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/android-apps.git
cd android-apps
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

## 📱 How Android launching works

Android applications are identified by their package name and Activity.

For example, an application may resolve to:

```text
com.rockstargames.gtasa/.DownloaderActivity
```

The manager can then launch it dynamically with:

```bash
am start --user 0 -n com.rockstargames.gtasa/.DownloaderActivity
```

The important part is that the project **does not assume that every application uses `.Main`, `.MainActivity`, or another fixed Activity name**.

The launcher Activity is discovered from Android's package information.

---

## 🧭 Application discovery

The application list is generated dynamically from the Android system.

This means the project is not built around entries such as:

```text
com.whatsapp
com.google.android.gm
com.rockstargames.gtasa
```

Instead, installed packages and their launcher Activities are discovered at runtime.

This allows the same manager to work with different Android installations and different sets of applications.

---

## 🗂️ XFCE Application Menu

When an application is added to the XFCE menu, the project creates a proper `.desktop` application entry.

The entries are organized under:

```text
Android Apps
```

The visible application name comes from the Android application label rather than the package ID.

For example:

```text
WhatsApp
```

instead of:

```text
com.whatsapp
```

---

## 🖥️ Desktop shortcuts

Desktop shortcuts are standard freedesktop `.desktop` files.

They contain an actual desktop-entry structure rather than shell commands pretending to be `.desktop` files.

For example:

```ini
[Desktop Entry]
Type=Application
Name=WhatsApp
Exec=...
Icon=...
Terminal=false
```

This allows XFCE to treat the shortcut as an application launcher.

---

## 🖼️ Icons

The manager attempts to locate and use the application's original Android icon dynamically.

No application-specific icon list is required.

If an Android icon cannot be extracted or converted into a format usable by XFCE, the launcher can fall back to a generic application icon while retaining the correct application name and launch command.

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

## 📁 Project layout

A typical installation looks like:

```text
android-apps/
├── android-apps.sh
├── README.md
└── ...
```

Runtime data and cached application information are stored separately from the source code so that refreshing the application list does not require editing the script.

---

## 🔐 Permissions and Android security

The manager uses Android's normal application-launching interfaces from Termux.

Some Android applications deliberately mark Activities as non-exported.

For example, attempting to start a non-exported Activity can produce an error similar to:

```text
Permission Denial:
starting Intent ... not exported
```

The manager therefore resolves the application's actual launcher Activity rather than blindly assuming an Activity name.

If Android itself prevents an Activity from being launched, the manager cannot bypass that Android security restriction.

---

## 🛠️ Troubleshooting

### `python3.14` cannot import tkinter

Install:

```bash
pkg install tk python-tkinter
```

Then verify:

```bash
python3.14 -c 'import tkinter; print("Tkinter OK")'
```

---

### `am` is missing

Check:

```bash
command -v am
```

The script requires access to Android's Activity Manager interface.

---

### `pm` is missing

Check:

```bash
command -v pm
```

The package manager interface is required to discover installed Android applications.

---

### No applications appear

First test Android package access:

```bash
pm list packages
```

Then test launcher resolution manually:

```bash
cmd package resolve-activity --user 0 --brief \
  -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER \
  PACKAGE_NAME
```

Replace `PACKAGE_NAME` with an installed package.

---

### A desktop shortcut runs as a shell script

A `.desktop` file is **not** supposed to be executed directly with:

```bash
./something.desktop
```

XFCE reads `.desktop` files as desktop-entry files.

The manager creates valid desktop-entry files containing:

```ini
[Desktop Entry]
```

rather than Bash commands.

---

## 🧪 Manual launch test

To test a resolved application manually:

```bash
am start --user 0 -n PACKAGE/ACTIVITY
```

For example:

```bash
am start --user 0 -n com.rockstargames.gtasa/.DownloaderActivity
```

The exact package/activity pair should always come from the application's actual Android launcher information.

---

## 🎯 Design goals

The project is intentionally designed around three principles:

### 1. Dynamic

Applications, names, launcher Activities, and icons should be discovered from the Android system rather than hard-coded.

### 2. XFCE-friendly

The generated launchers should behave like normal XFCE application entries and desktop shortcuts.

### 3. Simple

The GUI should provide the complete workflow:

```text
Discover → Select → Launch
                  ↓
            Add to Menu
                  ↓
          Create Desktop Shortcut
                  ↓
             Remove / Refresh
```

---

## 🧰 Technology

- **Bash** — bootstrap/launcher layer
- **Python 3.14** — graphical application manager
- **Tkinter** — GUI
- **Android `pm`** — package discovery
- **Android `cmd`** — package/activity resolution
- **Android `am`** — application launching
- **XFCE / XDG desktop entries** — menu and desktop integration

---

## 📄 License

Choose the license you want for the project and add it here.

For example:

```text
MIT License
```

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

## 📌 Project status

This project is intended for **Termux + XFCE Android desktop environments** and focuses on dynamically integrating Android applications into the Linux/XFCE desktop experience.
