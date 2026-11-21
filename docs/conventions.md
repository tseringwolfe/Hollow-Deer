# Hollow Deer Conventions

## Folder rules
- `scenes/X/foo.tscn` has its script at `scripts/X/foo.gd`. The two trees mirror each other exactly.
- Art goes in `assets/`, grouped by type.
- Prefix files with the scene name, for example `wolf_sheet.png` and `wolf_stats.tres`.
- Editor plugins go in `addons/`. Command-line scripts go in `tools/`.
- `.gd` resource definitions and the `.tres` files that use them live together in `resources/`.

## Scene rules
- One controller script per scene, on the root node, named after the scene.
- Extra scripts only go on their own subscenes (for example `health_component.tscn`). Don't stack scripts on one node.
- Signals go up, method calls go down. A scene references only its own children.
- External dependencies are wired up by a parent, through `@export`, public methods, or `event_bus`.
- At most one layer of scene inheritance (for example `enemy_base` → `slime`).
- Subscene children stay non-editable. Expose settings with `@export` instead.
- Script member order: signals, enums, constants, `@export` vars, public vars, private vars, `@onready` vars, `_ready`, other built-in methods, public methods, private methods.

## Workflow rules
- snake_case for all files and folders. PascalCase only for `class_name`.
- Move, rename, and delete files only in Godot's FileSystem dock. Use "View Owners" before deleting.
- Commit before any refactor, so `git restore .` can undo it.
- If the project breaks after a pull, delete `.godot/` and reload the project.
- Use `%UniqueName` node references. `assert` required exports in `_ready`.
- Prefer `.tres` over `.res`.
- Commit `.import` and `.uid` files.
- Don't edit a `.tscn` you don't own. Instance it instead.
- Credit every outside asset in `assets/CREDITS.md`.
