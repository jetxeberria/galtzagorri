# Plan: one development environment; the package is the production artifact

| | |
|---|---|
| **Status** | Proposed, awaiting approval |
| **Implements** | G-009 (ENV-4, ENV-5; amends ENV-2, CHK-1) in the [specification](../SPECIFICATION.md) |
| **Replaces** | the production-venv part of [the environments plan](2026-11-18-environments.md) |
| **Date** | 2026-11-18 |

## Starting point

As of galtzagorri `b99a3c1`:

- `template/tooling.just` has `sync: sync-python sync-lock sync-dev sync-prod`. `sync-prod` creates and syncs PDM's named venv `prod`.
- `install-tool` freezes `prod` into a constraints file for `uv tool install`.
- `test-template` checks `prod` (it imports the package, has no pytest, and gives versions equal to `.venv`) and removes it on exit.
- `pdm venv list` and `~/.local/share/pdm/venvs/` are empty on this machine. lantoki and harness-harvest are still on galtzagorri `e627ecc`, from before `just sync`.
- The wheel's `Requires-Dist` lists only `dependencies`, as ranges (verified on lantoki).

## Phase 1: galtzagorri

1. `template/tooling.just`:
   - `sync` becomes `sync-python sync-lock sync-env`; `sync-dev` is renamed `sync-env`, since there is one environment.
   - `sync-prod` is removed.
   - The header comment describes one environment.
2. `template/Justfile`:
   - `install-tool` drops the freeze and constraints: `uv tool install --force <wheel>`.
   - A new `check-package` recipe:
     1. Build.
     2. `uv venv --python X.Y` (X.Y from `requires-python`) in a temporary folder.
     3. `uv pip install` the wheel alone.
     4. Import every package under `src/`.
     5. Load every `console_scripts` entry point of the distribution (`importlib.metadata`).
     6. Delete the folder.
   - `check` becomes `fmt-check lint test check-package`.
3. READMEs:
   - The generated *Environments* section describes one `.venv`, with `just sync` after a pull.
   - *Packaging* says the wheel carries production requirements as ranges and installs without PDM.
   - The galtzagorri README *Python* row drops the production venv.
4. `test-template`:
   - Remove the `prod` checks, the prod-version comparison in the `install-tool` test, and the `pdm venv remove` cleanup.
   - Keep: a second `just sync` keeps `.venv`; `just add six` / `just remove six` reach `.venv`.
   - New negative check: put an `import six` in the package with `six` only in the `dev` group. `just check-package` must fail. Then undo both.

**Check:** galtzagorri's `just check`. Then commit, citing G-009, and push.

## Phase 2: projects

| Project | Steps | Check |
|---|---|---|
| harness-harvest | `just update`, `git rm .python-version`, commit, push | ends with *all checks passed*; a second `just sync` keeps `.venv`; no `prod` venv |
| lantoki (branch `feat/init-and-git-exclude`) | `just update`, `git rm .python-version`, commit, push the branch | same; `check-package` passes for `lantoki` and `python-verification-gate` |

## Phase 3: the owner's rule for every project

Add an *Environments and packaging* section to lantoki's `customizations/user/instructions/dependencies.md`:

- one development environment, which always follows `pyproject.toml` and is changed only by syncing it;
- the testing environment holds the production requirements plus development tools, from one resolution, with requirements nested and never duplicated;
- the package is built from production requirements only, as version ranges that rely on the dependencies' semantic versioning;
- a new major version is adopted deliberately, through an upgrade and the checks.

Then run `lantoki sync user`, and commit on the lantoki branch.

**Check:** `lantoki plan user` before `sync user` shows only that rule as changed; after it, 25 unchanged.

## Risks

| Risk | Mitigation |
|---|---|
| `check-package` needs network access to resolve the wheel's dependencies | Same as `just sync`; uv's cache makes repeat runs fast. |
| A package with no importable module under `src/` | `check-package` reports that it found none and fails: the template always generates one. |
| A dependency breaks within its range despite semantic versioning | Out of the package's control. The next `just upgrade` and `just check` expose it, and a stated upper bound is the fix (dependency rule). |

## Out of scope

- Publishing to an index.
- CI.
