#!/usr/bin/env python3
from pathlib import Path
import shutil
import os


platforms = ["windows", "linux", "macos"]



# copy src into a temporary directory, ignoring indev .so and .dll files
shutil.rmtree("build", ignore_errors=True)
Path("build").mkdir()
shutil.copytree("src", "build/src", ignore=shutil.ignore_patterns("*.so", "*.dll"))

# create .love file
shutil.make_archive("build/newlestehorn", "zip", "build/src")
os.rename("build/newlestehorn.zip", "build/newlestehorn.love")

# copy files
for platform in platforms:
    print(f"[{platform}]")
    
    Path(f"build/{platform}").mkdir()
    
    if platform == "windows":
        # copy love2d files
        shutil.copytree("bin/windows/love", "build/windows", 
            ignore=shutil.ignore_patterns("*.exe"),
            dirs_exist_ok=True)
        
        # copy libraries
        for dll in ["nuklear.dll", "nfd.dll"]:
            shutil.copy(f"bin/windows/{dll}", "build/windows")
        
        # concatenate love.exe and newlestehorn.love
        filenames = ["bin/windows/love/love.exe", "build/newlestehorn.love"]
        with open("build/windows/newlestehorn.exe", "wb") as of:
            for fn in filenames:
                with open(fn, "rb") as inf:
                        of.write(inf.read())
    elif platform == "linux":
        # linux - no fancy packaging, just src and .so's
        # copy src
        shutil.copytree("build/src", f"build/{platform}", dirs_exist_ok=True)
        
        # copy .so's
        for so in ["nuklear.so", "nfd.so"]:
            shutil.copy(f"bin/{platform}/{so}", f"build/{platform}")
    elif platform == "macos":
        # macos - no fancy packaging, just src and .so's
        # copy src
        shutil.copytree("build/src", f"build/{platform}", dirs_exist_ok=True)
        
        # copy .so and .py
        # python file used as a hack for file dialog for macos
        # since i couldn't compile nfd
        for so in ["nuklear.so", "filedialog.py"]:
            shutil.copy(f"bin/{platform}/{so}", f"build/{platform}")

# create archives    
version = input("version suffix: ")
for platform in platforms:
    arcname = f"newlestehorn-{version}-{platform}"
    os.rename(f"build/{platform}", f"build/{arcname}")
    
    fmt = "zip" if platform == "windows" else "gztar"
    shutil.make_archive(f"build/{arcname}", fmt, "build", arcname)

print("done")
