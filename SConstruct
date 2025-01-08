#!/usr/bin/env python
import os
from glob import glob
from pathlib import Path

env = SConscript("thirdparty/godot-cpp/SConstruct")

# add sources
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

# link libserialport (statically)
env.Append(CPPPATH=["thirdparty/libserialport"])
env.Append(LIBS=File("thirdparty/libserialport/.libs/libserialport.a"))
if env["platform"] == "windows":
    env.Append(LIBS=["setupapi"])

# # find pkg-config command
# if env["platform"] == "macos" and "OSXCROSS_ROOT" in os.environ:
#     pkg_config = "x86_64-apple-%s-pkg-config" % env["osxcross_sdk"]
# else:
#     pkg_config = "pkg-config"

# # link libserialport (shared)
# env.ParseConfig(f"{pkg_config} libserialport --cflags --libs --static")

# find extension path
(extension_path,) = glob("project/addons/*/*.gdextension")
addon_path = Path(extension_path).parent
project_name = Path(extension_path).stem

# scons cache
scons_cache_path = os.environ.get("SCONS_CACHE")
if scons_cache_path:
    CacheDir(scons_cache_path)
else:
    CacheDir(".scons_cache/%s_%s_%s" % (env["platform"], env["arch"], env["target"]))

# create library target
debug_or_release = "release" if env["target"] == "template_release" else "debug"
if env["platform"] == "macos":
    library = env.SharedLibrary(
        "{0}/bin/{1}.{2}.{3}.framework/{1}.{2}.{3}".format(
            addon_path, project_name, env["platform"], debug_or_release
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "{}/bin/{}.{}.{}.{}{}".format(
            addon_path,
            project_name,
            env["platform"],
            debug_or_release,
            env["arch"],
            env["SHLIBSUFFIX"],
        ),
        source=sources,
    )

Default(library)
