# SINGULARITY — Vessel of the Fallen

A complete, playable **Godot 4 action-RPG** set at PMIST campus the evening the sky
cracked open. Three stages, a multi-phase boss, seven upgrades, story crossroads and
three endings — with every character, backdrop, effect, sound and music loop generated
procedurally inside this project.

> This repository also keeps the earlier **single-file browser build** (`index.html`)
> as a reference version. The Godot project is the shipping form of the game.

---

## 1. Quick start

1. Install **Godot 4.3 or newer** (standard build, no .NET needed).
2. Launch Godot → **Import** → pick this folder's `project.godot` → **Import & Edit**.
3. Press **F5** (or the ▶ Play button). The main scene is `res://res/scenes/main.tscn`.

No plugins, no add-ons, no external downloads. The first import generates Godot's
`.godot/` cache; it is git-ignored and safe to delete.

**On a phone:** the same project runs on Android/iOS. Landscape is locked, the
on-screen thumbstick and buttons appear automatically, and the HUD scales with the
viewport (`canvas_items` stretch, 1280×720 design resolution).

---

## 2. Story in one paragraph

The last bell has rung at PMIST when a rift tears the courtyard open. Ajees is pulled
into the wound in the sky and comes back as its vessel — power that should have
destroyed him now waits in his hands. Sara, Bala, Manmohan, Gokul and Prince hold the
line while he fights through the campus, the fractured rift, and finally the glass
throne of **Katleen**, who opened the door in the first place. Every crossroads you
take changes the run; the last choice decides which of three endings you earn.

All characters are fictional. The campus is used as a respectful backdrop, not a claim
about real people or events.

---

## 3. Controls

| Action | Keyboard / mouse | Touch |
| --- | --- | --- |
| Move | `W A S D` / arrow keys | drag anywhere on the left half |
| Rift blade (3-hit combo) | `J` or left click | **A** |
| Rift shot | `K` or right click | **B** |
| Singularity burst | `L` | **S** |
| Jump | `SPACE` | — |
| Phase dash (i-frames) | `SHIFT` | **D** |
| Mend (needs the upgrade) | `H` | **H** |
| Pause | `ESC` / `P` | **II** button, top right |

Attacks and shots auto-repeat while held, so mashing is optional. Menus are
mouse/touch driven; `ENTER` starts a run from the title screen and `R` retries after
a defeat.

---

## 4. What is in the run

* **Three stages** — *The Awakening* (PMIST courtyard at dusk), *The Dimensional Rift*
  (broken campus, burning ground hazards), *Katleen's Realm* (glass throne, boss).
* **Stage 1** asks for 12 wraiths in 42 s; **stage 2** asks for 16 in 52 s while
  telegraphed ground hazards rain down. Hitting the quota *or* surviving the clock
  clears the stage — the score bonus is the same.
* **Combat:** 15 / 15 / 24 damage combo with a heavy third hit, 13-damage rift shots,
  a 36-damage radial burst, dash i-frames, knockback, hit-stop, screen shake and
  floating damage numbers.
* **Energy:** regenerates 10/s, pays for shots (7), burst (45) and Mend (26). Blue
  motes from kills refill it.
* **Combo:** every kill adds 0.5× up to 4× and refreshes a 2.6 s window; taking a hit
  resets it. Score = kills × combo + damage dealt + orbs + stage bonus.
* **XP and upgrades:** kills drop orbs; each level opens a three-card choice from
  seven upgrades (Rift Edge, Vessel Current, Vessel Mend, Phase Step, Second Heart,
  Singularity Core, Rift Flux). Ranks are capped and exhausted pools fall back to a
  score bonus instead of a dead screen.
