#!/data/data/com.termux/files/usr/bin/bash
###############################################################################
#                                                                            #
#                    ANDROID APPS LAUNCHER MANAGER                           #
#                                                                            #
#        Termux + XFCE + Python 3.14 + Tkinter                              #
#                                                                            #
#  Features                                                                  #
#  ------------------------------------------------------------------------  #
#  * Dynamically discovers Android launcher applications                      #
#  * Resolves MAIN/LAUNCHER activities                                        #
#  * Retrieves human-readable Android application names                      #
#  * Caches application information                                           #
#  * Refreshes cache when Android applications are installed/uninstalled     #
#  * Search/filter                                                            #
#  * Multi-selection                                                         #
#  * Select all / select none                                                 #
#  * Launch Android applications                                              #
#  * Create/remove XFCE desktop shortcuts                                     #
#  * Create/remove XFCE "Android Apps" application menu entries               #
#  * Dynamically attempts to obtain original application icons                #
#  * Uses valid .desktop files                                                 #
#  * Uses Termux "am start" for launching                                      #
#  * No hard-coded application package names                                  #
#  * Python 3.14                                                              #
#                                                                            #
###############################################################################

set -u
set -o pipefail

###############################################################################
# CONFIGURATION
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"

PYTHON314="${PREFIX}/bin/python3.14"

CACHE_ROOT="${HOME_DIR}/.cache/android-launcher-manager"
CACHE_FILE="${CACHE_ROOT}/apps.json"
ICON_CACHE="${CACHE_ROOT}/icons"

LOCAL_BIN="${HOME_DIR}/.local/bin"
LAUNCHER_BIN="${LOCAL_BIN}/android-launchers"

APPLICATIONS_DIR="${HOME_DIR}/.local/share/applications"
DESKTOP_DIR="${HOME_DIR}/Desktop"
DESKTOP_DIRECTORIES_DIR="${HOME_DIR}/.local/share/desktop-directories"

MENU_DIR="${HOME_DIR}/.config/menus"
MENU_MERGED_DIR="${MENU_DIR}/applications-merged"

MENU_FILE="${MENU_MERGED_DIR}/android-apps.menu"
DIRECTORY_FILE="${DESKTOP_DIRECTORIES_DIR}/android-apps.directory"

###############################################################################
# COLORS
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

###############################################################################
# BASIC HELPERS
###############################################################################

print_banner() {
    clear 2>/dev/null || true

    echo -e "${CYAN}"
    cat <<'EOF'
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                                                                      ║
    ║                     ANDROID LAUNCHER MANAGER                         ║
    ║                                                                      ║
    ║                  Termux + XFCE Android Integration                   ║
    ║                                                                      ║
    ╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo
}

die() {
    echo
    echo -e "${RED}[ERROR]${NC} $*"
    echo
    exit 1
}

###############################################################################
# CHECK PYTHON 3.14
###############################################################################

check_python() {
    echo -e "${CYAN}[*] Checking Python 3.14...${NC}"

    if [[ ! -x "${PYTHON314}" ]]; then
        echo -e "${RED}[-] Python 3.14 was not found:${NC}"
        echo "    ${PYTHON314}"
        echo
        echo "Install Python 3.14 in Termux first."
        exit 1
    fi

    VERSION="$("${PYTHON314}" --version 2>&1)"

    if [[ "${VERSION}" != Python\ 3.14.* ]]; then
        echo -e "${RED}[-] Wrong Python version:${NC}"
        echo "    ${VERSION}"
        echo
        echo "This launcher requires Python 3.14."
        exit 1
    fi

    echo -e "${GREEN}[+] ${VERSION}${NC}"
}

###############################################################################
# CHECK ANDROID COMMANDS
###############################################################################

check_android_tools() {
    echo
    echo -e "${CYAN}[*] Checking Android interface...${NC}"

    local missing=0

    for command_name in pm cmd am; do
        if command -v "${command_name}" >/dev/null 2>&1; then
            echo -e "${GREEN}[+] ${command_name}${NC}"
        else
            echo -e "${RED}[-] ${command_name} not found${NC}"
            missing=1
        fi
    done

    if [[ "${missing}" -ne 0 ]]; then
        die "Android command interface is unavailable."
    fi

    echo -e "${GREEN}[+] Android interface is available${NC}"
}

###############################################################################
# PREPARE DIRECTORIES
###############################################################################

prepare_directories() {
    mkdir -p \
        "${CACHE_ROOT}" \
        "${ICON_CACHE}" \
        "${LOCAL_BIN}" \
        "${LAUNCHER_BIN}" \
        "${APPLICATIONS_DIR}" \
        "${DESKTOP_DIR}" \
        "${DESKTOP_DIRECTORIES_DIR}" \
        "${MENU_DIR}" \
        "${MENU_MERGED_DIR}"
}

###############################################################################
# EXECUTE PYTHON 3.14
###############################################################################

exec "${PYTHON314}" - "${CACHE_FILE}" "${ICON_CACHE}" "${LAUNCHER_BIN}" \
    "${APPLICATIONS_DIR}" "${DESKTOP_DIR}" "${DESKTOP_DIRECTORIES_DIR}" \
    "${MENU_MERGED_DIR}" "${MENU_FILE}" "${DIRECTORY_FILE}" <<'PYTHON'
###############################################################################
# PYTHON 3.14 APPLICATION
###############################################################################

import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import hashlib
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox


###############################################################################
# ARGUMENTS
###############################################################################

