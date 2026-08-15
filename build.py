#!/usr/bin/env python3

import argparse
import os
import platform
import shlex
import shutil
import ssl
import stat
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path
from typing import Literal

PROJ_NAME = "m8gd"
LIB_NAME = "m8"
BUILD_DIR = "build"
GODOT_VERSION = "4.7"
GODOT_BRANCH = "stable"
TARGET_FLAGS = {
    "gui": "--features gdext --lib",
    "gdext": "--features gdext --lib",
}

################################################################################
# Functions/Variables

Platform = Literal["windows", "linux", "macos"]

godot_url_root = f"https://github.com/godotengine/godot/releases/download/{GODOT_VERSION}-{GODOT_BRANCH}/"
godot_zip_export_templates = (
    f"Godot_v{GODOT_VERSION}-{GODOT_BRANCH}_export_templates.tpz"
)
godot_zip_win = f"Godot_v{GODOT_VERSION}-{GODOT_BRANCH}_win64.exe.zip"
godot_zip_linux = f"Godot_v{GODOT_VERSION}-{GODOT_BRANCH}_linux.x86_64.zip"
godot_zip_mac = f"Godot_v{GODOT_VERSION}-{GODOT_BRANCH}_macos.universal.zip"
godot_path_win = f"Godot_v{GODOT_VERSION}-{GODOT_BRANCH}_win64.exe"
godot_path_linux = f"Godot_v{GODOT_VERSION}-{GODOT_BRANCH}_linux.x86_64"
godot_path_mac = "Godot.app"

################################################################################
# Argument Parser

parser = argparse.ArgumentParser()
_ = parser.add_argument(
    "target",
    type=str,
    choices=list(TARGET_FLAGS.keys()),
    default=next(iter(TARGET_FLAGS.keys())),
    help=f"set the target build type ({', '.join(TARGET_FLAGS.keys())})",
)
_ = parser.add_argument(
    "--release",
    action="store_true",
    help=f"build the release release version of {PROJ_NAME}",
)
# _ = parser.add_argument(
#     "--extension",
#     action="store_true",
#     help=f"only build the lib{PROJ_NAME} GDExtension (does not export {PROJ_NAME})",
# )
_ = parser.add_argument(
    "--platform",
    type=str,
    choices=["windows", "linux", "macos"],
    default="",
    help="set the target platform to build for",
)
_ = parser.add_argument(
    "--nodownload",
    action="store_true",
    help="run this script without downloading anything",
)


def main() -> None:

    args = parser.parse_args()
    build_target = str(args.target)  # pyright: ignore[reportAny]
    build_platform = get_platform(str(args.platform))  # pyright: ignore[reportAny]
    is_release = bool(args.release)  # pyright: ignore[reportAny]
    is_nodownload = bool(args.nodownload)  # pyright: ignore[reportAny]

    match build_target:
        case "cli":
            build_export = False
        case "gui":
            build_export = True
        case "gdext":
            build_export = False
        case _:
            raise RuntimeError(f"Unsupported build target: {build_target}")

    println(f"Building for {build_platform} platform...")

    match build_platform:
        case "macos":
            app_extension = ".app"
            cargo_targets = ["x86_64-apple-darwin", "aarch64-apple-darwin"]
        case "windows":
            app_extension = ".exe"
            cargo_targets = ["x86_64-pc-windows-gnu"]
            # _ = os.system("color")
        case "linux":
            app_extension = ".x86_64"
            cargo_targets = ["x86_64-unknown-linux-gnu"]

    if is_release:
        godot_target = "--export-release"
    else:
        godot_target = "--export-debug"

    # create build directory if doesn't exist

    build_path = Path(BUILD_DIR)
    build_path.mkdir(exist_ok=True)

    exec_cargo_build(build_target, is_release, build_platform, cargo_targets)

    if not build_export:
        println("Done!")
        sys.exit(0)

    # find or download Godot export templates

    try:
        godot_path = find_godot()
        found_godot = True
        println("Found godot!")
    except RuntimeError:
        godot_path = None
        found_godot = False

    export_templates_path = Path(get_export_templates_path())
    if (
        found_godot
        and export_templates_path.is_dir()
        and any(export_templates_path.iterdir())
    ):
        found_godot_templates = True
        println("Found export templates!")
    else:
        found_godot_templates = False

    if not found_godot_templates:
        if is_nodownload:
            printerr("Could not find export templates!")
            println(
                "Download required to continue, but found --nodownload flag. Exiting."
            )
            sys.exit(1)

        url: str = f"{godot_url_root}{godot_zip_export_templates}"

        download_zip(url, BUILD_DIR)
        # move templates
        if found_godot:
            _ = shutil.move(f"{BUILD_DIR}/templates", export_templates_path)
        else:
            _ = shutil.move(
                f"{BUILD_DIR}/templates/",
                f"{BUILD_DIR}/editor_data/export_templates/{GODOT_VERSION}.{GODOT_BRANCH}/",
            )

    # find or download Godot editor

    if not found_godot:
        if is_nodownload:
            printerr("Could not find godot!")
            println(
                "Download required to continue, but found --nodownload flag. Exiting."
            )
            sys.exit(1)

        match build_platform:
            case "windows":
                url = f"{godot_url_root}{godot_zip_win}"
            case "linux":
                url = f"{godot_url_root}{godot_zip_linux}"
            case "macos":
                url = f"{godot_url_root}{godot_zip_mac}"

        download_zip(url, BUILD_DIR)
        Path(f"{BUILD_DIR}/_sc_").touch()
        godot_path = find_godot()

    # export the Godot project

    println(f"Exporting Godot project for {build_platform} platform...")
    exec("ls -l ./build/")
    Path(f"{BUILD_DIR}/gui").mkdir(parents=True, exist_ok=True)
    exec(
        f"{godot_path} --headless --path godot {godot_target} {build_platform} ../{BUILD_DIR}/gui/{PROJ_NAME}{app_extension}"
    )
    println('Done! The exported app will be found in the "build" folder.')


