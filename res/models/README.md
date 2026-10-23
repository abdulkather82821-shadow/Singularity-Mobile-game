# res/models

Reserved for imported 3D meshes (`.glb`, `.obj`, `.gltf`).

The shipped game needs none: SINGULARITY is a stylised 2D action-RPG. Entities and
backdrops are drawn with vector calls every frame, and depth is faked with y-sorting,
ground-position scaling and contact shadows. This folder exists so the project layout
matches the pitch deck and so a future 3D pass has a home.

Nothing here is referenced by any scene or script.