* **Crossroads:** after stage 1 (Scholar vs Guardian), after stage 2 (Sara joins vs
  fight alone) and before the throne (faith vs the rift's power). Choices are
  permanent for the run and change damage, health, healing and the ally.
* **Sara** auto-fires 11-damage bolts every 2.4 s once she joins.
* **Katleen:** 1200 HP, intro animation, five moves (fan blast, dash, nova marks,
  barrage, summons) and a 50 % phase shift that speeds her up, adds shots and grows
  wings.
* **Three endings:** *The Vessel's Choice*, *The Sovereign of the Rift* and
  *A Quiet Morning*, tracked across runs.
* **Records & settings** persist in `user://save.cfg` (best score, best combo,
  wraiths, victories, endings found, checkpoint, five toggles).

---

## 5. Project layout

The structure follows the pitch deck's page 12 outline: one engine config, one scene
folder, one script folder, and an asset tree.

```
project.godot              # engine config: main scene, autoloads, input map, stretch
icon.svg                   # hand-written project icon
export_presets.cfg         # Android preset (see §7)
README.md
index.html                 # reference browser build of the same game
tools/
  generate_audio.py        # regenerates every WAV in res/audio
  generate_textures.py     # regenerates every PNG in res/textures
res/
  scenes/                  # game scenes
    main.tscn              #   root: Stage (background/world/effects) + UI layers
    player.tscn  enemy.tscn  boss.tscn
    projectile.tscn  pickup.tscn  hazard.tscn
    background.tscn  effects.tscn
    hud.tscn  menus.tscn  dialogue.tscn  touch_controls.tscn  post_fx.tscn
  scripts/
    game_config.gd         # autoload GameConfig  - every tuning constant
    save_manager.gd        # autoload SaveManager - records, settings, checkpoint
    audio_manager.gd       # autoload AudioManager- pooled SFX + looping music
    story_manager.gd       # autoload StoryManager- dialogue, crossroads, endings
    main.gd                # director: state machine, waves, collisions, flow
    manager.gd             # RunState: score, combo, XP, upgrades, story flags
    effects.gd             # particles, shockwaves, slashes, damage numbers
    post_fx.gd             # vignette, grain, scanlines, low-health pulse, flashes
    entities/
      player.gd  enemy.gd  boss.gd
      projectile.gd  pickup.gd  hazard.gd
    world/
      background.gd        # three hand-drawn parallax backdrops
      shapes.gd            # shared vector primitives
    ui/
      ui.gd                # interface factory (panels, cards, bars, buttons)
      hud.gd  menus.gd  dialogue_box.gd  touch_controls.gd
  assets/                  # shared asset notes (art is code-drawn, see below)
  models/                  # reserved for mesh imports; the game needs none
  textures/                # glow, glow_sharp, shadow, vignette, grain, scanline
  audio/                   # 22 sound effects + 5 music loops (16-bit mono WAV)
```

### Mapping to the "Key Files" legend

| Deck legend | In this project |
| --- | --- |
| `project.godot` — game config | window/stretch/mobile settings, four autoloads, full input map |
| `scenes/` — game scenes | `res/scenes/*.tscn`, main scene instanced from `project.godot` |
| `scripts/` — GDScript | `res/scripts/**`, split into director, entities, world and UI |
| `player.gd` / `enemy.gd` / `boss.gd` | `res/scripts/entities/` |
| `manager.gd` | `res/scripts/manager.gd` (run state) + `res/scripts/main.gd` (director) |
| `ui.gd` | `res/scripts/ui/ui.gd` plus `hud.gd`, `menus.gd`, `dialogue_box.gd` |
| `assets/` — models/textures/audio | `res/textures/` and `res/audio/`; `res/models/` is reserved |

### About the art

This is a **stylised 2D game inside a 3D engine's project layout** — not a 3D game.
Nothing here is a mesh import. Characters, the three backdrops, bullets, hazards and
particles are drawn with `CanvasItem` vector calls every frame (`Shapes` holds the
shared primitives), which is why there is no sprite sheet to manage. Depth is faked
the same way the browser build did it: entities are y-sorted, scaled by their ground
position, and cast a ground shadow.

Two consequences worth knowing:

* The `res/models/` folder is empty on purpose. Drop `.glb`/`.obj` files there if you
  ever want to add real models; nothing currently loads from it.
* Because the art is code, tweaking a colour in `player.gd` or `background.gd`
  re-skins the game instantly.

---

## 6. Assets, regeneration and tuning

Everything ships with the repo, but both generators are pure standard-library Python
(no Pillow, no numpy) and are safe to re-run:

```bash
python3 tools/generate_audio.py      # rewrites res/audio/*.wav  (~2.7 MB, 27 files)
python3 tools/generate_textures.py   # rewrites res/textures/*.png (~140 KB, 6 files)
```

* **Audio** is synthesised from oscillators and noise (sine/saw/square/tri), with
  envelopes and a simple echo; music loops are procedural pad progressions.
  `AudioManager` loads them by name, pools ten players for SFX and loops the music
  manually, so a missing or muted file can never crash the game.
* **Textures** are written by a tiny zlib/struct PNG encoder: a soft glow, a sharp
  glow, a contact shadow, a vignette, animated grain and scanlines.
* **Balance** lives in one place: `GameConfig` (`res/scripts/game_config.gd`). Player
  speed, damage, boss timings, stage tables, upgrade ranks, score values and palettes
  are all constants there. Change a number, press F5.

Difficulty knobs worth knowing: `STAGES[*].hp_mul / speed_mul / damage_mul`,
`BOSS_HP`, `BOSS_MOVES[*].cooldown`, `XP_GROWTH` and `COMBO_MAX_MULT`.

---

## 7. Building an Android APK

`export_presets.cfg` already contains an **Android** preset (`com.singularity.vessel`,
landscape, arm64). The full path from the deck's page 10:

1. **Install the SDK.** Install Android Studio, then in its SDK Manager add
   *Android SDK Platform 34*, *Build-Tools* and *Platform-Tools*. Note the SDK path.
2. **Point Godot at it.** `Editor → Editor Settings → Export → Android`:
   set `Android SDK Path`; for debug exports also set a debug keystore
   (`~/.android/debug.keystore`, alias `androiddebugkey`, password `android`).
   Godot will show a green tick when the SDK and Java are found.
3. **Install export templates.** `Editor → Manage Export Templates → Download` for
   your exact Godot version.
4. **Open the preset.** `Project → Export… → Android`. Adjust *Package → Unique Name*,
   *Version*, and the launcher icons; keep `arm64-v8a` checked. Tick *Gradle Build* if
   you need custom Android plugins (requires *Install Android Build Template*).
5. **Export.** Set the path to `build/android/singularity.apk` and press
   **Export Project**. `build/` is git-ignored.
6. **Install on the phone.** `adb install -r build/android/singularity.apk`, or copy
   the APK across and tap it (allow unknown sources).

Notes: the project already locks landscape, uses the GL Compatibility renderer (best
for mid-range phones) and enables immersive mode in the preset. If your Godot version
rewrites some preset keys, re-select the values in the export dialog once and save —
the file is plain config, not code.

---

## 8. Verification status — read this before trusting anything

The engine **could not be launched in the environment where this port was written**
(the Godot binary download was blocked). So, honestly:

* Every one of the 21 GDScript files is **parsed** with `gdparse` (Godot 4 grammar)
  and **linted** with `gdlint` — zero errors.
* Every `res://` path referenced by scripts, scenes and `project.godot` is checked to
  exist on disk.
* Every node path used by `@onready` in `main.gd` is checked against `main.tscn`.
* Every cross-object call and signal connection between the director, entities and UI
  is checked by a static symbol pass.
* The scenes are **not** instantiated, and no frame has been rendered, in this
  environment. Expect to fix small things the first time you press F5.

The browser build in `index.html` was verified the hard way (headless runs, a
scripted bot reaching the victory state, scripted assertions), so the rules, numbers
and flow here follow a version of the game that is known to be playable.

---

## 9. Troubleshooting

| Symptom | Fix |
| --- | --- |
| Project opens but the screen is black | Check the Output panel; a script error stops `main.gd` before the title screen. |
| No sound on Android | Media volume, and `SaveManager` settings (Settings → Sound Effects / Music). |
| Touch buttons missing | Settings → *Touch controls on screen* must be on; they are hidden during menus. |
| A shot feels like it misses the boss | Her hit centre is deliberately generous; aim at the torso, not the feet. |
| `user://save.cfg` warning in Settings | The device denied file access; the game keeps running without records. |

---

## 10. Reference: the single-file browser build

`index.html` is the earlier version of the same game: one self-contained file, no
build step, no libraries. Open it in any modern browser (double-click works). It
carries the same three stages, upgrades, crossroads and endings, saves the high score
in `localStorage`, and synthesises its audio with the Web Audio API after the first
tap/click. Keyboard: `WASD` move, `J` attack, `K` shot, `L` burst, `SPACE` dash,
`H` mend, `ESC` pause. It is kept as a reference and a zero-install way to play; the
Godot project is the version to extend.

---

## 11. Credits

Design, code, story, art and audio: made for this project, in code.
Engine: **Godot 4** (MIT). No third-party assets, fonts, plugins or libraries are
bundled — the interface uses Godot's built-in fallback font on purpose.