CACHE_FILE = Path(sys.argv[1])
ICON_CACHE = Path(sys.argv[2])
LAUNCHER_BIN = Path(sys.argv[3])
APPLICATIONS_DIR = Path(sys.argv[4])
DESKTOP_DIR = Path(sys.argv[5])
DESKTOP_DIRECTORIES_DIR = Path(sys.argv[6])
MENU_MERGED_DIR = Path(sys.argv[7])
MENU_FILE = Path(sys.argv[8])
DIRECTORY_FILE = Path(sys.argv[9])


###############################################################################
# DIRECTORIES
###############################################################################

for directory in (
    CACHE_FILE.parent,
    ICON_CACHE,
    LAUNCHER_BIN,
    APPLICATIONS_DIR,
    DESKTOP_DIR,
    DESKTOP_DIRECTORIES_DIR,
    MENU_MERGED_DIR,
):
    directory.mkdir(parents=True, exist_ok=True)


###############################################################################
# COLORS / UI
###############################################################################

BG = "#111111"
PANEL = "#181818"
PANEL_2 = "#202020"
PANEL_3 = "#252525"
TEXT = "#eeeeee"
TEXT_MUTED = "#9b9b9b"
ACCENT = "#38bdf8"
ACCENT_2 = "#60a5fa"
BORDER = "#343434"
SUCCESS = "#4ade80"
WARNING = "#facc15"
DANGER = "#f87171"


###############################################################################
# CONSTANTS
###############################################################################

ANDROID_USER = "0"

CUSTOM_CATEGORY = "X-Android-Apps"

MENU_NAME = "Android Apps"

DESKTOP_PREFIX = "android-"
LAUNCHER_PREFIX = "android-"


###############################################################################
# STATE
###############################################################################

apps = []
filtered_apps = []
selected_packages = set()

refresh_in_progress = False


###############################################################################
# SUBPROCESS HELPERS
###############################################################################

def run_command(command, timeout=20):
    """
    Run a command and return stdout.

    No shell is used.
    """

    try:
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            errors="replace",
            timeout=timeout,
        )

        return result.returncode, result.stdout.strip(), result.stderr.strip()

    except subprocess.TimeoutExpired:
        return 124, "", "Command timed out"

    except Exception as exc:
        return 1, "", str(exc)


def command_exists(name):
    return shutil.which(name) is not None


###############################################################################
# PACKAGE / ACTIVITY RESOLUTION
###############################################################################

def normalize_component(package_name, component):
    """
    Convert Android component notation into:

        package/activity

    Examples:

        com.example/.MainActivity
        com.example/com.example.MainActivity

    The resolver output is preserved when possible.
    """

    component = component.strip()

    if not component:
        return ""

    if component.startswith(package_name + "/"):
        return component

    if component.startswith("."):
        return package_name + "/" + component

    if "/" in component:
        return component

    if component.startswith(package_name):
        return package_name + "/" + component

    return package_name + "/" + component


def resolve_launcher_activity(package_name):
    """
    Resolve MAIN + LAUNCHER using Android's PackageManager.

    This is the same Android package-manager mechanism used to discover
    launcher activities rather than guessing activity names.
    """

    commands = [
        [
            "cmd",
            "package",
            "resolve-activity",
            "--user",
            ANDROID_USER,
            "--brief",
            "-a",
            "android.intent.action.MAIN",
            "-c",
            "android.intent.category.LAUNCHER",
            package_name,
        ],
        [
            "cmd",
            "package",
            "resolve-activity",
            "--user",
            ANDROID_USER,
            "--brief",
            package_name,
        ],
    ]

    for command in commands:
        code, stdout, stderr = run_command(command, timeout=12)

        if code != 0:
            continue

        lines = [
            line.strip()
            for line in stdout.splitlines()
            if line.strip()
        ]

        for line in reversed(lines):
            if "/" in line and not line.startswith("priority="):
                component = normalize_component(package_name, line)

                if component.startswith(package_name + "/"):
                    return component

    return ""


###############################################################################
# PACKAGE NAME DISCOVERY
###############################################################################

def get_launcher_packages():
    """
    Discover packages which have a MAIN/LAUNCHER activity.

    We intentionally do not hard-code package names.
    """

    code, stdout, stderr = run_command(
        [
            "cmd",
            "package",
            "query-activities",
            "--user",
            ANDROID_USER,
            "--brief",
            "-a",
            "android.intent.action.MAIN",
            "-c",
            "android.intent.category.LAUNCHER",
        ],
        timeout=40,
    )

    packages = set()

    if code == 0:
        for line in stdout.splitlines():
            line = line.strip()

            if "/" not in line:
                continue

            if line.startswith("priority="):
                continue

            package_name = line.split("/", 1)[0]

            if re.fullmatch(r"[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+", package_name):
                packages.add(package_name)

    if packages:
        return sorted(packages, key=str.casefold)

    # Fallback: list installed packages and individually resolve them.
    code, stdout, stderr = run_command(
        [
            "pm",
            "list",
            "packages",
            "--user",
            ANDROID_USER,
        ],
        timeout=40,
    )

    if code != 0:
        return []

    candidate_packages = []

    for line in stdout.splitlines():
        line = line.strip()

        if line.startswith("package:"):
            package_name = line[len("package:"):].strip()

            if package_name:
                candidate_packages.append(package_name)

    for package_name in candidate_packages:
        activity = resolve_launcher_activity(package_name)

        if activity:
            packages.add(package_name)

    return sorted(packages, key=str.casefold)


###############################################################################
# APPLICATION LABEL DISCOVERY
###############################################################################

def clean_android_label(value):
    value = value.strip()

    value = value.strip("'\"")

    value = re.sub(r"^application-label(?:-[\w-]+)?\s*[:=]\s*", "", value)

    value = value.strip("'\"")

    return value.strip()


