# List all commands
default:
    @just --list

# Run all tests
test:
    mix test

# Run only tests affected by recent changes (faster)
test-stale:
    mix test --stale

# Format code
format:
    mix format

# Pre-commit gate: run by the global TDD commit-msg hook.
# Tests only staged content — unstaged changes are stashed and restored.
pre-commit:
    #!/usr/bin/env bash
    set -uo pipefail
    before=$(git stash list | wc -l)
    git stash push --keep-index --quiet 2>/dev/null || true
    after=$(git stash list | wc -l)
    mix test --stale
    status=$?
    if [ "$after" -gt "$before" ]; then
        git stash pop --quiet 2>/dev/null || true
    fi
    exit $status

# Pre-push gate: full test suite before pushing
pre-push: test
