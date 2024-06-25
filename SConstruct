#!/usr/bin/env python
import subprocess

ADDON_DIR = "project/addons/libm8gd"
TARGET_LIB = "libm8gd"

env = SConscript("thirdparty/godot-cpp/SConstruct")

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

sources = Glob("src/*.cpp")

if env["target"] == "template_release":
    env.Append(CFLAGS=["-O2"])

env.Append(CFLAGS=["-Wall", "-pipe"])
env.Append(CFLAGS=PKG_CONFIG_CFLAGS)

env.Append(CPPPATH=["src", "thirdparty"])

env.Append(LIBPATH=["thirdparty/godot-cpp/bin", "bin", "/mingw64/lib"])

LIBFLAGS = PKG_CONFIG_LIBFLAGS
LIBFLAGS += ["libgodot-cpp.%s.%s.x86_64" % (env["platform"], env["target"])]

library = env.SharedLibrary(
    target="%s/%s.%s.%s%s"
    % (ADDON_DIR, TARGET_LIB, env["platform"], env["target"], env["SHLIBSUFFIX"]),
    source=sources,
    LIBS=LIBFLAGS,
)
Default(library)