def label_from_aapt(package_name):
    """
    Try aapt/aapt2 against the installed APK.

    This is used dynamically. No application names are hard-coded.
    """

    if not command_exists("aapt2") and not command_exists("aapt"):
        return ""

    code, stdout, stderr = run_command(
        ["pm", "path", package_name],
        timeout=10,
    )

    if code != 0:
        return ""

    apk_path = ""

    for line in stdout.splitlines():
        line = line.strip()

        if line.startswith("package:"):
            candidate = line[len("package:"):].strip()

            if candidate.endswith(".apk"):
                apk_path = candidate
                break

    if not apk_path:
        return ""

    for tool in ("aapt2", "aapt"):
        if not command_exists(tool):
            continue

        if tool == "aapt2":
            command = [
                tool,
                "dump",
                "badging",
                apk_path,
            ]
        else:
            command = [
                tool,
                "dump",
                "badging",
                apk_path,
            ]

        code, stdout, stderr = run_command(
            command,
            timeout=20,
        )

        if code != 0:
            continue

        match = re.search(
            r"application-label(?:-[^:]+)?='([^']*)'",
            stdout,
            re.IGNORECASE,
        )

        if match:
            label = match.group(1).strip()

            if label:
                return label

    return ""


def label_from_package_dump(package_name):
    """
    Attempt to obtain the application label from Android's package dump.
    """

    commands = [
        ["cmd", "package", "dump", package_name],
        ["dumpsys", "package", package_name],
    ]

    patterns = [
        r"Application Label:\s*(.+)",
        r"application-label:\s*(.+)",
        r"applicationLabel:\s*(.+)",
        r"label:\s*(.+)",
    ]

    for command in commands:
        code, stdout, stderr = run_command(
            command,
            timeout=15,
        )

        if code != 0:
            continue

        for pattern in patterns:
            match = re.search(
                pattern,
                stdout,
                re.IGNORECASE,
            )

            if match:
                value = clean_android_label(match.group(1))

                if value and value != package_name:
                    return value

    return ""


def prettify_package_name(package_name):
    """
    Last-resort display name.

    This is deliberately only a fallback if Android does not expose
    its application label through the available interfaces.
    """

    last = package_name.split(".")[-1]

    if not last:
        return package_name

    last = re.sub(
        r"([a-z0-9])([A-Z])",
        r"\1 \2",
        last,
    )

    last = last.replace("_", " ")
    last = last.replace("-", " ")

    return last.title()


def get_application_name(package_name):
    """
    Resolve the real human-readable Android label.

    Order:
        1. Android package dump
        2. aapt/aapt2
        3. fallback formatting
    """

    label = label_from_package_dump(package_name)

    if label:
        return label

    label = label_from_aapt(package_name)

    if label:
        return label

    return prettify_package_name(package_name)


###############################################################################
# APK ICON DISCOVERY
###############################################################################

def get_apk_paths(package_name):
    code, stdout, stderr = run_command(
        ["pm", "path", package_name],
        timeout=10,
    )

    if code != 0:
        return []

    paths = []

    for line in stdout.splitlines():
        line = line.strip()

        if line.startswith("package:"):
            path = line[len("package:"):].strip()

            if path.endswith(".apk"):
                paths.append(path)

    return paths


def find_icon_with_aapt(package_name):
    """
    Find the icon resource path dynamically from the installed APK.
    """

    apk_paths = get_apk_paths(package_name)

    if not apk_paths:
        return None, None

    tools = []

    if command_exists("aapt2"):
        tools.append("aapt2")

    if command_exists("aapt"):
        tools.append("aapt")

    if not tools:
        return None, None

    for apk_path in apk_paths:
        for tool in tools:
            code, stdout, stderr = run_command(
                [
                    tool,
                    "dump",
                    "badging",
                    apk_path,
                ],
                timeout=20,
            )

            if code != 0:
                continue

            match = re.search(
                r"application-icon-\d+:'([^']+)'",
                stdout,
            )

            if not match:
                match = re.search(
                    r"application:.*?icon='([^']+)'",
                    stdout,
                )

            if match:
                return apk_path, match.group(1)

    return None, None


def extract_icon(package_name):
    """
    Attempt to extract the original application icon.

    The Android APK may not be readable directly by the Termux UID.
    In that case the function simply returns no icon instead of breaking
    application discovery.
    """

    cache_file = ICON_CACHE / (hashlib.sha256(
        package_name.encode("utf-8")
    ).hexdigest() + ".png")

    if cache_file.exists():
        return str(cache_file)

    apk_path, icon_path = find_icon_with_aapt(package_name)

    if not apk_path or not icon_path:
        return ""

    if not Path(apk_path).exists():
        return ""

    temporary_dir = ICON_CACHE / (
        hashlib.sha256(
            (package_name + "-tmp").encode("utf-8")
        ).hexdigest()
    )

    temporary_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    try:
        # APK is a ZIP archive.
        import zipfile

        with zipfile.ZipFile(apk_path, "r") as archive:
            candidate = icon_path.lstrip("/")

            if candidate not in archive.namelist():
                matches = [
                    name
                    for name in archive.namelist()
                    if name.endswith("/" + candidate)
                    or name == candidate
                ]

                if not matches:
                    return ""

                candidate = matches[0]

            raw_file = temporary_dir / Path(candidate).name

            with archive.open(candidate) as source:
                with raw_file.open("wb") as target:
                    shutil.copyfileobj(source, target)

        # Tkinter can load PNG directly.
        if raw_file.suffix.lower() == ".png":
            shutil.copy2(
                raw_file,
                cache_file,
            )

            return str(cache_file)

        # Try Pillow if installed.
        try:
            from PIL import Image

            image = Image.open(raw_file)
            image.save(
                cache_file,
                "PNG",
            )

            return str(cache_file)

        except Exception:
            pass

        # Try ImageMagick if available.
        convert_tool = shutil.which("magick") or shutil.which("convert")

        if convert_tool:
            code, stdout, stderr = run_command(
                [
                    convert_tool,
                    str(raw_file),
                    str(cache_file),
                ],
                timeout=20,
            )

            if code == 0 and cache_file.exists():
                return str(cache_file)

        return ""

    except Exception:
        return ""

    finally:
        shutil.rmtree(
            temporary_dir,
            ignore_errors=True,
        )


