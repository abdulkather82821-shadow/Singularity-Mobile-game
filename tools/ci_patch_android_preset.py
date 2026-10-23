#!/usr/bin/env python3
"""CI helper: aim the Android preset's debug keystore at a generated file.

Godot's headless exporter reads the keystore from the export preset (or from
Editor Settings). CI has no editor settings, so the preset is patched in place
inside the throwaway checkout.

Usage: python3 tools/ci_patch_android_preset.py /path/to/debug.keystore
"""
from __future__ import annotations

import pathlib
import sys

VALUES = {
    "keystore/debug": "",
    "keystore/debug_user": "androiddebugkey",
    "keystore/debug_password": "android",
}


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: ci_patch_android_preset.py <keystore path>", file=sys.stderr)
        return 2
    keystore = pathlib.Path(sys.argv[1]).expanduser().resolve()
    if not keystore.is_file():
        print(f"error: keystore not found: {keystore}", file=sys.stderr)
        return 1
    VALUES["keystore/debug"] = str(keystore)
    preset = pathlib.Path(__file__).resolve().parent.parent / "export_presets.cfg"
    lines = preset.read_text(encoding="utf-8").splitlines()
    patched = set()
    out = []
    for line in lines:
        for key, value in VALUES.items():
            if line.startswith(key + "="):
                line = f'{key}="{value}"'
                patched.add(key)
                break
        out.append(line)
    preset.write_text("\n".join(out) + "\n", encoding="utf-8")
    missing = set(VALUES) - patched
    if missing:
        print(f"warning: options not present in preset: {sorted(missing)}", file=sys.stderr)
    print(f"patched debug keystore -> {keystore}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
