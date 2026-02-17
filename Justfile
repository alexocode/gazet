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

# Pre-commit gate: checks only — stash isolation handled by the global commit-msg hook
pre-commit:
    mix test --stale

# Pre-push gate: full test suite before pushing
pre-push: test