###############################################################################
# CACHE
###############################################################################

def load_cache():
    if not CACHE_FILE.exists():
        return []

    try:
        with CACHE_FILE.open(
            "r",
            encoding="utf-8",
        ) as handle:
            data = json.load(handle)

        if isinstance(data, list):
            return data

    except Exception:
        pass

    return []


def save_cache(data):
    temporary = CACHE_FILE.with_suffix(".tmp")

    with temporary.open(
        "w",
        encoding="utf-8",
    ) as handle:
        json.dump(
            data,
            handle,
            indent=2,
            ensure_ascii=False,
        )

    temporary.replace(CACHE_FILE)


def cache_application(package_name, activity):
    """
    Update one application record while retaining useful cached values.
    """

    previous = None

    for item in apps:
        if item.get("package") == package_name:
            previous = item
            break

    name = get_application_name(package_name)

    icon = ""

    if previous:
        icon = previous.get("icon", "")

        if icon and not Path(icon).exists():
            icon = ""

    if not icon:
        icon = extract_icon(package_name)

    if not name:
        name = prettify_package_name(package_name)

    result = {
        "name": name,
        "package": package_name,
        "activity": activity,
        "component": activity,
        "icon": icon,
        "updated": int(time.time()),
    }

    return result


###############################################################################
# APP SCANNING
###############################################################################

def scan_android_apps():
    package_names = get_launcher_packages()

    found = []

    for index, package_name in enumerate(package_names, start=1):
        activity = resolve_launcher_activity(package_name)

        if not activity:
            continue

        record = cache_application(
            package_name,
            activity,
        )

        found.append(record)

    found.sort(
        key=lambda item: item.get("name", "").casefold()
    )

    save_cache(found)

    return found


###############################################################################
# COMPONENT / FILE NAMES
###############################################################################

def safe_id(package_name):
    return re.sub(
        r"[^A-Za-z0-9_.-]",
        "_",
        package_name,
    )


def desktop_filename(app):
    return (
        DESKTOP_PREFIX
        + safe_id(app["package"])
        + ".desktop"
    )


def launcher_filename(app):
    return (
        LAUNCHER_PREFIX
        + safe_id(app["package"])
    )


def desktop_path(app):
    return DESKTOP_DIR / desktop_filename(app)


def menu_desktop_path(app):
    return APPLICATIONS_DIR / desktop_filename(app)


def launcher_path(app):
    return LAUNCHER_BIN / launcher_filename(app)


###############################################################################
# ANDROID LAUNCHER WRAPPER
###############################################################################

def write_launcher_wrapper(app):
    """
    Create a real executable launcher.

    XFCE launches this file.

    The wrapper itself invokes Android's am with the exact resolved
    package/activity component.
    """

    path = launcher_path(app)

    package_name = app["package"]
    component = app["component"]

    content = """#!/data/data/com.termux/files/usr/bin/bash
set -u

AM_BIN="/data/data/com.termux/files/usr/bin/am"

if [ ! -x "${AM_BIN}" ]; then
    echo "Android Activity Manager was not found."
    exit 1
fi

exec "${AM_BIN}" start --user 0 -n "__COMPONENT__"
""".replace(
        "__COMPONENT__",
        component,
    )

    path.write_text(
        content,
        encoding="utf-8",
    )

    path.chmod(0o755)

    return path


###############################################################################
# DESKTOP ENTRY
###############################################################################

def desktop_entry_text(app):
    name = app["name"]
    package_name = app["package"]
    icon = app.get("icon", "")

    launcher = write_launcher_wrapper(app)

    icon_value = icon if icon else "application-x-executable"

    return """[Desktop Entry]
Version=1.0
Type=Application
Name={name}
GenericName=Android Application
Comment=Launch {name}
Exec={exec_path}
Icon={icon}
Terminal=false
StartupNotify=true
Categories={category};
X-XFCE-Source=Android Launcher Manager
X-Android-Package={package}
X-Android-Activity={activity}
""".format(
        name=name.replace("\n", " "),
        exec_path=str(launcher),
        icon=icon_value,
        category=CUSTOM_CATEGORY,
        package=package_name,
        activity=app["activity"],
    )


def create_desktop_shortcut(app):
    """
    Create an actual XFCE desktop .desktop file.
    """

    path = desktop_path(app)

    path.write_text(
        desktop_entry_text(app),
        encoding="utf-8",
    )

    path.chmod(0o755)

    return path


def remove_desktop_shortcut(app):
    path = desktop_path(app)

    try:
        path.unlink()
    except FileNotFoundError:
        pass


###############################################################################
# XFCE APPLICATION MENU
###############################################################################

def ensure_android_apps_directory():
    """
    Directory entry that gives the submenu its visible name.
    """

    content = """[Desktop Entry]
Version=1.0
Type=Directory
Name=Android Apps
Comment=Android applications
Icon=application-x-executable
"""

    DIRECTORY_FILE.write_text(
        content,
        encoding="utf-8",
    )


