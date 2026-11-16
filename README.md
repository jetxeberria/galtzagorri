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
| System | `just install-system` | just, git, git-lfs, curl, jq, shellcheck, shfmt, clang-format, clang-tidy |
| User   | `just install-user`   | uv, pdm (`uv tool`), yamlfmt (GitHub release, checksum-verified) |
| Python | `just install-env`    | ruff, yamllint, copier (+ pytest in projects), pinned in `pdm.lock` |

The shared recipes live in [template/just/tooling.just](template/just/tooling.just)
and are imported by both this repository's Justfile and the generated projects'.

## Creating a project

```bash
pdm run copier copy gh:jetxeberria/galtzagorri path/to/new-project
cd path/to/new-project
just init install
```
