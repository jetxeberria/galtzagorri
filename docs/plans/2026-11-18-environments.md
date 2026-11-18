# Plan: testing and production environments, `just sync`

| | |
|---|---|
| **Status** | Approved 2026-11-18 |
| **Implements** | G-008 (ENV-1 … ENV-3; amends PY-1, UPD-1, INI-1) in the [specification](../SPECIFICATION.md) |
| **Date** | 2026-11-18 |

## Starting point

Facts verified on 2026-11-18, with PDM 2.29.7, `use_uv = true` and a throwaway clone of lantoki:

- `pdm use --first 3.15` recreates `.venv` on every run, and the template's `install-python` uses it. `pdm sync -G :all --clean` with no `pdm use` creates `.venv` from `requires-python` when it is missing, and a second run leaves it in place (`pyvenv.cfg` mtime unchanged).
- `pdm sync --clean` removes a package the lock does not list. Tested with `six`.
- `pdm venv create -n prod`, then `pdm sync --prod --no-editable --venv prod`, gives a production venv: the project runs in it, it has no pytest or ruff, and it uses the lock's versions.
- The built wheel's `Requires-Dist` lists only `dependencies`.
- `uv tool install --constraints <freeze of prod> <wheel>` installs exactly the locked versions (`pydantic==2.14.3`, `mcp==2.3.0`).
- `pdm export --prod` fails: "Can't export a lock file without environment markers". Relocking with `--strategy inherit_metadata` did not add them (the lock's `strategy` stays `[]`). So the freeze is taken from the prod venv instead.
- Recipes to replace: `install-python` and `install-deps` (`tooling.just`), `update-lock` (`Justfile`). `install-env` = `install-python install-plugins install-deps install-hooks`. `update-sync` lists all of them.
- `.python-version` is committed in galtzagorri, lantoki and harness-harvest. `pdm use` wrote it; nothing will write it once `pdm use` is gone.

## Phase 1: recipes

**`template/tooling.just`** (shared with galtzagorri's root Justfile):

| Recipe | Body |
|---|---|
| `sync` | `sync-lock sync-python sync-dev sync-prod` |
| `sync-lock` | `pdm lock -G :all --update-reuse` |
| `sync-python` | Reads X.Y from `requires-python`. When no interpreter matches it (`pdm python find X.Y` fails), runs `pdm python install X.Y`; otherwise prints that it is skipping. |
| `sync-dev` | `pdm sync -G :all --clean` |
| `sync-prod` | Skipped when `distribution = false` (galtzagorri's own root). Otherwise creates the `prod` venv if `pdm venv --path prod` fails, then runs `pdm sync --prod --no-editable --clean --venv prod`. |
| `install-env` | `install-plugins sync install-hooks` |

**Removed:** `install-python`, `install-deps`.

**`template/Justfile`:**

- `add`, `remove` and `upgrade` run `pdm add/remove/update --no-sync {{ args }}`, then `just sync`.
- `update-sync` becomes `update-conflicts install-plugins sync install-hooks check`.
- `update-lock` is removed.
- `install-tool` freezes the `prod` venv (`pdm list --venv prod --freeze`, without the project's own line) into a temporary file, then runs `uv tool install --force --constraints <file> <wheel>`.

**Projects:** `git rm .python-version` in galtzagorri, lantoki and harness-harvest. `requires-python` is the only source.

Verified: `pdm python find 3.15` prints the interpreter and exits 0; `pdm python find 3.99` exits 1.

## Phase 2: documentation

- **Generated README:** a short *Environments* section. It covers the two environments, `just sync` after a pull, and that add/remove/upgrade sync by themselves.
- **galtzagorri README:** the *Python* row says `just sync`.
- **lantoki user rule** `customizations/user/instructions/dependencies.md` gets an *Environments* section stating the owner's rule for every project:
  - the environment follows `pyproject.toml` through one sync operation;
  - testing = production + development tools, from one resolution, with requirements nested and never duplicated;
  - the package carries production requirements only.

  Then run `lantoki sync user`.

## Phase 3: checks (CHK-1)

`test-template` (already: `install-env`, `check`, packaging tests) also checks:

- A second `just sync` keeps `.venv` (unchanged `pyvenv.cfg` mtime).
- The `prod` venv imports the package and has no `pytest`.
- `just add -dG dev six`, then `just remove -dG dev six`, leaves `six` neither in `.venv` nor in `prod`.
- In the `install-tool` test, the tool's environment has the same versions as `prod`.
- Cleanup removes the `prod` venv, which PDM keeps outside the project, with `pdm venv remove -y prod`.

**Check:** galtzagorri's `just check`. Then commit, citing G-008, and push.

## Phase 4: projects

| Project | Steps | Check |
|---|---|---|
| harness-harvest | `just update`, `git rm .python-version`, commit, push | ends with *all checks passed*; a second `just sync` keeps `.venv`; `prod` exists |
| lantoki | `just update` on the unmerged `feat/init-and-git-exclude` branch, `git rm .python-version`, rule change, `lantoki sync user`, commit, push the branch | same, plus `lantoki plan user` reports only the changed rule |

## Findings during execution

- `pdm sync --prod --venv prod` prints a long `Removed <package>` list (copier, pytest, …) on every run. Neither environment changes, though. Checked by counting distributions before and after: `.venv` stayed at 35 and `prod` at 1. A package installed into `prod` by hand is still removed by the next sync. The list is misleading output from the uv backend, not a change.

## Risks

| Risk | Mitigation |
|---|---|
| The `prod` venv lives in PDM's venv folder (`~/.local/share/pdm/venvs/<project>-<hash>-prod`), outside the project | Accepted: it is PDM's own mechanism. `pdm venv list` shows it, and `just clean-envs` could remove both later if wanted. |
| `--clean` removes packages installed by hand in `.venv` | Intended (ENV-2): the environment is what `pyproject.toml` says. |
| Every sync now syncs two environments | Cheap: uv links from its cache, and `--clean` is a no-op when nothing changed. |

## Out of scope

- CI.
- A test run inside the `prod` venv (the tests need `pytest`, which is a dev tool). The `prod` venv is checked by importing the package and by `install-tool`.
