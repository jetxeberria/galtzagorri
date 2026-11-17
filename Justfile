set shell := ["bash", "-euo", "pipefail", "-c"]

# Same install / fmt / lint recipes as the projects generated from the template
import 'tooling.just'

# List available recipes
default:
    @just --list --unsorted

# Run every check, including rendering the template
check: fmt-check lint test-template
    @{{ info }} "all checks passed"

# Render the template (with uncommitted changes) for each output-changing answer and run its checks
test-template: (test-render "false") (test-render "true")

# Render the template with the given `packaged` answer into a temp dir and run its checks
test-render packaged:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ run }}
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    {{ info }} "packaged={{ packaged }}, a long description (copier wraps it in .copier-answers.yml); --vcs-ref HEAD includes uncommitted changes; removed on exit"
    run pdm run copier copy --defaults --vcs-ref HEAD \
        --data "packaged={{ packaged }}" \
        --data "project_description=A description longer than eighty columns, so that copier wraps it in the answers file" \
        . "$tmp/project"
    cd "$tmp/project"
    {{ info }} "git is needed: recipes list files with git ls-files"
    run git init
    run git add -A
    run just install-env
    run just check
    if [ "{{ packaged }}" = true ]; then
        {{ info }} "packaged: the build system must produce an sdist and a wheel"
        run just build
        run just --show install-tool
    fi
