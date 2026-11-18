# galtzagorri — Specification

| | |
|---|---|
| **Status** | Active |
| **Owner** | jetxeberria |
| **Last change** | 2026-11-18 — G-008 (testing and production environments, `just sync`) |

This document is the authority on what galtzagorri must do and **why**. Every requirement has an ID and a rationale; the template, its recipes and its README implement them. A change to what the template does is written here first (requirement + decision-log entry), then made in the template, and commits cite the IDs.

---

## 1. Purpose

**PUR-1. galtzagorri is the single owner of the development tooling shared by the owner's projects.** It is a [Copier](https://copier.readthedocs.io) template: system packages, user tools, the PDM environment, formatters, linters, tests and git hooks are defined once here and reach every generated project through `just update`.

> **Why.** Hand-maintained copies of the same tooling drift: a fix made in one project never reaches the others. One template, updated through a self-checking command, keeps every project aligned.

## 2. Ownership

**OWN-1. Every line of a generated project has one owner: the template or the project.** Template-owned files (`Justfile`, `tooling.just`, `packaging.just`, `pdm.toml`, `.editorconfig`, `.yamlfmt.yaml`, `.yamllint.yaml`, `.clang-format`, `.gitattributes`, `.pre-commit-config.yaml`, `.copier-answers.yml`) and template-owned lines (the `base` group) are never edited in the project. The project owns its metadata, `dependencies`, its own dependency groups and `project.just` (JUS-1). *Amended by G-005: the Justfile was previously split by a project-specific marker.*

> **Why.** Tested with copier: `copier update` does not restore lines the project deleted, and it conflicts whenever the template edits lines near a project edit. Keeping template-owned and project-owned lines apart is what lets updates merge cleanly; a whole file per owner is the cleanest form of that separation.

**OWN-2. Projects extend template behaviour through tool configuration, not by redefining recipes.** `just check`, `just test`, `just fmt` and `just lint` mean the same thing in every project; a project tunes them in `pyproject.toml` (`[tool.ruff]`, `[tool.pytest.ini_options]`, …).

> **Why.** A redefined recipe conflicts on every update that touches it, and `just check` would mean different things in different projects.

## 3. Requirements

**DEP-1. Template-owned `base` dependency group with `>=` floors.** The generated `pyproject.toml` has a `base` group holding the tools the template's recipes need (`copier`, `pre-commit`, `pytest`, `ruff`, `yamllint`), each as a minimum version. It is separate from the project-owned `dependencies` and `dev` group. A project that needs a newer version of a `base` tool adds a higher floor to its `dev` group.

