# Plan: template-owned Justfile, project recipes in `project.just`

| | |
|---|---|
| **Status** | Proposed, awaiting approval |
| **Implements** | G-005 (OWN-1, JUS-1 in the [specification](../SPECIFICATION.md)); lantoki D-013 (DEV-4) |
| **Date** | 2026-11-18 |

## Starting point

Facts checked on 2026-11-18:

- `template/Justfile` ends with `# --- Project-specific recipes go below this line ---` (line 96). No other template file mentions the marker.
- just 1.21 accepts `import? 'missing.just'` (tested 2026-11-17).
- lantoki (branch `chore/adopt-galtzagorri`, not merged) has 12 recipes below the marker. Its `AGENTS.md` mentions "the Justfile above its project marker".
- harness-harvest has nothing below the marker. Its MDD says to add `lint-types` to "the project Justfile".

## Phases

Each phase is one commit citing G-005 (galtzagorri) or D-013 (lantoki).

### Phase 1: galtzagorri

1. `template/Justfile`: replace the marker with `import? 'project.just'` (after `packaging.just`), with a one-line comment.
2. `template/project.just`: a stub holding only a comment ("project-owned recipes; the template never changes this file").
3. `copier.yml`: `_skip_if_exists: [project.just]`.
4. `template/README.md.jinja`: one sentence saying project recipes go in `project.just`.
5. `test-render`: after `just check`, append a recipe to `project.just` and check that `just --show` finds it. This proves the import works, and that an empty stub is valid, since `just check` already ran with the stub.

**Check:** galtzagorri's `just check` (both `packaged` variants). Then commit and push.

**Experiment before pushing:** render with the previous commit, add a recipe to `project.just`, run `copier update` to the new commit, and confirm that `project.just` is untouched and the Justfile merges without conflicts.

### Phase 2: lantoki (on `chore/adopt-galtzagorri`)

`copier update` needs a clean tree, and a Justfile with project lines below the marker would conflict where the marker is removed. So the move comes first:

1. Move the 12 recipes from below the marker into `project.just`, and leave the Justfile exactly as the template rendered it. Commit.
2. `just update`. The Justfile then merges cleanly to the new version, and `project.just` already exists, so copier skips it. Commit.
3. `AGENTS.md`: "the Justfile above its project marker" becomes "the `Justfile`; lantoki's recipes are in `project.just`". This goes in the same commit as step 2.

**Check:**

- `just --list` shows the same recipes as before.
- `just check` passes.
- `just plan-user` output is identical to the 2026-11-17 baseline.
- A second `just update` is a clean no-op.

### Phase 3: harness-harvest

1. `just update`: nothing is below the marker, so it merges cleanly, and the stub `project.just` is created.
2. MDD: "add `lint-types` (mypy) to the project Justfile" becomes "to `project.just`".

**Check:** `just update` ends with *all checks passed*. Then commit and push.

## Risks

| Risk | Mitigation |
|---|---|
| Between the lantoki move commit and `just update`, the old Justfile does not import `project.just`, so lantoki's recipes are missing for one commit | Transient, on a branch. Phase 2 step 2 restores them, and the check verifies it. |
| `_skip_if_exists` also stops the stub from being re-created if a project deletes it | Intended: a missing `project.just` is valid (`import?`). |
| A project recipe named like a template recipe breaks `just` (duplicate definition) | Intended (JUS-1, OWN-2). The error names the recipe. |

## Out of scope

- galtzagorri's own root Justfile. It is not a generated project, so it keeps its recipes.
- Merging lantoki's branch into `master`. That still waits for the owner.
