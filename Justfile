set shell := ["bash", "-euo", "pipefail", "-c"]

# Same install / fmt / lint recipes as the projects generated from the template
import 'tooling.just'

# List available recipes
default:
    @just --list --unsorted

# Run every check, including rendering the template
check: fmt-check lint test-template
    @{{ info }} "all checks passed"

# Render the template (with uncommitted changes) into a temp dir and run its checks
test-template:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ run }}
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    {{ info }} "default answers but a long description (copier wraps it in .copier-answers.yml); --vcs-ref HEAD includes uncommitted changes; removed on exit"
    run pdm run copier copy --defaults --vcs-ref HEAD \
        --data "project_description=A description longer than eighty columns, so that copier wraps it in the answers file" \
        . "$tmp/project"
    cd "$tmp/project"
    {{ info }} "git is needed: recipes list files with git ls-files"
    run git init
    run git add -A
    run just install-env
    run just check
    {{ info }} "project.just: the stub is valid (check ran with it); a recipe added to it is imported"
    printf '\n# Probe\nprobe:\n    echo probe\n' | run tee -a project.just
    run just --show probe
    {{ info }} "packaging (PKG-2): uv tools go to temp dirs, never the user's"
    export UV_TOOL_DIR="$tmp/uv-tools" UV_TOOL_BIN_DIR="$tmp/uv-bin"
    {{ info }} "no [project.scripts]: the install recipes succeed without installing"
    run just install-tool-editable
    run just uninstall-tool
    {{ info }} "a probe command: from the wheel, then from the sources (follows edits), then removed"
    printf '\n[project.scripts]\nprobe-cmd = "my_new_project:main"\n' | run tee -a pyproject.toml
    printf '\n\ndef main():\n    print("wheel")\n' | run tee -a src/my_new_project/__init__.py
    run just install-tool
    run test "$("$UV_TOOL_BIN_DIR/probe-cmd")" = wheel
    run just install-tool-editable
    run sed -i 's/print("wheel")/print("editable")/' src/my_new_project/__init__.py
    run test "$("$UV_TOOL_BIN_DIR/probe-cmd")" = editable
    run just uninstall-tool
    run test ! -e "$UV_TOOL_BIN_DIR/probe-cmd"