def ensure_android_apps_menu():
    """
    Create a proper freedesktop/XFCE merged submenu.

    The custom category is X-Android-Apps.
    """

    ensure_android_apps_directory()

    content = """<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
"http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
    <Name>Applications</Name>

    <Menu>
        <Name>Android Apps</Name>
        <Directory>android-apps.directory</Directory>

        <Include>
            <Category>X-Android-Apps</Category>
        </Include>
    </Menu>
</Menu>
"""

    MENU_FILE.write_text(
        content,
        encoding="utf-8",
    )


def add_to_application_menu(app):
    """
    Add the selected application to Android Apps.

    The .desktop file lives in ~/.local/share/applications.
    """

    ensure_android_apps_menu()

    path = menu_desktop_path(app)

    path.write_text(
        desktop_entry_text(app),
        encoding="utf-8",
    )

    path.chmod(0o644)

    refresh_xfce_menu()


def remove_from_application_menu(app):
    path = menu_desktop_path(app)

    try:
        path.unlink()
    except FileNotFoundError:
        pass

    refresh_xfce_menu()


def refresh_xfce_menu():
    """
    Ask XFCE to refresh its menu where supported.
    """

    commands = [
        ["xfdesktop", "--reload"],
    ]

    for command in commands:
        if command_exists(command[0]):
            run_command(
                command,
                timeout=5,
            )


###############################################################################
# STATUS
###############################################################################

def is_in_menu(app):
    return menu_desktop_path(app).exists()


def is_on_desktop(app):
    return desktop_path(app).exists()


###############################################################################
# TKINTER ICONS
###############################################################################

tk_image_cache = {}


def get_tk_icon(app):
    icon_path = app.get("icon", "")

    if not icon_path:
        return None

    if not Path(icon_path).exists():
        return None

    if icon_path in tk_image_cache:
        return tk_image_cache[icon_path]

    try:
        image = tk.PhotoImage(
            file=icon_path,
        )

        # Keep icons visually compact.
        width = image.width()
        height = image.height()

        max_size = 48

        if width > max_size or height > max_size:
            scale = max(
                (width + max_size - 1) // max_size,
                (height + max_size - 1) // max_size,
            )

            image = image.subsample(
                scale,
                scale,
            )

        tk_image_cache[icon_path] = image

        return image

    except Exception:
        return None


###############################################################################
# MAIN WINDOW
###############################################################################

root = tk.Tk()

root.title("Android Apps")
root.geometry("1180x760")
root.minsize(900, 600)

try:
    root.tk.call(
        "tk",
        "scaling",
        1.0,
    )
except Exception:
    pass


###############################################################################
# TK STYLE
###############################################################################

style = ttk.Style(root)

try:
    style.theme_use("clam")
except Exception:
    pass


style.configure(
    ".",
    background=BG,
    foreground=TEXT,
    font=("DejaVu Sans", 10),
)

style.configure(
    "TFrame",
    background=BG,
)

style.configure(
    "Panel.TFrame",
    background=PANEL,
)

style.configure(
    "Title.TLabel",
    background=BG,
    foreground=TEXT,
    font=("DejaVu Sans", 24, "bold"),
)

style.configure(
    "Subtitle.TLabel",
    background=BG,
    foreground=TEXT_MUTED,
    font=("DejaVu Sans", 10),
)

style.configure(
    "Section.TLabel",
    background=PANEL,
    foreground=ACCENT,
    font=("DejaVu Sans", 14, "bold"),
)

style.configure(
    "Status.TLabel",
    background=BG,
    foreground=TEXT_MUTED,
)

style.configure(
    "TButton",
    background=PANEL_3,
    foreground=TEXT,
    bordercolor=BORDER,
    focusthickness=1,
    padding=(12, 8),
)

style.map(
    "TButton",
    background=[
        ("active", "#303030"),
        ("pressed", "#383838"),
    ],
    foreground=[
        ("disabled", "#666666"),
        ("active", "#ffffff"),
    ],
)

style.configure(
    "Accent.TButton",
    background=ACCENT_2,
    foreground="#ffffff",
    font=("DejaVu Sans", 10, "bold"),
)

style.map(
    "Accent.TButton",
    background=[
        ("active", ACCENT),
        ("pressed", "#2563eb"),
    ],
)

style.configure(
    "Danger.TButton",
    background="#3a1d1d",
    foreground=DANGER,
)

style.configure(
    "Treeview",
    background="#161616",
    fieldbackground="#161616",
    foreground=TEXT,
    rowheight=48,
    bordercolor=BORDER,
    lightcolor=BORDER,
    darkcolor=BORDER,
)

style.configure(
    "Treeview.Heading",
    background="#222222",
    foreground=TEXT_MUTED,
    font=("DejaVu Sans", 9, "bold"),
    padding=8,
)

style.map(
    "Treeview",
    background=[
        ("selected", "#174b66"),
    ],
    foreground=[
        ("selected", "#ffffff"),
    ],
)


###############################################################################
# TOP HEADER
###############################################################################

header = ttk.Frame(root)
header.pack(
    fill="x",
    padx=26,
    pady=(22, 8),
)

title = ttk.Label(
    header,
    text="Android Apps",
    style="Title.TLabel",
)

title.pack(
    anchor="w",
)

subtitle = ttk.Label(
    header,
    text="Launch and manage Android applications",
    style="Subtitle.TLabel",
)

subtitle.pack(
    anchor="w",
    pady=(2, 0),
)


###############################################################################
# SEARCH BAR
###############################################################################

search_frame = ttk.Frame(root)
search_frame.pack(
    fill="x",
    padx=26,
    pady=(10, 12),
)

search_var = tk.StringVar()

search_entry = tk.Entry(
    search_frame,
    textvariable=search_var,
    bg="#181818",
    fg=TEXT,
    insertbackground=TEXT,
    relief="flat",
    highlightthickness=1,
    highlightbackground=BORDER,
    highlightcolor=ACCENT,
    font=("DejaVu Sans", 11),
)

