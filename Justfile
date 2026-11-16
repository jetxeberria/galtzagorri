set shell := ["bash", "-euo", "pipefail", "-c"]

# Same install / fmt / lint recipes as the projects generated from the template
import 'template/just/tooling.just'

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
    {{ info }} "default answers; --vcs-ref HEAD includes uncommitted changes; removed on exit"
    run pdm run copier copy --defaults --vcs-ref HEAD . "$tmp/project"
    cd "$tmp/project"
    {{ info }} "git is needed: recipes list files with git ls-files"
    run git init
    run git add -A
    run just install-env
    run just check
