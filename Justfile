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
    {{ info }} "on exit: the project's prod venv (PDM keeps it outside the project), then the temp dir"
    trap '(cd "$tmp/project" 2>/dev/null && pdm venv remove -y prod >/dev/null 2>&1) || true; rm -rf "$tmp"' EXIT
    version_in() { "$1" -c "import importlib.metadata as m; print(m.version('$2'))"; }
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
    {{ info }} "environments (ENV-1, ENV-2): a second sync keeps .venv"
    before=$(stat -c %Y .venv/pyvenv.cfg)
    run just sync
    run test "$before" = "$(stat -c %Y .venv/pyvenv.cfg)"
    prod=$(pdm venv --path prod)
    {{ info }} "the production venv has the package but no development tools"
    run "$prod/bin/python" -c "import my_new_project"
    if "$prod/bin/python" -c "import pytest" 2>/dev/null; then {{ warn }} "pytest leaked into prod"; exit 1; fi
    {{ info }} "a production dependency reaches both environments with one version"
    run just add six
    run test "$(version_in .venv/bin/python six)" = "$(version_in "$prod/bin/python" six)"
    {{ info }} "init steps (INI-1) except install, which needs sudo: init-git twice is a no-op"
    run just init-git
    run git status --short
    run just init-hook
    {{ info }} "init-ai without lantoki on PATH: warns and succeeds"
    {{ info }} "tooling.just puts \$HOME/.local/bin back on PATH, so HOME points to an empty dir too"
    mkdir -p "$tmp/home"
    no_lantoki=$(printf '%s' "$PATH" | tr ':' '\n' | while read -r d; do [ -x "$d/lantoki" ] || printf '%s:' "$d"; done)
    HOME="$tmp/home" PATH="$no_lantoki" run just init-ai 2>&1 | tee "$tmp/init-ai.log"
    run grep -q "lantoki not found" "$tmp/init-ai.log"
    {{ info }} "project.just: the stub is valid (check ran with it); a recipe added to it is imported"
    printf '\n# Probe\nprobe:\n    echo probe\n' | run tee -a project.just
    run just --show probe
    printf '\ninit-project:\n    echo project-init\n' | run tee -a project.just
    run just init-hook
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
    {{ info }} "the tool runs on the production versions (ENV-3)"
    run test "$(version_in "$UV_TOOL_DIR/my-new-project/bin/python" six)" = "$(version_in "$prod/bin/python" six)"
    run just install-tool-editable
    run sed -i 's/print("wheel")/print("editable")/' src/my_new_project/__init__.py
    run test "$("$UV_TOOL_BIN_DIR/probe-cmd")" = editable
    run just uninstall-tool
    run test ! -e "$UV_TOOL_BIN_DIR/probe-cmd"
    {{ info }} "removing the dependency removes it from both environments"
    run just remove six
    for py in .venv/bin/python "$prod/bin/python"; do
        if "$py" -c "import six" 2>/dev/null; then {{ warn }} "six still in $py"; exit 1; fi
    done