_BOLD_ = "\033[1m"
_RESET_ = "\033[0m"
_GREEN_ = "\033[92m"
_RED_ = "\033[91m"
_BLUE_ = "\033[34m"


def println(text: str) -> None:
    print(f"{_GREEN_}:: {text}{_RESET_}", flush=True)


def printinfo(text: str) -> None:
    print(f"{_BLUE_} > {text}{_RESET_}", flush=True)


def printerr(text: str) -> None:
    print(f"{_RED_}{text}{_RESET_}")


def get_export_templates_path() -> str:
    match platform.system():
        case "Windows":
            return os.path.expandvars(
                f"%APPDATA%\\Godot\\export_templates\\{GODOT_VERSION}.stable"
            )
        case "Linux":
            return os.path.expanduser(
                f"~/.local/share/godot/export_templates/{GODOT_VERSION}.stable"
            )
        case "MacOS" | "Darwin":
            return os.path.expanduser(
                f"~/Library/Application Support/Godot/export_templates/{GODOT_VERSION}.stable"
            )
        case _:
            raise OSError()


def is_using_cygwin() -> bool:
    return bool(shutil.which("cygpath"))


def find_godot() -> str:
    """
    Find the Godot executable in the system PATH or in the build directory.
    """
    # first try to find godot in PATH
    path = which("godot")

    if path != None:
        println(f"found! {path}")
        return path

    # if not found, try to find godot in the build directory
    if platform.system() == "Windows":
        file_path = Path(f"{BUILD_DIR}/{godot_path_win}")
    elif platform.system() == "Linux":
        file_path = Path(f"{BUILD_DIR}/{godot_path_linux}")
    elif platform.system() == "Darwin":  # MacOS
        file_path = Path(f"{BUILD_DIR}/{godot_path_mac}/Contents/MacOS/Godot")
    else:
        raise RuntimeError("Unsupported platform!")

    if file_path.exists():
        file_path.chmod(file_path.stat().st_mode | stat.S_IEXEC)
        path = which(file_path.as_posix())
        if path != None:
            return path

    raise RuntimeError(f"Could not find godot in {file_path}!")


def find_command_or_exit(cmd: str) -> str:
    path: str | None = which(cmd)
    if path != None:
        println(f"Found {cmd}! ({path})")
        return path
    else:
        printerr(f"Could not find {cmd}!")
        sys.exit(1)


def which(path: str) -> str | None:
    return shutil.which(path)


def exec_and_capture(
    command: str,
    cwd: str | None = None,
    env: None = None,
    *,
    capture_output: bool = False,
):
    old_cwd = os.getcwd()
    if cwd:
        printinfo(f"cd {cwd}")
        os.chdir(cwd)

    printinfo(command)

    # args = shlex.split(command)
    result = subprocess.run(
        command,
        shell=True,
        check=True,
        text=True,
        env=env,
        capture_output=capture_output,
    )

    returncode = result.returncode

    if returncode != 0:
        # if result and result.stderr:
        #     print(result.stderr.decode())
        print()
        raise RuntimeError(
            f'Command "{command}" returned non-zero exit status: {returncode}'
        )

    # restore working directory
    if cwd:
        printinfo(f"cd {old_cwd}")
        os.chdir(old_cwd)

    return result


def exec(command: str, cwd: str | None = None, env: None = None) -> None:
    _ = exec_and_capture(command, cwd, env, capture_output=False)


