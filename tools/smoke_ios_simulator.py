#!/usr/bin/env python3
"""Launch the compiled app in an available iPhone Simulator and capture evidence."""
import json
import os
import pathlib
import subprocess
import time


def run(*args):
    print("Running:", " ".join(args), flush=True)
    return subprocess.check_output(args, text=True, timeout=300)


output = pathlib.Path("build/ios")
app = (output / "simulator/Build/Products/Release-iphonesimulator/PhreakNICCCG.app").resolve()
if not (app / "PhreakNICCCG").is_file():
    raise RuntimeError("Simulator executable missing; build the Simulator app successfully first")
devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))
device = next(
    d for runtime, entries in sorted(devices["devices"].items(), reverse=True) if "iOS" in runtime
    for d in entries if d["name"].startswith("iPhone") and d["isAvailable"]
)
udid = device["udid"]
print("Testing on", device["name"], udid, flush=True)
if device["state"] != "Booted":
    run("xcrun", "simctl", "boot", udid)
run("xcrun", "simctl", "bootstatus", udid, "-b")
print(run("file", str(app / "PhreakNICCCG")), flush=True)
print(run("xcrun", "vtool", "-show-build", str(app / "PhreakNICCCG")), flush=True)
run("xcrun", "simctl", "install", udid, str(app))
launch = run("xcrun", "simctl", "launch", "--terminate-running-process", udid, "com.nirtom84.phreakniccg")
(output / "simulator.log").write_text(launch)
print(launch, flush=True)
pid = int(launch.strip().rsplit(":", 1)[1])
time.sleep(15)
# Simulator applications are host processes. Check the app PID, rather than the simctl client.
os.kill(pid, 0)
command = run("ps", "-p", str(pid), "-o", "command=")
if "PhreakNICCCG.app/PhreakNICCCG" not in command:
    raise RuntimeError("The launched PID does not identify the game executable")
run("xcrun", "simctl", "io", udid, "screenshot", str(output / "simulator.png"))
os.kill(pid, 0)
print("Game process stayed running; screenshot captured.")
