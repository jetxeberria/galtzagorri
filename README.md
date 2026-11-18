# galtzagorri

[Copier](https://copier.readthedocs.io) template for new projects. Generated
projects share this repository's tooling: [just](https://just.systems) as the
task runner and [PDM](https://pdm-project.org) (with `use_uv = true`) for the
Python environment.

## Getting started

```bash
sudo apt install just   # bootstrap: everything else is installed by `just install`
just install            # system packages, user tools and the PDM environment
just                    # list recipes
```

## Tools

| Layer  | Installed by          | Tools                                                          |
|--------|-----------------------|----------------------------------------------------------------|
| System | `just install-system` | just, git, git-lfs, curl, jq, shellcheck, shfmt, clang-format, clang-tidy, xclip, wl-clipboard |
| User   | `just install-user`   | uv, pdm (`uv tool`), yamlfmt and gh (GitHub releases, checksum-verified) |
| Python | `just install-env`, `just sync` | ruff, yamllint, copier (+ pytest in projects), pinned in `pdm.lock` |

The shared recipes live in [template/tooling.just](template/tooling.just)
and are imported by both this repository's Justfile and the generated projects'.

## Creating a project

```bash
pdm run copier copy gh:jetxeberria/galtzagorri path/to/new-project
cd path/to/new-project
just init
```

Template answers: `project_name`, `project_description`, `github_or_gitlab`,
`python_min` (minimum Python, default the latest stable release). Every
project is a package, with `just build`, `just install-tool` (from the wheel)
and `just install-tool-editable` (from the sources). Requirements and their
reasons: [docs/SPECIFICATION.md](docs/SPECIFICATION.md).

## Updating a project

Run `just update` in the project: it merges the template changes with copier,
relocks `pdm.lock`, reinstalls and runs `just check`, so the result is ready to
commit. Projects keep their own dependencies apart from the template's `base`
group (see the generated README), so updates merge without conflicts.