> **Why.** OWN-1: separate groups merge without conflicts. Floors rather than pins let PDM resolve the latest compatible versions (the owner's dependency policy) while the lock, which covers all groups, keeps installs reproducible.

**PY-1. The minimum Python version is a template answer, `python_min`** (default: the latest stable release, `3.15`). It renders `requires-python = ">=X.Y"`, from which the environments are built (ENV-2). Updates never change it; raising it is a deliberate `just update --data python_min=3.X` on a branch.

> **Why.** The latest compatible version by default, without an upper bound nobody can justify. Kept in `.copier-answers.yml` so a template update cannot silently raise a project's minimum.

**UPD-1. `just update` leaves a working repository.** It merges the template (`update-template`: `copier update --defaults`, extra arguments passed through), then runs `update-sync` in a second `just` invocation, so it uses the recipes the merge brought in:

1. `update-conflicts`: stop if copier left conflict markers or `*.rej` files;
2. `install-plugins`, then `sync` (ENV-2): relock and bring both environments in line with `pyproject.toml`;
3. `install-hooks`;
4. `just check`.

*Amended by G-008: steps `install-python`, `update-lock` and `install-deps` are replaced by `sync`.*

After resolving conflicts, `just update-sync` resumes from step 1.

> **Why.** A merge alone can leave a stale lock or broken checks that surface later, in someone else's push. Ending with `just check` makes each update prove itself. `-G :all` is needed because `pdm lock --update-reuse` otherwise keeps the lock's old group list and misses groups the template adds; `--update-reuse` changes only what the new constraints require.

**ENV-1. Two environments, one resolution: testing and production.** Every project has:

| Environment | Where | Contains |
|---|---|---|
| testing (development) | `.venv` in the project | `dependencies` plus every dependency group (`base`, `dev`, the project's own), and the project in editable mode |
| production | PDM's named venv `prod` | `dependencies` only, and the project installed as a package, not editable |

Both come from the same `pdm.lock`, which resolves `dependencies` and all groups together. So every production package has the same version in both environments, and the testing environment is the production one plus development tools. Requirements are declared once: `dependencies` is the production set, and the groups only add to it. The production environment exists for packages (`[tool.pdm] distribution = true`, which every generated project is, PKG-2).

> **Why.** Owner's rule for every software project: tests must run against the exact package versions production uses, so a passing test suite also validates production's package selection; development tools must never leak into production. One lock for both gives the same versions without duplicating any requirement; the production venv proves that the package runs with production requirements only.

**ENV-2. The environments always follow `pyproject.toml`; `just sync` is the only way they change.** `sync` relocks (`pdm lock -G :all --update-reuse`, a no-op when nothing changed), then makes each environment match the lock exactly: `pdm sync -G :all --clean` for `.venv`, and `pdm sync --prod --no-editable --clean --venv prod` for production (the venv is created first if missing). It removes packages the lock no longer lists. The Python version comes from `requires-python` alone: PDM creates a missing environment with a matching interpreter, and `sync` only runs `pdm python install X.Y` (X.Y from `requires-python`) when no matching interpreter exists. There is no interpreter selection step (`pdm use`) and no option for it.

Every change goes through `sync`:

| Change | Recipe |
|---|---|
| add, remove, upgrade or downgrade a dependency | `just add`, `just remove`, `just upgrade`: they edit `pyproject.toml` / `pdm.lock` without installing (`--no-sync`), then run `sync` |
| template update | `just update` → `update-sync` → `sync` (UPD-1) |
| a pulled change to `pyproject.toml` or `pdm.lock` | `just sync` |

> **Why.** The environment is derived data: it must be what `pyproject.toml` says, whatever changed it, so one operation brings it in line and the resolver never cares whether a requirement came from the template or the project. Observed 2026-11-18 with PDM 2.29.7: the previous `install-python` (`pdm use --first X.Y`) recreated `.venv` on every run, so `just init` and `just update` reinstalled everything; `pdm sync` alone creates `.venv` from `requires-python` when it is missing and leaves a matching one in place (verified: unchanged `pyvenv.cfg`). Interpreter-selection options were configuration with no requirement behind them.

**ENV-3. The package carries production requirements only, at the locked versions.** The built wheel's metadata lists `dependencies` only (dependency groups never reach it). `install-tool` installs that wheel constrained to the production environment's versions (`pdm list --venv prod --freeze`, without the project itself, as `uv tool install --constraints`), so the installed tool runs on the tested versions. `install-tool-editable` follows the working tree and is for development.

> **Why.** Development and test tools are not needed in production. Without constraints, `uv tool install` would resolve the newest versions allowed by the floors, not the ones the tests ran against (ENV-1). The freeze is taken from the production venv because `pdm export` needs a lock with environment markers (`inherit_metadata`), which the uv-backed lock does not have (verified 2026-11-18).

**PKG-1. Packaging is a template answer, `packaged`** (boolean, default `false`). *Superseded by G-007 (PKG-2).*

- `false`: `distribution = false`, no build system; the project is an application environment, not an installable package.
- `true`: `distribution = true`, a `[build-system]` using `pdm-backend`, and a template-owned `packaging.just` (imported by the Justfile with `import?`) with an `install-tool` recipe running `uv tool install --editable .`, which puts the project's `[project.scripts]` on `PATH`.

The project still declares its own `[project.scripts]`.

> **Why.** Some projects ship a CLI (lantoki, harness-harvest) and must be installable. Without the option they would have to edit template-owned lines (`distribution`, `[build-system]`), and every update touching them would conflict (OWN-1). The recipe lives in its own conditional file so the Justfile stays a plain, non-Jinja file; `import?` makes the import a no-op when the file is not rendered. `--editable` keeps the installed command in sync with the working tree.

**PKG-2. Every generated project is a package, installable from its built package or from its sources.** There is no `packaged` answer: the generated `pyproject.toml` always has `distribution = true` and a `[build-system]` using `pdm-backend`, and the Justfile always has:

| Recipe | Does | Use it for |
|---|---|---|
| `build` | `pdm build`: sdist and wheel in `dist/` (cleaned first) | checking or sharing the package |
| `install-tool` | `build`, then `uv tool install --force` of the wheel just built | the project's commands on `PATH` exactly as a user would install them; reinstall to pick up changes |
| `install-tool-editable` | `uv tool install --force --editable .` | the project's commands on `PATH`, following the working tree: edits apply without reinstalling |
| `uninstall-tool` | `uv tool uninstall <project>` | removing either install |

The commands are the project's own `[project.scripts]`. A project that declares none has nothing to install: the `install-tool*` recipes say so and succeed, instead of failing as `uv tool install` does. Inside the project, `pdm install` already installs the package into `.venv` in editable mode, so `pdm run <command>` works without either recipe.

> **Why.** Owner's decision: almost every project ends as a package, so packaging is the default, not an option. Removing the answer also removes a render variant to test and a template branch to keep working (PKG-1 made `just check` render twice). The two install modes serve different needs: the wheel proves the package installs as it will for a user (missing package data or a wrong entry point shows up here, never in an editable install), while editable is what a developer working on the tool wants. `uv tool` keeps each tool in its own environment and links its commands into `~/.local/bin`, which `install-path` puts on `PATH`. The recipes live in the template's Justfile, so `packaging.just` is no longer needed.

**JUS-1. The Justfile is template-owned; project recipes live in `project.just`.** The generated `Justfile` holds only template recipes and imports, ending with `import? 'project.just'`. The template renders `project.just` once, as a stub with a comment and no recipes, and lists it in copier's `_skip_if_exists`, so `copier update` never touches it. A missing or empty `project.just` is valid. Recipe names must not repeat across the imported files (just rejects duplicates); a project tunes template recipes through tool configuration (OWN-2), not by redefining them.

> **Why.** With one Justfile split by a *project-specific recipes go below this line* marker, the template and the project edit the same file, and a template change near the marker conflicts (OWN-1). With the entry point owned by the template, `copier update` can always replace it, and the template can add imports later (as `packaging.just` needed, PKG-1) without editing a project-owned file. The reverse split (a project-owned Justfile importing a template file) was rejected for that reason: the template could never add an import line. `import?` keeps projects with no recipes of their own working; just runs imported recipes from the imported file's folder, which is the project root because `project.just` sits next to the Justfile.

**INI-1. `just init` makes a fresh checkout ready to work, on a brand-new machine.** After `sudo apt install just`, one command takes a freshly generated or freshly cloned project to a working state. It is idempotent: running it again changes nothing that is already set up. In order:

1. `init-git`: `git init` and stage the files, only when the folder is not a git repository yet.
2. `install`: system packages, user tools, both environments (`sync`, ENV-2) and the git hooks.
3. `install-tool-editable` (PKG-2): the project's commands on `PATH`, following the working tree; skipped when the project declares no `[project.scripts]`.
4. `init-project`, only when the project defines it in `project.just` (JUS-1): the project's own setup steps.
5. `init-ai`: AI-assistant customization for this repository through [lantoki](https://github.com/jetxeberria/lantoki), when `lantoki` is on `PATH` (`lantoki sync repo .`, which asks once per machine which sources apply). When it is not, `init-ai` prints how to get it and succeeds: the project works without it.
6. `check`: the last step, so *all checks passed* means the repository is ready.

The template does not list lantoki's outputs in `.gitignore`: lantoki keeps them out of git itself (lantoki INS-9).

> **Why.** Getting from a clone to a working repository took several commands whose order mattered (`install` before the hooks, the environment before `check`), and on a new machine they were easy to miss. One idempotent entry point is what a new machine, or a new contributor, needs. AI customization is lantoki's job (lantoki PUR-1), so the template calls lantoki and never duplicates its knowledge of harness folders, not even as `.gitignore` entries: they would go stale whenever a lantoki profile changes, and a broad entry such as `/AGENTS.md` would hide a project's own committed file. It is optional because a project must not need lantoki to build. `init-project` is optional for the same reason as `project.just`: just has no optional-recipe call, so `init` runs it only when `just --show init-project` finds it. Ending with `check` makes `init` prove itself, like `update` (UPD-1). *Supersedes the earlier `init` (`init-git` + `install-hooks`), which assumed the tools were already installed.*

**CHK-1. galtzagorri's own `just check` renders the template and runs the generated project's checks** with the default answers, then builds the package and installs it both ways (`install-tool`, `install-tool-editable`) into a temporary `UV_TOOL_DIR` and `UV_TOOL_BIN_DIR`, so the check never touches the user's own tools. It runs with uncommitted changes (`--vcs-ref HEAD`) and before every push (pre-commit hook).

> **Why.** A template change is only correct if the projects it generates pass their own checks; the install recipes are part of what the template promises (PKG-2), so they are exercised too, in isolation.

## 4. Change control

**CHG-1.** A change to what the template must do is first written here: the affected requirement and a decision-log entry with its reason. Then the template changes, and commits cite the IDs.

**CHG-2.** IDs are never reused. A superseded requirement is marked *Superseded by G-xxx*, not deleted.

### Decision log

| ID | Date | Decision | Reason |
|---|---|---|---|
| G-001 | 2026-11-17 | Template-owned `base` dependency group with `>=` floors, separate from the project-owned `dependencies` and `dev` (DEP-1, OWN-1). | Copier experiments: projects that edited template-owned lines conflicted on every update; separate groups merged cleanly. |
| G-002 | 2026-11-17 | Minimum Python is the `python_min` answer, default 3.15 (PY-1). | Latest stable by default; an update must never raise a project's minimum silently. |
| G-003 | 2026-11-17 | `just update` merges, then `update-sync` checks conflicts, installs Python, relocks with `pdm lock -G :all --update-reuse`, reinstalls plugins, dependencies and hooks, and runs `just check` (UPD-1). | An update must leave a working, checked repository; `-G :all` because `--update-reuse` keeps the lock's old group list. |
| G-004 | 2026-11-17 | Packaging is the `packaged` answer (default `false`): `distribution = true`, `pdm-backend` build system and an `install-tool` recipe (`uv tool install --editable .`) when true (PKG-1); `just check` renders both variants (CHK-1). | lantoki and harness-harvest ship CLIs; without the option they must edit template-owned lines and conflict on every update. |
| G-005 | 2026-11-18 | The generated `Justfile` is wholly template-owned and ends with `import? 'project.just'`; project recipes live in `project.just`, rendered once as a stub and skipped on updates (`_skip_if_exists`). Replaces the *project-specific recipes go below this line* marker (OWN-1, JUS-1). | One owner per file instead of per region: updates replace the Justfile without conflicts, and the template keeps control of the entry point, so it can add imports later. Owner's request. |
| G-006 | 2026-11-18 | `just init` takes a fresh checkout on a new machine to a working, checked repository: git (if needed), `install`, `install-tool-editable`, the optional `init-project` hook, `init-ai` (lantoki, when on `PATH`) and `check`; idempotent (INI-1). | Owner's request: one command to start working on any project, including its AI-assistant setup. |
| G-007 | 2026-11-18 | Every generated project is a package: no `packaged` answer; `distribution = true` and `pdm-backend` always; `build`, `install-tool` (from the built wheel), `install-tool-editable` (from the sources) and `uninstall-tool` in the template's Justfile; `packaging.just` is removed (PKG-2, supersedes PKG-1 / G-004). `just init` uses the editable install (INI-1). | Owner's decision: almost every project ends as a package; the template should provide building and both install modes by default. |
| G-008 | 2026-11-18 | Two environments from one lock: testing (`.venv`, all groups, editable) and production (named venv `prod`, `dependencies` only, not editable). `just sync` is the single operation that brings both in line with `pyproject.toml`; `add`/`remove`/`upgrade`, `update` and `init` all go through it. `install-python`, `update-lock` and `install-deps` are removed; Python comes from `requires-python` only. `install-tool` installs the wheel constrained to the production versions (ENV-1 … ENV-3; amends PY-1, UPD-1, INI-1). | Owner's rule for all projects: the environment follows `pyproject.toml`, tests run on production's exact versions, development tools never reach production. Also fixes `.venv` being recreated on every `init` and `update` (`pdm use --first`). |