search_entry.pack(
    fill="x",
    ipady=10,
)


###############################################################################
# TOOLBAR
###############################################################################

toolbar = ttk.Frame(root)
toolbar.pack(
    fill="x",
    padx=26,
    pady=(0, 12),
)

select_all_button = ttk.Button(
    toolbar,
    text="Select All",
)

select_all_button.pack(
    side="left",
    padx=(0, 6),
)

select_none_button = ttk.Button(
    toolbar,
    text="Select None",
)

select_none_button.pack(
    side="left",
    padx=6,
)

launch_button = ttk.Button(
    toolbar,
    text="Launch Selected",
    style="Accent.TButton",
)

launch_button.pack(
    side="left",
    padx=6,
)

menu_add_button = ttk.Button(
    toolbar,
    text="Add to Android Apps",
)

menu_add_button.pack(
    side="left",
    padx=6,
)

menu_remove_button = ttk.Button(
    toolbar,
    text="Remove from Android Apps",
)

menu_remove_button.pack(
    side="left",
    padx=6,
)

desktop_add_button = ttk.Button(
    toolbar,
    text="Create Desktop Shortcut",
)

desktop_add_button.pack(
    side="left",
    padx=6,
)

desktop_remove_button = ttk.Button(
    toolbar,
    text="Remove Desktop Shortcut",
)

desktop_remove_button.pack(
    side="left",
    padx=6,
)

refresh_button = ttk.Button(
    toolbar,
    text="Refresh",
)

refresh_button.pack(
    side="right",
)


###############################################################################
# MAIN CONTENT
###############################################################################

content = ttk.Frame(root)
content.pack(
    fill="both",
    expand=True,
    padx=26,
    pady=(0, 12),
)

left_panel = ttk.Frame(
    content,
    style="Panel.TFrame",
)

left_panel.pack(
    side="left",
    fill="both",
    expand=True,
)


right_panel = ttk.Frame(
    content,
    style="Panel.TFrame",
    width=310,
)

right_panel.pack(
    side="right",
    fill="y",
    padx=(14, 0),
)

right_panel.pack_propagate(False)


###############################################################################
# TREE
###############################################################################

tree_frame = ttk.Frame(
    left_panel,
    style="Panel.TFrame",
)

tree_frame.pack(
    fill="both",
    expand=True,
    padx=1,
    pady=1,
)

columns = (
    "name",
    "package",
    "launcher",
)

tree = ttk.Treeview(
    tree_frame,
    columns=columns,
    show="tree headings",
    selectmode="extended",
)

tree.heading(
    "#0",
    text="",
)

tree.heading(
    "name",
    text="Application",
)

tree.heading(
    "package",
    text="Package",
)

tree.heading(
    "launcher",
    text="Launcher Activity",
)

tree.column(
    "#0",
    width=52,
    minwidth=52,
    stretch=False,
)

tree.column(
    "name",
    width=260,
    minwidth=180,
)

tree.column(
    "package",
    width=260,
    minwidth=180,
)

tree.column(
    "launcher",
    width=400,
    minwidth=220,
)

scrollbar = ttk.Scrollbar(
    tree_frame,
    orient="vertical",
    command=tree.yview,
)

tree.configure(
    yscrollcommand=scrollbar.set,
)

tree.pack(
    side="left",
    fill="both",
    expand=True,
)

scrollbar.pack(
    side="right",
    fill="y",
)


###############################################################################
# DETAILS PANEL
###############################################################################

details_title = ttk.Label(
    right_panel,
    text="Application",
    style="Section.TLabel",
)

details_title.pack(
    anchor="w",
    padx=20,
    pady=(20, 16),
)


def detail_label(parent, text):
    return ttk.Label(
        parent,
        text=text,
        style="Subtitle.TLabel",
    )


def detail_value(parent):
    entry = tk.Entry(
        parent,
        bg="#151515",
        fg=TEXT,
        insertbackground=TEXT,
        relief="flat",
        highlightthickness=1,
        highlightbackground=BORDER,
        highlightcolor=ACCENT,
        font=("DejaVu Sans", 9),
    )

    entry.configure(
        state="readonly",
        readonlybackground="#151515",
    )

    return entry


name_label = detail_label(
    right_panel,
    "Name",
)

name_label.pack(
    anchor="w",
    padx=20,
)

name_value = detail_value(
    right_panel,
)

name_value.pack(
    fill="x",
    padx=20,
    pady=(5, 12),
    ipady=6,
)


package_label = detail_label(
    right_panel,
    "Package",
)

package_label.pack(
    anchor="w",
    padx=20,
)

package_value = detail_value(
    right_panel,
)

package_value.pack(
    fill="x",
    padx=20,
    pady=(5, 12),
    ipady=6,
)


activity_label = detail_label(
    right_panel,
    "Launcher",
)

activity_label.pack(
    anchor="w",
    padx=20,
)

activity_value = detail_value(
    right_panel,
)

activity_value.pack(
    fill="x",
    padx=20,
    pady=(5, 12),
    ipady=6,
)


command_label = detail_label(
    right_panel,
    "Launch command",
)

command_label.pack(
    anchor="w",
    padx=20,
)

command_value = detail_value(
    right_panel,
)

command_value.pack(
    fill="x",
    padx=20,
    pady=(5, 16),
    ipady=6,
)


###############################################################################
# STATUS CARD
###############################################################################

status_card = tk.Frame(
    right_panel,
    bg=PANEL_2,
)

status_card.pack(
    fill="x",
    padx=20,
    pady=(0, 16),
)

