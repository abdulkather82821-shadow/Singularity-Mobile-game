# SINGULARITY — Vessel of the Fallen

A **3D anime action-RPG** built in **Godot 4.3** from the design deck: third-person
combat in a real 3D arena, a cast of procedural low-poly characters, three stages,
a multi-phase boss and three endings.

> "It all started at PMIST. The day the sky cracked."

---

## 1. Download the game

Both binaries are built by CI from this branch and attached to the rolling release:

| Platform | File | Size | Link |
|---|---|---|---|
| Windows (x86-64) | `SINGULARITY.exe` | ~85 MB | <https://github.com/abdulkather82821-shadow/Singularity-Mobile-game/releases/download/latest-build/SINGULARITY.exe> |
| Android (arm64-v8a) | `SINGULARITY.apk` | ~27 MB | <https://github.com/abdulkather82821-shadow/Singularity-Mobile-game/releases/download/latest-build/SINGULARITY.apk> |

Release page: <https://github.com/abdulkather82821-shadow/Singularity-Mobile-game/releases/tag/latest-build>
Screenshots rendered from the real build are attached to every CI run as the
`SINGULARITY-screenshots` artifact.

- **Windows:** run the `.exe` directly — the PCK is embedded, no install needed.
- **Android:** copy the APK to the phone and tap it; allow "install unknown apps"
  for your file manager. It is debug-signed, offline, and needs Android 6+.

---

## 2. Story in one paragraph

Ajees is an ordinary PMIST student until the sky splits and Katleen — a dimensional
invader wearing a crown of glass — starts folding his campus into her realm. Guided
by Sara, backed by Bala, Manmohan, Gokul and Prince, and carrying a vessel of rift
power he does not understand, he fights through the courtyard, the fractured rift
and Katleen's throne. Three crossroads decisions and three endings decide whether he
seals the rift, rules it, or walks away from it.

---

## 3. Controls

| Action | Keyboard / mouse | Touch |
|---|---|---|
| Move | `W A S D` / arrows | left thumbstick |
| Melee chain (3 hits) | `J` / left click | **A** |
| Rift shot | `K` / right click | **B** |
| Class special | `L` | **S** |
| Dash (i-frames) | `Shift` | **D** |
| Jump | `Space` | — |
| Mend (after upgrade) | `H` | **H** |
| **Ultimate** (when the meter is full) | `Q` | **U** |
| **Switch class** | `1` `2` `3`, or `Tab` to cycle | **C** |
| Pause | `Esc` / `P` | **II** |

### The power system — three classes, twelve abilities

The deck's "melee, magic, ultimate, healing defence" is a real class system. Switch
mid-run (there is a short settle cooldown) and Ajees's 3D model, weapon and colours
change with the class:

| Class | Melee | Shot | Special | Ultimate |
|---|---|---|---|---|
| **VESSEL** (balanced) | 16 / 16 / 27 | 1 bolt, 13 dmg | Singularity Burst — radial | Vessel Unbound — big AoE |
| **BLADE** (melee) | 20 / 20 / 36, faster | weak quick bolt | Blade Rush — fast, tight burst | Thousand Cuts |
| **CASTER** (ranged) | 11 / 11 / 17 | 3-bolt spread, 17 dmg | Rift Storm — wide | Singularity Rain |

Hits charge the **ultimate meter**; kills charge it faster. Level-ups (7 upgrade
tracks) stack on top: Rift Edge, Vessel Current, Mend, Phase Step, Second Heart,
Singularity Core and Rift Flux.

---

## 4. What is in a run

- **Stage 1 — The Awakening** (PMIST campus at dusk): 12 wraiths in a 3D courtyard
  with buildings, lamps, trees and benches.
- **Stage 2 — The Dimensional Rift**: the campus tears open — floating slabs,
  monoliths, a rift tear and burning ground hazards.
- **Stage 3 — Katleen's Realm**: glass throne, pillars, hanging shards. Katleen
  telegraphs five attacks (blast, dash, nova, barrage, summon) and transforms at
  half health with a full phase-two dialogue beat.
- **Story**: dialogue with typewriter pacing, three crossroads (path / allies /
  resolve) that change damage, health, Mend and Sara, checkpoints between stages,
  and three endings (`seal`, `sovereign`, `dawn`).
- **Feel**: hit-stop, slow-motion ultimates, camera shake, bloom, fog, damage
  numbers, 3D ember bursts, ground rings, slash arcs.

---

## 5. Project layout (deck page 12)

```
res/
  models/            docs only — every mesh is generated in code
  textures/          vignette, grain, scanline, glow (2D UI overlays)
  audio/             27 generated WAVs (music + SFX)
  scenes/            main, arena, player, enemy, boss, projectile, pickup,
                     hazard, effects, hud, menus, dialogue, touch_controls, post_fx
  assets/            notes on external assets
res/scripts/
  main.gd            campaign director: stages, story, combat resolution, endings
  game_config.gd     3D tuning, classes, upgrades, stage tables (central CONFIG)
  manager.gd         RunState: score, combo, XP/levels, upgrades, class state
  save_manager.gd    settings, records, checkpoint, endings
  audio_manager.gd   music + SFX pools
  story_manager.gd   dialogue lines, crossroads, endings, typewriter
  effects.gd         3D particles, rings, slashes, damage numbers
  post_fx.gd         screen-space vignette, grain, flash
  entities/          player.gd, enemy.gd, boss.gd, projectile.gd, pickup.gd, hazard.gd
  world/             arena.gd, rig3d.gd, camera_rig.gd, shapes.gd
  ui/                hud.gd, menus.gd, dialogue_box.gd, touch_controls.gd, ui.gd
tools/
  validate_project.py  static check: gdparse + gdlint + res:// paths + scene nodes
  export.sh            local export helper (apk | exe | all)
  generate_audio.py    regenerates the WAV set
  generate_textures.py regenerates the UI overlays
```

