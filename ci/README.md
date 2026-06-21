# Health checks

Warn-only CI for the project. **Nothing here blocks a merge** — it reports problems
as annotations + a summary on every PR and push to `main` (see the Actions
`health-check` run). Run the same checks locally before you push:

```sh
python3 ci/checks.py                  # static: UIDs, refs, conflict markers, project.godot, filenames…
GODOT=godot bash ci/godot_checks.sh   # import + script parse + boot smoke (needs Godot 4.6)
```

`ci/parse_check.gd` is the in-project parser used by `godot_checks.sh`; not meant to be run directly.

`checks.py` accepts `CHECK_ROOT=/path` to scan another checkout, and `--strict` to exit non-zero on errors.
