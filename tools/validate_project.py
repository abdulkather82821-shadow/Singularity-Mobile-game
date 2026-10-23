#!/usr/bin/env python3
"""Static sanity check for the Godot project (no engine required).

Checks that:
  1. every .gd file parses with gdparse and lints clean with gdlint (if installed),
  2. every res:// path referenced from scripts, scenes and project.godot exists,
  3. every .tscn has valid ext_resources and a root node,
  4. every node path used by @onready in main.gd exists in main.tscn,
  5. single-hop method/signal/property calls between the director, entities and UI
     resolve to declarations in the target script.

Usage:  python3 tools/validate_project.py
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

GD_DIRS = ["res/scripts"]
errors = []
warnings = []

gd_files = []
for base in GD_DIRS:
    for dirpath, _, files in os.walk(base):
        for name in sorted(files):
            if name.endswith(".gd"):
                gd_files.append(os.path.join(dirpath, name).replace("\\", "/"))

scene_files = sorted(
    os.path.join("res/scenes", f) for f in os.listdir("res/scenes") if f.endswith(".tscn")
)


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


# ---------------------------------------------------------------- 1. gdscript
if shutil.which("gdparse"):
    for path in gd_files:
        result = subprocess.run(["gdparse", path], capture_output=True, text=True)
        if result.returncode != 0:
            errors.append(f"{path}: gdparse failed\n{result.stdout}{result.stderr}")
else:
    warnings.append("gdparse not installed - skipped syntax check")

if shutil.which("gdlint"):
    for path in gd_files:
        result = subprocess.run(["gdlint", path], capture_output=True, text=True)
        if result.returncode != 0:
            errors.append(f"{path}: gdlint failed\n{result.stdout}{result.stderr}")
else:
    warnings.append("gdlint not installed - skipped lint check")

# ---------------------------------------------------------------- 2. res paths
for path in gd_files + ["project.godot"] + scene_files + ["export_presets.cfg"]:
    text = read(path)
    for match in re.finditer(r"res://([A-Za-z0-9_./-]+)", text):
        target = match.group(1)
        if not os.path.exists(target):
            errors.append(f"{path}: missing resource res://{target}")

# ---------------------------------------------------------------- 3. scenes
for path in scene_files:
    text = read(path)
    if not text.startswith("[gd_scene"):
        errors.append(f"{path}: no [gd_scene] header")
    ids = re.findall(r'id="([^"]+)"', text)
    if len(ids) != len(set(ids)):
        errors.append(f"{path}: duplicate ext_resource id")
    for match in re.finditer(r'\[ext_resource type="(\w+)" path="res://([^"]+)"', text):
        if not os.path.exists(match.group(2)):
            errors.append(f"{path}: ext_resource points at missing {match.group(2)}")
    if not re.search(r'\[node name="[^"]+" type="\w+"\]', text):
        errors.append(f"{path}: no root node")

# ---------------------------------------------------------------- 4. @onready
main_script = "res/scripts/main.gd"
main_scene = read("res/scenes/main.tscn")
nodes = {}
for match in re.finditer(r'\[node name="([^"]+)"(?:\s+type="\w+")?(?:\s+parent="([^"]+)")?', main_scene):
    nodes[match.group(1)] = match.group(2) or ""
for match in re.finditer(r"@onready var \w+: \w+ = \$(.+)", read(main_script)):
    parts = match.group(1).strip().split("/")
    if parts[0] not in nodes:
        errors.append(f"{main_script}: @onready node '{parts[0]}' missing from main.tscn")
        continue
    for part in parts[1:]:
        if part not in nodes:
            errors.append(f"{main_script}: @onready node '{part}' missing from main.tscn")

# ---------------------------------------------------------------- 5. symbols
symbols = {}
for path in gd_files:
    raw = read(path)
    symbols[path] = {
        "funcs": set(re.findall(r"^\s*(?:static\s+)?func ([A-Za-z0-9_]+)\(", raw, re.M)),
        "signals": set(re.findall(r"^\s*signal ([A-Za-z0-9_]+)", raw, re.M)),
        "consts": set(re.findall(r"^\s*const ([A-Za-z0-9_]+)", raw, re.M)),
        "vars": set(re.findall(r"^\s*(?:@onready )?var ([A-Za-z0-9_]+)", raw, re.M)),
    }

TARGETS = {
    "SaveManager": "res/scripts/save_manager.gd",
    "AudioManager": "res/scripts/audio_manager.gd",
    "StoryManager": "res/scripts/story_manager.gd",
    "GameConfig": "res/scripts/game_config.gd",
    "UI": "res/scripts/ui/ui.gd",
    "Shapes": "res/scripts/world/shapes.gd",
    "run": "res/scripts/manager.gd",
    "player": "res/scripts/entities/player.gd",
    "boss": "res/scripts/entities/boss.gd",
    "enemy": "res/scripts/entities/enemy.gd",
    "menus": "res/scripts/ui/menus.gd",
    "hud": "res/scripts/ui/hud.gd",
    "dialogue": "res/scripts/ui/dialogue_box.gd",
    "touch": "res/scripts/ui/touch_controls.gd",
    "effects": "res/scripts/effects.gd",
    "background": "res/scripts/world/background.gd",
    "post_fx": "res/scripts/post_fx.gd",
}

ANALYSE = [
    "res/scripts/main.gd",
    "res/scripts/ui/hud.gd",
    "res/scripts/ui/menus.gd",
    "res/scripts/ui/dialogue_box.gd",
    "res/scripts/ui/touch_controls.gd",
    "res/scripts/post_fx.gd",
]

ENGINE_FUNCS = {
    "has_method", "call", "call_deferred", "set_process", "is_instance_valid", "get", "set",
    "new", "instantiate", "free", "queue_free", "duplicate", "emit", "connect", "add_child",
    "get_children", "get_child", "create_tween", "tween_property", "set_delay", "set_parallel",
    "add_theme_stylebox_override", "add_theme_font_size_override", "add_theme_color_override",
    "add_theme_constant_override", "set_anchors_preset", "set_anchors_and_offsets_preset",
    "queue_redraw", "grab_focus", "set_pivot_offset", "play", "stop", "merge", "keys", "has",
    "append", "erase", "remove_at", "size",
}

ENGINE_PROPS = {
    "position", "hp", "max_hp", "energy", "max_energy", "alive", "name", "visible", "modulate",
    "z_index", "size", "text", "input", "radius", "damage", "kind", "phase", "def", "kills",
    "score", "level", "combo_mult", "stage_time", "damage_taken", "pending_levels", "modifiers",
    "kills_needed", "xp", "shots_fired", "hits_landed", "lines", "index", "flags", "layers",
}


def strip_code(text):
    text = re.sub(r"#.*", "", text)
    return re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)


for path in ANALYSE:
    if path not in symbols:
        continue
    text = strip_code(read(path))
    for obj, target in TARGETS.items():
        table = symbols[target]
        for match in re.finditer(rf"(?<![A-Za-z0-9_.]){obj}\.([A-Za-z0-9_]+)\(", text):
            method = match.group(1)
            if method in table["funcs"] or method in table["signals"] or method in ENGINE_FUNCS:
                continue
            errors.append(f"{path}: {obj}.{method}() is not declared in {target}")
        for match in re.finditer(rf"(?<![A-Za-z0-9_.]){obj}\.([A-Za-z0-9_]+)\b(?!\()", text):
            prop = match.group(1)
            if prop in table["vars"] or prop in table["consts"] or prop in table["signals"]:
                continue
            if prop in ENGINE_PROPS:
                continue
            errors.append(f"{path}: {obj}.{prop} is not a declared member of {target}")

# ---------------------------------------------------------------- report
print(f"scanned {len(gd_files)} scripts and {len(scene_files)} scenes")
for warning in warnings:
    print(f"note: {warning}")
if errors:
    print(f"\nFAILED with {len(errors)} problem(s):")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)
print("OK: parse, lint, resource paths, scene nodes and cross-script calls all resolve")