status_heading = tk.Label(
    status_card,
    text="STATUS",
    bg=PANEL_2,
    fg=ACCENT,
    font=("DejaVu Sans", 10, "bold"),
)

status_heading.pack(
    anchor="w",
    padx=14,
    pady=(12, 8),
)

menu_status = tk.Label(
    status_card,
    text="Menu  —",
    bg=PANEL_2,
    fg=TEXT_MUTED,
    anchor="w",
)

menu_status.pack(
    fill="x",
    padx=14,
    pady=2,
)

desktop_status = tk.Label(
    status_card,
    text="Desktop  —",
    bg=PANEL_2,
    fg=TEXT_MUTED,
    anchor="w",
)

desktop_status.pack(
    fill="x",
    padx=14,
    pady=(2, 12),
)


###############################################################################
# RIGHT-SIDE ACTIONS
###############################################################################

right_launch_button = ttk.Button(
    right_panel,
    text="Launch",
)

right_launch_button.pack(
    fill="x",
    padx=20,
    pady=4,
)

right_menu_add_button = ttk.Button(
    right_panel,
    text="Add to Android Apps menu",
)

right_menu_add_button.pack(
    fill="x",
    padx=20,
    pady=4,
)

right_menu_remove_button = ttk.Button(
    right_panel,
    text="Remove from Android Apps menu",
)

right_menu_remove_button.pack(
    fill="x",
    padx=20,
    pady=4,
)

right_desktop_add_button = ttk.Button(
    right_panel,
    text="Create desktop shortcut",
)

right_desktop_add_button.pack(
    fill="x",
    padx=20,
    pady=4,
)

right_desktop_remove_button = ttk.Button(
    right_panel,
    text="Remove desktop shortcut",
)

right_desktop_remove_button.pack(
    fill="x",
    padx=20,
    pady=4,
)


###############################################################################
# BOTTOM STATUS
###############################################################################

bottom = ttk.Frame(root)

bottom.pack(
    fill="x",
    padx=26,
    pady=(0, 18),
)

status_var = tk.StringVar(
    value="Ready"
)

status_label = ttk.Label(
    bottom,
    textvariable=status_var,
    style="Status.TLabel",
)

status_label.pack(
    side="left",
)


###############################################################################
# TREE MANAGEMENT
###############################################################################

tree_items = {}


def set_readonly(entry, value):
    entry.configure(
        state="normal",
    )

    entry.delete(
        0,
        tk.END,
    )

    entry.insert(
        0,
        value,
    )

    entry.configure(
        state="readonly",
    )


def update_details():
    selection = tree.selection()

    if not selection:
        set_readonly(name_value, "")
        set_readonly(package_value, "")
        set_readonly(activity_value, "")
        set_readonly(command_value, "")

        menu_status.configure(
            text="Menu  —",
            fg=TEXT_MUTED,
        )

        desktop_status.configure(
            text="Desktop  —",
            fg=TEXT_MUTED,
        )

        return

    item_id = selection[0]

    app = tree_items.get(item_id)

    if not app:
        return

    set_readonly(
        name_value,
        app["name"],
    )

    set_readonly(
        package_value,
        app["package"],
    )

    set_readonly(
        activity_value,
        app["activity"],
    )

    set_readonly(
        command_value,
        "am start --user 0 -n " + app["component"],
    )

    if is_in_menu(app):
        menu_status.configure(
            text="Menu  ✓ Android Apps",
            fg=SUCCESS,
        )
    else:
        menu_status.configure(
            text="Menu  — Not installed",
            fg=TEXT_MUTED,
        )

    if is_on_desktop(app):
        desktop_status.configure(
            text="Desktop  ✓ Shortcut",
            fg=SUCCESS,
        )
    else:
        desktop_status.configure(
            text="Desktop  — No shortcut",
            fg=TEXT_MUTED,
        )


def rebuild_tree():
    global filtered_apps

    for item in tree.get_children():
        tree.delete(item)

    tree_items.clear()

    query = search_var.get().strip().casefold()

    if query:
        filtered_apps = [
            app
            for app in apps
            if (
                query in app.get("name", "").casefold()
                or query in app.get("package", "").casefold()
                or query in app.get("activity", "").casefold()
            )
        ]
    else:
        filtered_apps = list(apps)

    for app in filtered_apps:
        icon = get_tk_icon(app)

        values = (
            app.get("name", ""),
            app.get("package", ""),
            app.get("activity", ""),
        )

        item_id = tree.insert(
            "",
            "end",
            text="",
            image=icon if icon else "",
            values=values,
        )

        tree_items[item_id] = app

    status_var.set(
        "{} applications".format(
            len(filtered_apps)
        )
    )

    update_details()


def selected_apps():
    result = []

    for item_id in tree.selection():
        app = tree_items.get(item_id)

        if app:
            result.append(app)

    return result


###############################################################################
# ACTIONS
###############################################################################

def launch_app(app):
    component = app["component"]

    code, stdout, stderr = run_command(
        [
            "am",
            "start",
            "--user",
            ANDROID_USER,
            "-n",
            component,
        ],
        timeout=15,
    )

    if code != 0:
        messagebox.showerror(
            "Launch failed",
            "Could not launch:\n\n{}\n\n{}".format(
                app["name"],
                stderr or stdout or "Unknown Android error",
            ),
            parent=root,
        )

        return False

    return True


def launch_selected():
    selection = selected_apps()

    if not selection:
        messagebox.showinfo(
            "No application selected",
            "Select one or more applications first.",
            parent=root,
        )

        return

    failures = []

    for app in selection:
        if not launch_app(app):
            failures.append(app["name"])

    if failures:
        status_var.set(
            "{} failed to launch".format(
                len(failures)
            )
        )
    else:
        status_var.set(
            "Launched {} application(s)".format(
                len(selection)
            )
        )


