# SINGULARITY: VESSEL OF THE FALLEN

A cinematic, anime-inspired 2D action arena game (with pseudo-3D depth, parallax and
layered lighting) playable in any modern browser. The entire game — art, characters,
effects, music and sound — is generated at runtime by code inside a single file.

## Play

Open `index.html` directly in a browser (Chrome, Edge, Firefox or Safari). No build step,
no server, no network access, no external assets or libraries.

- **Desktop:** `WASD` / arrow keys to move, `Space` jump, `J` strike, `K` energy shot,
  `L` special burst, `H` mend, `Shift` dash, `Esc` pause, `Enter` advance dialogue,
  `1`–`3` to answer story choices and pick level-up upgrades.
- **Mobile:** virtual stick on the left; `STRIKE`, `SHOT`, `SPECIAL`, `DASH`, `JUMP`,
  `MEND` on the right; `❚❚` to pause. Touch controls appear automatically on touch devices.

## Campaign

0. **Prologue** — the PMIST classroom at 6:42 PM, the last bell long gone.
1. **The Awakening** — the campus courtyard at dusk. Learn the controls, survive the first
   wraiths, and awaken the vessel (unlocks the special burst).
2. **The Dimensional Rift** — the campus fractures. Brutes, ranged stalkers and telegraphed
   rift eruptions.
3. **Katleen's Realm** — a two-phase boss duel against Katleen with telegraphed blasts,
   dashes, novas and summons.

Defeat Katleen to win. Health reaching zero shows the Game Over screen with retry.

## Progression, choices and endings

- **XP & levels** — wraiths, rift energy and stage clears grant XP. Every level offers a
  choice of three permanent upgrades (Rift Edge, Vessel Current, Vessel Mend, Phase Step,
  Second Heart, Singularity Core, Rift Flux). Combat freezes while you choose.
- **Crossroads** — story choices change your build: *Scholar* (bigger burst) or *Guardian*
  (Mend + health) before stage 1, *stand with Sara and the others* (ally support fire and
  +20 health) or *walk alone* (+18% damage) before stage 2, and *faith* or *take the power*
  after Katleen's phase change.
- **Endings** — the final choice decides which of three endings you earn: *The Vessel's
  Choice*, *The Sovereign of the Rift*, or *A Quiet Morning*. Endings found are tracked
  in the High Score screen.

## Systems

- Central `CONFIG` object for all tunable gameplay values.
- Delta-time game loop with clamped frames, hit-stop and slow-motion support.
- State machine: `TITLE`, `HOW_TO_PLAY`, `DIALOGUE`, `PLAYING`, `PAUSED`,
  `STAGE_TRANSITION`, `BOSS_INTRO`, `CHOICE`, `UPGRADE`, `VICTORY`, `GAME_OVER`.
- Melee / ranged / special attacks with cooldowns, energy costs, hit IDs preventing
  duplicate damage, knockback, invulnerability frames, floating damage numbers and
  screen shake.
- Combo multiplier (up to ×4) feeding the score; stage, survival, boss and no-damage bonuses.
- Procedural Web Audio sound effects and an ambient score; settings for SFX, music,
  screen shake, reduced effects and touch controls.
- `localStorage` for best score, records, settings and a checkpoint (Continue Campaign).
  All storage access is guarded and the game keeps working if storage is blocked.

## Notes

- Story, characters (Ajees, Sara, Bala, Manmohan, Gokul, Prince, Katleen) and the campus
  setting are fictional story elements; no real people are depicted.
- Tested headlessly: full campaign completion, game over/retry, pause gating, touch input,
  combo scoring, hazards, XP/upgrades, Mend, crossroads and all three endings, ally support,
  storage failure handling — 22 + 29 + 35 automated checks, plus rendered-frame visual review.
