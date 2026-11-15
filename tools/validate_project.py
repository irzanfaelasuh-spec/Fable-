#!/usr/bin/env python3
"""Lightweight repository sanity checks; does not replace the Godot editor/compiler."""
from pathlib import Path
import configparser
import json
import re
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
errors = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

# Required core files.
required = [
    "project.godot", "export_presets.cfg", "scenes/main.tscn",
    "scripts/main.gd", "scripts/network_client.gd", "scripts/player.gd",
    "scripts/remote_player.gd", "scripts/world.gd", "scripts/virtual_joystick.gd", "scripts/item_drop.gd",
    "server/index.js", "server/storage.js", "server/package.json",
    ".github/workflows/build-android.yml", ".github/workflows/server-check.yml",
]
for rel in required:
    require((ROOT / rel).is_file(), f"Missing required file: {rel}")

# Verify local Godot resource references.
for path in list((ROOT / "scripts").glob("*.gd")) + list((ROOT / "scenes").glob("*.tscn")):
    source = path.read_text(encoding="utf-8")
    for resource in re.findall(r'res://([^"\']+)', source):
        require((ROOT / resource).exists(), f"Broken resource path in {path.relative_to(ROOT)}: res://{resource}")

# Verify project main scene and vector icon exist.
project = (ROOT / "project.godot").read_text(encoding="utf-8")
scene_match = re.search(r'^run/main_scene="res://([^\"]+)"', project, re.M)
icon_match = re.search(r'^config/icon="res://([^\"]+)"', project, re.M)
require(bool(scene_match), "project.godot is missing run/main_scene")
require(bool(icon_match), "project.godot is missing config/icon")
if scene_match:
    require((ROOT / scene_match.group(1)).is_file(), f"Main scene missing: {scene_match.group(1)}")
if icon_match:
    require((ROOT / icon_match.group(1)).is_file(), f"Project icon missing: {icon_match.group(1)}")

# Verify Android preset icons and their documented dimensions.
export_config = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
icon_specs = {
    "launcher_icons/main_192x192": ("assets/icon-main-192.png", (192, 192)),
    "launcher_icons/adaptive_foreground_432x432": ("assets/icon-adaptive-foreground-432.png", (432, 432)),
    "launcher_icons/adaptive_background_432x432": ("assets/icon-adaptive-background-432.png", (432, 432)),
    "launcher_icons/adaptive_monochrome_432x432": ("assets/icon-adaptive-monochrome-432.png", (432, 432)),
}
for key, (rel, expected_size) in icon_specs.items():
    require(key in export_config, f"Android preset missing {key}")
    image_path = ROOT / rel
    require(image_path.is_file(), f"Missing Android icon: {rel}")
    if image_path.is_file():
        with Image.open(image_path) as image_file:
            require(image_file.size == expected_size, f"Wrong dimensions for {rel}: {image_file.size}")

# Validate server package JSON and project orientation declaration.
try:
    package = json.loads((ROOT / "server/package.json").read_text(encoding="utf-8"))
    require(package.get("engines", {}).get("node", "").startswith(">=22"), "Server should target Node.js 22+")
    require("ws" in package.get("dependencies", {}), "Missing ws dependency")
    require("pg" in package.get("dependencies", {}), "Missing pg dependency")
except Exception as exc:
    errors.append(f"Invalid server/package.json: {exc}")

require("window/handheld/orientation=0" in project, "Android landscape orientation setting missing")
require('DisplayServer.SCREEN_LANDSCAPE' in (ROOT / "scripts/main.gd").read_text(encoding="utf-8"), "Runtime landscape lock missing")

if errors:
    print("FABLEBRINK validation FAILED")
    for item in errors:
        print(f" - {item}")
    sys.exit(1)

print("FABLEBRINK repository sanity checks passed.")
print("Note: run the Godot 4.7.2 editor/build workflow to verify GDScript parsing and Android export.")