def add_selected_menu():
    selection = selected_apps()

    if not selection:
        messagebox.showinfo(
            "No application selected",
            "Select one or more applications first.",
            parent=root,
        )

        return

    for app in selection:
        add_to_application_menu(app)

    status_var.set(
        "Added {} application(s) to Android Apps".format(
            len(selection)
        )
    )

    update_details()


def remove_selected_menu():
    selection = selected_apps()

    if not selection:
        messagebox.showinfo(
            "No application selected",
            "Select one or more applications first.",
            parent=root,
        )

        return

    for app in selection:
        remove_from_application_menu(app)

    status_var.set(
        "Removed {} application(s) from Android Apps".format(
            len(selection)
        )
    )

    update_details()


def add_selected_desktop():
    selection = selected_apps()

    if not selection:
        messagebox.showinfo(
            "No application selected",
            "Select one or more applications first.",
            parent=root,
        )

        return

    for app in selection:
        create_desktop_shortcut(app)

    status_var.set(
        "Created {} desktop shortcut(s)".format(
            len(selection)
        )
    )

    update_details()


def remove_selected_desktop():
    selection = selected_apps()

    if not selection:
        messagebox.showinfo(
            "No application selected",
            "Select one or more applications first.",
            parent=root,
        )

        return

    for app in selection:
        remove_desktop_shortcut(app)

    status_var.set(
        "Removed {} desktop shortcut(s)".format(
            len(selection)
        )
    )

    update_details()


def launch_single():
    selection = selected_apps()

    if not selection:
        return

    launch_app(selection[0])

    status_var.set(
        "Launching {}".format(
            selection[0]["name"]
        )
    )


###############################################################################
# SELECTION
###############################################################################

def select_all():
    tree.selection_set(
        tree.get_children()
    )

    update_details()

    status_var.set(
        "{} applications selected".format(
            len(tree.selection())
        )
    )


def select_none():
    tree.selection_remove(
        tree.selection()
    )

    update_details()

    status_var.set("Selection cleared")


###############################################################################
# REFRESH
###############################################################################

def refresh_worker():
    global refresh_in_progress
    global apps
    global selected_packages

    if refresh_in_progress:
        return

    refresh_in_progress = True

    refresh_button.configure(
        state="disabled",
    )

    status_var.set(
        "Refreshing Android applications..."
    )

    def worker():
        global apps
        global refresh_in_progress

        try:
            new_apps = scan_android_apps()

            apps = new_apps

            selected_packages.clear()

            root.after(
                0,
                rebuild_tree,
            )

            root.after(
                0,
                lambda: status_var.set(
                    "Found {} Android launcher applications".format(
                        len(apps)
                    )
                ),
            )

        except Exception as exc:
            root.after(
                0,
                lambda: messagebox.showerror(
                    "Refresh failed",
                    str(exc),
                    parent=root,
                ),
            )

        finally:
            refresh_in_progress = False

            root.after(
                0,
                lambda: refresh_button.configure(
                    state="normal",
                ),
            )

    threading.Thread(
        target=worker,
        daemon=True,
    ).start()


###############################################################################
# SEARCH
###############################################################################

def search_changed(*args):
    rebuild_tree()


search_var.trace_add(
    "write",
    search_changed,
)


###############################################################################
# TREE EVENTS
###############################################################################

tree.bind(
    "<<TreeviewSelect>>",
    lambda event: update_details(),
)

tree.bind(
    "<Double-1>",
    lambda event: launch_single(),
)


###############################################################################
# KEYBOARD
###############################################################################

root.bind(
    "<Control-a>",
    lambda event: (
        select_all(),
        "break",
    )[1],
)

root.bind(
    "<Escape>",
    lambda event: (
        select_none(),
        "break",
    )[1],
)

root.bind(
    "<Return>",
    lambda event: (
        launch_single(),
        "break",
    )[1],
)


###############################################################################
# BUTTON CONNECTIONS
###############################################################################

select_all_button.configure(
    command=select_all,
)

select_none_button.configure(
    command=select_none,
)

launch_button.configure(
    command=launch_selected,
)

menu_add_button.configure(
    command=add_selected_menu,
)

menu_remove_button.configure(
    command=remove_selected_menu,
)

desktop_add_button.configure(
    command=add_selected_desktop,
)

desktop_remove_button.configure(
    command=remove_selected_desktop,
)

refresh_button.configure(
    command=refresh_worker,
)

right_launch_button.configure(
    command=launch_single,
)

right_menu_add_button.configure(
    command=add_selected_menu,
)

right_menu_remove_button.configure(
    command=remove_selected_menu,
)

right_desktop_add_button.configure(
    command=add_selected_desktop,
)

right_desktop_remove_button.configure(
    command=remove_selected_desktop,
)


###############################################################################
# INITIAL CACHE
###############################################################################

apps = load_cache()

if apps:
    # Validate the cached launcher components lightly before displaying.
    valid_apps = []

    for app in apps:
        if (
            app.get("package")
            and app.get("activity")
            and app.get("component")
        ):
            valid_apps.append(app)

    apps = valid_apps


###############################################################################
# STARTUP
###############################################################################

ensure_android_apps_menu()

rebuild_tree()

# Always perform a background refresh so the cache gets synchronized
# with the current Android installation.
root.after(
    250,
    refresh_worker,
)


###############################################################################
# WINDOW CLOSE
###############################################################################

def close_application():
    root.destroy()


root.protocol(
    "WM_DELETE_WINDOW",
    close_application,
)


###############################################################################
# RUN
###############################################################################

root.mainloop()

PYTHON
