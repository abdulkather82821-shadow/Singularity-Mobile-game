# SINGULARITY: VESSEL OF THE FALLEN

A cinematic, anime-inspired 2D action arena game (with pseudo-3D depth, parallax and
layered lighting) playable in any modern browser. The entire game — art, characters,
effects, music and sound — is generated at runtime by code inside a single file.

## Play

Open `index.html` directly in a browser (Chrome, Edge, Firefox or Safari). No build step,
no server, no network access, no external assets or libraries.

- **Desktop:** `WASD` / arrow keys to move, `Space` jump, `J` strike, `K` energy shot,
  `L` special burst, `Shift` dash, `Esc` pause, `Enter` advance dialogue.
- **Mobile:** virtual stick on the left; `STRIKE`, `SHOT`, `SPECIAL`, `DASH`, `JUMP` on the
  right; `❚❚` to pause. Touch controls appear automatically on touch devices.

## Campaign

1. **The Awakening** — the PMIST-inspired courtyard at dusk. Learn the controls, survive the
   first wraiths, and awaken the vessel (unlocks the special burst).
2. **The Dimensional Rift** — the campus fractures. Brutes, ranged stalkers and telegraphed
   rift eruptions.
3. **Katleen's Realm** — a two-phase boss duel against Katleen with telegraphed blasts,
   dashes, novas and summons.

Defeat Katleen to win. Health reaching zero shows the Game Over screen with retry.

## Systems

- Central `CONFIG` object for all tunable gameplay values.
- Delta-time game loop with clamped frames, hit-stop and slow-motion support.
- State machine: `TITLE`, `HOW_TO_PLAY`, `DIALOGUE`, `PLAYING`, `PAUSED`,
  `STAGE_TRANSITION`, `BOSS_INTRO`, `VICTORY`, `GAME_OVER`.
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
  combo scoring, hazards, storage failure handling and 22 + 29 automated checks.
