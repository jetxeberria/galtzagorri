# galtzagorri — Specification

| | |
|---|---|
| **Status** | Active |
| **Owner** | jetxeberria |
| **Last change** | 2026-11-18 — G-005 (template-owned Justfile, project recipes in `project.just`) |

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

**PY-1. The minimum Python version is a template answer, `python_min`** (default: the latest stable release, `3.15`). It renders `requires-python = ">=X.Y"`, which `just install-python` reads. Updates never change it; raising it is a deliberate `just update --data python_min=3.X` on a branch.

> **Why.** The latest compatible version by default, without an upper bound nobody can justify. Kept in `.copier-answers.yml` so a template update cannot silently raise a project's minimum.

**UPD-1. `just update` leaves a working repository.** It merges the template (`update-template`: `copier update --defaults`, extra arguments passed through), then runs `update-sync` in a second `just` invocation, so it uses the recipes the merge brought in:

1. `update-conflicts`: stop if copier left conflict markers or `*.rej` files;
2. `install-python`: select the (possibly new) minimum Python;
3. `update-lock`: `pdm lock -G :all --update-reuse`;
4. `install-plugins`, `install-deps`, `install-hooks`;
5. `just check`.

After resolving conflicts, `just update-sync` resumes from step 1.

> **Why.** A merge alone can leave a stale lock or broken checks that surface later, in someone else's push. Ending with `just check` makes each update prove itself. `-G :all` is needed because `pdm lock --update-reuse` otherwise keeps the lock's old group list and misses groups the template adds; `--update-reuse` changes only what the new constraints require.

**PKG-1. Packaging is a template answer, `packaged`** (boolean, default `false`).

- `false`: `distribution = false`, no build system; the project is an application environment, not an installable package.
- `true`: `distribution = true`, a `[build-system]` using `pdm-backend`, and a template-owned `packaging.just` (imported by the Justfile with `import?`) with an `install-tool` recipe running `uv tool install --editable .`, which puts the project's `[project.scripts]` on `PATH`.

The project still declares its own `[project.scripts]`.

> **Why.** Some projects ship a CLI (lantoki, harness-harvest) and must be installable. Without the option they would have to edit template-owned lines (`distribution`, `[build-system]`), and every update touching them would conflict (OWN-1). The recipe lives in its own conditional file so the Justfile stays a plain, non-Jinja file; `import?` makes the import a no-op when the file is not rendered. `--editable` keeps the installed command in sync with the working tree.

**JUS-1. The Justfile is template-owned; project recipes live in `project.just`.** The generated `Justfile` holds only template recipes and imports, ending with `import? 'project.just'`. The template renders `project.just` once, as a stub with a comment and no recipes, and lists it in copier's `_skip_if_exists`, so `copier update` never touches it. A missing or empty `project.just` is valid. Recipe names must not repeat across the imported files (just rejects duplicates); a project tunes template recipes through tool configuration (OWN-2), not by redefining them.

> **Why.** With one Justfile split by a *project-specific recipes go below this line* marker, the template and the project edit the same file, and a template change near the marker conflicts (OWN-1). With the entry point owned by the template, `copier update` can always replace it, and the template can add imports later (as `packaging.just` needed, PKG-1) without editing a project-owned file. The reverse split (a project-owned Justfile importing a template file) was rejected for that reason: the template could never add an import line. `import?` keeps projects with no recipes of their own working; just runs imported recipes from the imported file's folder, which is the project root because `project.just` sits next to the Justfile.

**CHK-1. galtzagorri's own `just check` renders the template and runs the generated project's checks** for every supported answer combination that changes the output: `packaged=false` and `packaged=true` (the latter also builds the sdist and wheel). It runs with uncommitted changes (`--vcs-ref HEAD`) and before every push (pre-commit hook).

> **Why.** A template change is only correct if the projects it generates pass their own checks; rendering only the default answers would leave the packaged variant untested.

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