### How the 3D is built without asset files

There are no `.glb`/`.blend` files in the project — every model is constructed at
runtime:

- `world/rig3d.gd` builds a low-poly anime figure from boxes, spheres, capsules,
  cylinders and prisms, with an inverted-hull toon outline, and poses it for idle,
  run, attack, cast, hurt and death.
- `world/arena.gd` builds each stage from primitives: buildings with lit windows,
  lamp posts with real omni lights, trees, benches, floating rift slabs, glass
  pillars, a throne dais, plus per-stage sky, fog and lighting.
- `world/camera_rig.gd` is the third-person camera: smooth follow, impact shake and
  cinematic orbits for stage intros.
- `entities/*.gd` build their own meshes (wraiths with hoods and glowing eyes,
  Katleen with crown, cape, staff and orbiting shards, projectiles, pickups, hazards).

---

## 6. Character art

| Character | Role | In game |
|---|---|---|
| Ajees | protagonist | player rig, colour and weapon follow the active class |
| Sara | love interest / ally | follows Ajees and fires support shots once the *allies* crossroad is taken |
| Katleen | antagonist | boss rig with crown, cape, staff, shards and a phase-two recolour |
| Bala, Manmohan, Gokul, Prince | supporting cast | named in dialogue, crossroads and endings |

All characters are original, stylized low-poly interpretations built from primitives
— no copyrighted character art is used.

---

## 7. Building the binaries yourself

### Option A — script (local)

```bash
# Godot 4.3+ as `godot` on PATH, or set GODOT=/path/to/godot
./tools/export.sh exe     # build/windows/SINGULARITY.exe
./tools/export.sh apk     # build/android/SINGULARITY.apk
./tools/export.sh all
```

Android export additionally needs JDK 17, Android SDK 34 (`platform-tools`,
`platforms;android-34`, `build-tools;34.0.0`) and a debug keystore, all configured
in **Editor Settings → Export → Android** (or exported through CI, which does it
automatically).

### Option B — CI (how the published files are produced)

`.github/workflows/build.yml` runs five jobs on every push to `main`/`arena/**`:

1. **Headless smoke test** — imports the project, boots the 3D scene for 240 frames,
   then plays a **complete unattended campaign** (`-- --autoplay`): all three stages,
   crossroads, upgrades, boss phases and an ending. Any script error fails the run.
2. **Rendered screenshots** — runs the game under Xvfb with the OpenGL renderer and
   saves title / campus / boss stills as artifacts.
3. **Windows .exe** — `--export-release "Windows Desktop"`.
4. **Android .apk** — installs SDK 34, writes the Android editor settings, generates
   the debug keystore, patches the preset and runs `--export-debug "Android"`
   (apksigner signs and verifies the APK in the same step).
5. **Publish** — uploads both files to the rolling `latest-build` release.

### Option C — the editor

`Project → Export…` → choose **Windows Desktop** or **Android** → *Export Project*.
Presets, package name (`com.singularity.vessel`), version code/name, arm64-v8a,
landscape and immersive mode are already configured in `export_presets.cfg`.

---

## 8. Verification status — read this before trusting anything

Verified in CI on this branch (run artifacts available on the Actions tab):

- `gdparse` + `gdlint` clean across all 23 scripts; `tools/validate_project.py`
  checks every `res://` path, scene node and cross-script call.
- The project **boots headless** with zero script errors.
- An **unattended playthrough reaches the ending** (`AUTOPLAY_RESULT reason=ending
  stage=3 … endings=1`) — so stage flow, dialogue, crossroads, upgrades, boss phases
  and endings all execute for real.
- The **EXE and APK build successfully**; the APK is signed and verified by
  `apksigner` in CI.
- Screenshots are rendered from the actual build.

Not verified: nobody has played it with a mouse and keyboard on a real GPU here, and
nobody has tuned the difficulty by hand. The 3D art is deliberately stylized
low-poly — it reads as a 3D anime arena, but it is not film-quality character
modelling (the deck itself lists 3D models as an asset still to be produced).

---

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| `godot: command not found` | install Godot 4.3+ and put it on PATH, or `GODOT=/path/to/godot ./tools/export.sh` |
| Export says "export templates not found" | Editor → *Manage Export Templates* → download 4.3 stable |
| Android export: "A valid Java SDK path is required" | set `export/android/java_sdk_path` in Editor Settings, or let CI do it |
| Android export fails with an empty "configuration errors" list | `rendering/textures/vram_compression/import_etc2_astc` must be `true` in `project.godot` (already set — it fails silently otherwise) |
| No sound | the WAVs are in `res/audio/`; check `AudioManager` loaded them in the Output panel |

---

## 10. The single-file browser build

`index.html` is the earlier zero-install browser version of the same game (2D canvas,
procedural art and Web Audio). It is kept as a quick way to play in a browser without
installing anything; it is **not** the 3D Godot build.

---

## 11. Credits

Design, code, procedural models, textures, music and sound: built for
**abdulkather82821-shadow** from the *SINGULARITY: Vessel of the Fallen* deck.
Story, characters and setting are fictional and written to stay respectful of the
real PMIST community. Engine: [Godot 4.3](https://godotengine.org).