def copy_to_build_dir(file_path: str, subfolder: str = "") -> None:
    build_path = Path(BUILD_DIR) / subfolder
    build_path.mkdir(parents=True, exist_ok=True)

    file_name = Path(file_path).name
    dest_path = (build_path / file_name).as_posix()

    copy(file_path, dest_path)

    # file_dir = Path(file_path).parent
    # _println("Files in directory %s:" % file_dir)
    # for file in [f for f in Path(file_dir).iterdir() if f.is_file()]:
    #     _println("- %s" % file.name)


def copy(file_path: str, dest_path: str) -> None:
    Path(dest_path).parent.mkdir(parents=True, exist_ok=True)
    _ = shutil.copy(file_path, dest_path)
    println(f"Copied {file_path} to {dest_path}")


def move(file_path: str, dest_path: str) -> None:
    Path(dest_path).parent.mkdir(parents=True, exist_ok=True)
    _ = shutil.move(file_path, dest_path)
    println(f"Moved {file_path} to {dest_path}")


def exec_cargo_build(
    build_target: str,
    is_release: bool,
    platform: str,
    cargo_targets: list[str],
) -> None:
    cwd = "rust"
    cargo = find_command_or_exit("cargo")
    rustup = find_command_or_exit("rustup")
    release_or_debug = "release" if is_release else "debug"
    cargo_flags = ""

    if is_release:
        cargo_flags += "--release "

    cargo_flags += f"{TARGET_FLAGS[build_target]} "

    is_lib: bool = cargo_flags.find("--lib") != -1

    print(f"cargo path: {cargo}")

    exec("cargo --version")
    exec("rustup --version")

    for target in cargo_targets:
        exec(f"rustup target add {target}")
        exec(f"cargo build {cargo_flags} --target {target}", cwd)

    match platform:
        case "macos":
            if is_lib:
                filename = f"lib{LIB_NAME}.dylib"
            else:
                filename = f"{LIB_NAME}"

            println("Creating universal binary for macOS...")
            file_x86 = f"{cwd}/target/x86_64-apple-darwin/{release_or_debug}/{filename}"
            file_arm = (
                f"{cwd}/target/aarch64-apple-darwin/{release_or_debug}/{filename}"
            )
            file_uni = f"{cwd}/target/{release_or_debug}/{filename}"
            exec(f"lipo -create {file_x86} {file_arm} -output {file_uni}")

            if is_lib:
                move(file_uni, f"godot/addons/libm8/{release_or_debug}/{filename}")
            else:
                copy_to_build_dir(file_uni, "cli")

        case "windows":
            if is_lib:
                filename = f"{LIB_NAME}.dll"
            else:
                filename = f"{LIB_NAME}.exe"

            filepath = (
                f"{cwd}/target/x86_64-pc-windows-gnu/{release_or_debug}/{filename}"
            )

            if is_lib:
                copy(filepath, f"{cwd}/target/{release_or_debug}/{filename}")
                move(filepath, f"godot/addons/libm8/{release_or_debug}/{filename}")
            else:
                copy_to_build_dir(filepath, "cli")

        case "linux":
            if is_lib:
                filename = f"lib{LIB_NAME}.so"
            else:
                filename = f"{LIB_NAME}"

            filepath = (
                f"{cwd}/target/x86_64-unknown-linux-gnu/{release_or_debug}/{filename}"
            )

            if is_lib:
                copy(filepath, f"{cwd}/target/{release_or_debug}/{filename}")
                move(filepath, f"godot/addons/libm8/{release_or_debug}/{filename}")
            else:
                copy_to_build_dir(filepath, "cli")

        case _:
            raise RuntimeError(f"Unsupported platform: {platform}")


def download_zip(url: str, dest_dir: str) -> None:
    println(f"Downloading {url}...")
    ssl._create_default_https_context = ssl._create_unverified_context
    res = urllib.request.urlretrieve(url)
    with zipfile.ZipFile(res[0], "r") as zip:
        zip.extractall(dest_dir)
        println(f"Extracted zip to {dest_dir}...")


def get_platform(p: str) -> Platform:
    p = p.lower()
    if p == "":
        p = platform.system().lower()
    if p == "darwin":
        p = "macos"
    match p:
        case "windows":
            return "windows"
        case "linux":
            return "linux"
        case "macos":
            return "macos"
        case _:
            printerr(f"Unsupported platform: {p}")
            sys.exit(1)


if __name__ == "__main__":
    try:
        main()
        sys.exit(0)
    except RuntimeError as e:
        printerr(f"{_BOLD_}RuntimeError{_RESET_}: {e}")
        sys.exit(1)
