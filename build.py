#!/usr/bin/env python3

import os
import platform
import subprocess
import shutil
import sys
import shlex
import zipfile
import ssl
import urllib.request

EXPORT_TEMPLATES_URL = "https://github.com/godotengine/godot-builds/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"


def get_export_templates_path() -> str:
    match platform.system():
        case "Windows":
            return os.path.expandvars("%APPDATA%\\Godot\\export_templates\\4.3.stable")
        case "Linux":
            return os.path.expanduser(
                "~/.local/share/godot/export_templates/4.3.stable"
            )
        case "MacOS":
            return os.path.expanduser(
                "~/Library/Application Support/Godot/export_templates/4.3.stable"
            )
        case _:
            raise EnvironmentError()


def using_cygwin() -> bool:
    return shutil.which("cygpath")


def using_osxcross() -> bool:
    return len(sys.argv) >= 2 and sys.argv[1] == "osxcross"


def find_godot() -> str | None:
    _print(f"Checking for godot...")
    path = which("godot")
    if path != None:
        _println(f"found! {path}")
        return path
    if platform.system() == "Windows":
        path = which("./godot.exe")
        if path != None:
            _println(f"found! {path}")
            return path
    elif platform.system() == "Linux":
        path = which("./godot.x86_64")
        if path != None:
            _println(f"found! {path}")
            return path

    _println_err("not found!")
    quit(1)


def find_command(cmd: str) -> str | None:
    _print(f"Checking for {cmd}...")
    path: str = which(cmd)
    if path != None:
        _println(f"found! {path}")
        return path
    else:
        _println_err("not found!")
        quit(1)


def find_bash() -> str | None:
    _print(f"Checking for bash...")
    path: str = shutil.which("bash")
    if path != None:
        _println(f"found! {path}")
        return path
    else:
        _println_err("not found!")
        quit(1)


def which(path: str) -> str | None:
    if not using_cygwin():
        return shutil.which(path)
    else:
        which_path = shutil.which("which")
        if which_path != None:
            try:
                return subprocess.check_output([which_path, path]).decode().strip()
            except subprocess.CalledProcessError:
                pass


def run(command: str) -> None:
    if not using_cygwin():
        subprocess.run(shlex.split(command), check=True)
    else:
        bash_path = find_bash()
        if bash_path:
            subprocess.run([bash_path, "--login", "-c", command], check=True)


def _print(text: str) -> None:
    print(f"\033[92m{text}\033[0m", end="")


def _println(text: str) -> None:
    print(f"\033[92m{text}\033[0m")


def _println_err(text: str) -> None:
    print(f"\033[91m{text}\033[0m")


################################################################################


if platform.system() == "Windows":
    os.system("color")


if using_cygwin():
    find_bash()

git_path = find_command("git")
scons_path = find_command("scons")
godot_path = find_godot()

_println("Compiling libm8gd extension...")
if using_osxcross():
    _println("Note: compiling with OSXCross...")
    run(
        "scons target=template_release platform=macos arch=x86_64 osxcross_sdk=darwin23"
    )
else:
    run("scons target=template_release platform=%s" % platform.system())

_print("Checking for Godot export templates...")
export_templates_path = get_export_templates_path()
if not os.path.exists(export_templates_path):

    _print("not found, downloading...")
    ssl._create_default_https_context = ssl._create_unverified_context
    res = urllib.request.urlretrieve(EXPORT_TEMPLATES_URL)
    _println("done!")

    # extract .zip
    with zipfile.ZipFile(res[0], "r") as zip:
        zip.extractall("build")

    # move templates
    shutil.move("build/templates", export_templates_path)

else:
    _println("found!")

_println("Exporting Godot project...")
match platform.system():
    case "Windows":
        run(
            "%s --headless --path project --export-release windows ../build/m8gd_windows.zip"
            % godot_path
        )
    case "Linux":
        if using_osxcross():
            run(
                "%s --headless --path project --export-release macos ../build/m8gd_macos.zip"
                % godot_path
            )
        else:
            run(
                "%s --headless --path project --export-release linux ../build/m8gd_linux.zip"
                % godot_path
            )
    case "MacOS":
        run(
            "%s --headless --path project --export-release macos ../build/m8gd_macos.zip"
            % godot_path
        )

_println("Done!")
quit(0)
