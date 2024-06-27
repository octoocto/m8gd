#!/usr/bin/env python
import subprocess

ADDON_DIR = "project/addons/libm8gd"
TARGET_LIB = "libm8gd"

env = SConscript("thirdparty/godot-cpp/SConstruct")

# find libserialport flags
PKG_CONFIG_LIBFLAGS = (
    subprocess.run(
        ["pkg-config", "--libs", "--static", "libserialport"],
        capture_output=True,
    )
    .stdout.decode()
    .removesuffix("\n")
    .replace("-mwindows", "")
    .replace("-pthread", "")
    .split(" ")
)

PKG_CONFIG_CFLAGS = (
    subprocess.run(
        ["pkg-config", "--cflags", "libserialport"],
        capture_output=True,
    )
    .stdout.decode()
    .removesuffix("\n")
    .split(" ")
)

# add sources
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

# set flags
if env["target"] == "template_release":
    env.Append(CFLAGS=["-O2"])

env.Append(CFLAGS=["-Wall", "-pipe"])
env.Append(CFLAGS=PKG_CONFIG_CFLAGS)

env.Append(LIBS=PKG_CONFIG_LIBFLAGS)

# create library target
if env["platform"] == "macos":
    library = env.SharedLibrary(
        target="%s/%s.%s.%s.framework"
        % (ADDON_DIR, TARGET_LIB, env["platform"], env["target"]),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        target="%s/%s.%s.%s%s"
        % (ADDON_DIR, TARGET_LIB, env["platform"], env["target"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)
