#!/usr/bin/env python
import subprocess

ADDON_DIR = "project/addons/libm8gd"
TARGET_LIB = "libm8gd"

env = SConscript("thirdparty/godot-cpp/SConstruct")


def call(*args) -> str:
    return subprocess.run(args, capture_output=True).stdout.decode().strip()


def call_split(*args) -> list[str]:
    return call(*args).split(" ")


USING_OSXCROSS: bool = "osxcross_sdk" in env

if USING_OSXCROSS:
    if env["arch"] == "universal":
        print("OSXCross does not support universal builds.")
        Exit(255)
    else:
        print("using OSXCross SDK: %s" % env["osxcross_sdk"])

PKG_CONFIG: str
if env["platform"] == "macos" and USING_OSXCROSS:
    PKG_CONFIG = "x86_64-apple-%s-pkg-config" % env["osxcross_sdk"]
else:
    PKG_CONFIG = "pkg-config"


CFLAGS = call_split(PKG_CONFIG, "--cflags", "libserialport")

print("using pkg-config: %s" % PKG_CONFIG)
print("using cxx: %s" % env["CXX"])

# add sources
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

# set flags
if env["target"] == "template_release":
    env.Append(CFLAGS=["-O2"])

env.Append(CFLAGS=["-Wall", "-pipe"])
env.Append(CFLAGS=CFLAGS)

print("architecture: %s" % env["arch"])

if USING_OSXCROSS:
    # explicitly link the static library
    LIB_FILE = (
        call(PKG_CONFIG, "--variable=libdir", "libserialport") + "/libserialport.a"
    )
    print("library path: %s" % LIB_FILE)
    env.Append(LIBS=File(LIB_FILE))
else:
    LIBPATH = call_split(PKG_CONFIG, "--libs-only-L", "--static", "libserialport")
    LIBS = call_split(PKG_CONFIG, "--libs-only-l", "--static", "libserialport")

    print("library paths: %s" % LIBPATH)
    print("library flags: %s" % LIBS)

    env.Append(LIBPATH=LIBPATH)
    env.Append(LIBS=LIBS)

# create library target
if env["platform"] == "macos":

    env.Append(CCFLAGS=CFLAGS)

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
