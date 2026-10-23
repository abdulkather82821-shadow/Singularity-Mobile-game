# res/assets

Shared home for any asset that does not belong to one specific media folder.

Everything the shipped game draws is generated at runtime from `res/scripts/`
(`Shapes`, `effects.gd`, the entity `_draw()` methods) or loaded from:

* `res/textures/` — six generated PNGs (glow, sharp glow, shadow, vignette, grain,
  scanlines) used for light, contact shadows and post-processing.
* `res/audio/` — 22 synthesised sound effects and 5 music loops.

If you add imported art later, keep sprites and UI sheets in `res/textures/`, audio in
`res/audio/`, and put shared source material (palettes, references, licence notes) in
this folder. Nothing in this folder is loaded at runtime, so it never affects exports.
