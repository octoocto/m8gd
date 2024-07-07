#!/usr/bin/env python
import subprocess


def call(*args) -> str:
    return subprocess.run(args, capture_output=True).stdout.decode().strip()


def call_split(*args) -> list[str]:
    return call(*args).split(" ")


ADDON_DIR = "project/addons/libm8gd"
TARGET_LIB = "libm8gd"

env = SConscript("thirdparty/godot-cpp/SConstruct")

PKG_CONFIG = "pkg-config"

if env["platform"] == "macos" and "osxcross_sdk" in env:
    PKG_CONFIG = "x86_64-apple-%s-pkg-config" % env["osxcross_sdk"]

print("using pkg-config: %s" % PKG_CONFIG)
print("using cxx: %s" % env["CXX"])

# find libserialport flags
# PKG_CONFIG_LIBS = []
# PKG_CONFIG_LIBPATH = []

# PKG_CONFIG_LIBFLAGS = (
#     call(PKG_CONFIG, "--libs", "--static", "libserialport")
#     .replace("-mwindows", "")
#     .replace("-pthread", "")
#     .split(" ")
# )

# for flag in PKG_CONFIG_LIBFLAGS:
#     if flag[:2] == "-L":
#         PKG_CONFIG_LIBPATH.append(flag)
#     if flag[:2] == "-l":
#         PKG_CONFIG_LIBS.append(flag + ".a")

CFLAGS = call_split(PKG_CONFIG, "--cflags", "libserialport")

# add sources
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

# set flags
if env["target"] == "template_release":
    env.Append(CFLAGS=["-O2"])

env.Append(CFLAGS=["-Wall", "-pipe"])
env.Append(CFLAGS=CFLAGS)


# create library target
if env["platform"] == "macos":

    LIB_FILE = (
        call(PKG_CONFIG, "--variable=libdir", "libserialport") + "/libserialport.a"
    )
    print("library path: %s" % LIB_FILE)
    env.Append(LIBS=File(LIB_FILE))
    env.Append(CCFLAGS=CFLAGS)

    library = env.SharedLibrary(
        target="%s/%s.%s.%s.framework"
        % (ADDON_DIR, TARGET_LIB, env["platform"], env["target"]),
        source=sources,
    )

else:

    LIBPATH = call_split(PKG_CONFIG, "--libs-only-L", "--static", "libserialport")
    LIBS = call_split(PKG_CONFIG, "--libs-only-l", "--static", "libserialport")

    print("library paths: %s" % LIBPATH)
    print("library flags: %s" % LIBS)

    env.Append(LIBPATH=LIBPATH)
    env.Append(LIBS=LIBS)

    library = env.SharedLibrary(
        target="%s/%s.%s.%s%s"
        % (ADDON_DIR, TARGET_LIB, env["platform"], env["target"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)
