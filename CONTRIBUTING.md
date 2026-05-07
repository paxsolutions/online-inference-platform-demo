# Contributing

Thank you for taking the time to contribute. This document covers the development workflow, commit conventions, and local tooling setup.

---

## Development Setup

**Prerequisites:** [uv](https://docs.astral.sh/uv/getting-started/installation/), Docker, Git.

### Install uv

```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# or via Homebrew
brew install uv
```

### Clone and set up the environment

```bash
# 1. Clone and enter the repo
git clone https://github.com/paxsolutions/online-inference-platform-demo.git
cd online-inference-platform-demo

# 2. Create a Python 3.12 virtual environment (must match Docker/CI — tokenizers
#    has no pre-built wheel for 3.13 and will fail to compile from source)
uv venv --python 3.12          # uv downloads 3.12 automatically if not found
source .venv/bin/activate      # Windows: .venv\Scripts\activate
uv pip install pre-commit

# 3. Install API dependencies into the venv (required for the pre-push test hook)
#    requirements-dev.txt is identical to requirements.txt but omits
#    torch==2.10.0+cpu which is a Linux-only wheel (Docker / CI use only)
uv pip install -r services/inference-api/requirements-dev.txt

# 4. Register the Git hooks
pre-commit install                            # pre-commit + commit-msg
pre-commit install --hook-type pre-push      # pytest gate on push
```

> The `.venv` directory is gitignored. The `pre-push` hook runs `pytest` using whatever Python is active in your shell — **ensure the venv is activated before pushing**.

Verify the hooks are wired up:

```bash
pre-commit run --all-files
```

---

## Branch Naming

| Prefix | Purpose |
|--------|---------|
| `feat/` | New feature |
| `fix/` | Bug fix |
| `docs/` | Documentation only |
| `refactor/` | Code restructuring, no behaviour change |
| `chore/` | Tooling, deps, CI, housekeeping |

Example: `feat/add-batch-inference-endpoint`

---

## Commit Conventions

This project follows [Conventional Commits](https://www.conventionalcommits.org/). The `commit-msg` hook enforces the format automatically.

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | When to use |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation changes only |
| `style` | Formatting, missing semicolons — no logic change |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `build` | Build system or dependency changes |
| `ci` | CI/CD configuration changes |
| `chore` | Routine tasks — version bumps, generated files |
| `revert` | Reverts a previous commit |

### Examples

```
feat: add batch inference endpoint
fix(cache): handle Redis timeout on cold start
docs: update API reference with NER examples
ci: add pre-push test hook
feat!: redesign inference response schema (breaking change)
```

### Breaking Changes

Append `!` after the type/scope, **or** add a `BREAKING CHANGE:` footer:

```
feat!: rename /infer to /predict

BREAKING CHANGE: the /infer endpoint has been renamed to /predict.
Update all clients accordingly.
```

Breaking changes trigger a **major** version bump in the automated release pipeline.

---

## Pre-commit Hooks

Hooks run automatically — you do not need to invoke them manually.

| Stage | Hook | What it does |
|-------|------|--------------|
| `pre-commit` | `trailing-whitespace` | Removes trailing whitespace |
| `pre-commit` | `end-of-file-fixer` | Ensures files end with a newline |
| `pre-commit` | `check-yaml` / `check-json` / `check-toml` | Validates config file syntax |
| `pre-commit` | `check-added-large-files` | Blocks files > 500 KB (prevents accidental model weight commits) |
| `pre-commit` | `detect-private-key` | Blocks accidentally committed secrets |
| `pre-commit` | `ruff` | Lint and auto-fix Python |
| `pre-commit` | `ruff-format` | Format Python |
| `commit-msg` | `conventional-pre-commit` | Validates commit message format |
| `pre-push` | `pytest` | Runs the full unit test suite |

To run all pre-commit hooks manually (useful before a PR):

```bash
pre-commit run --all-files
```

To bypass hooks in exceptional circumstances (e.g. a WIP push to a personal branch):

```bash
git commit --no-verify
git push --no-verify
```

> **Note:** Bypassed commits will still be caught by the CI lint and test jobs on GitHub Actions.

---

## Running Tests Locally

```bash
# Ensure the venv is active
source .venv/bin/activate

# Fast — mocks model and Redis, no Docker or torch needed
cd services/inference-api
pytest tests/ -v

# Or inside Docker (matches CI exactly, includes torch)
docker compose build inference-api
docker compose run --rm inference-api pytest tests/ -v
```

---

## Pull Request Checklist

Before marking a PR as ready for review:

- [ ] All pre-commit hooks pass (`pre-commit run --all-files`)
- [ ] Tests pass locally (`pytest tests/ -v`)
- [ ] Commit messages follow Conventional Commits
- [ ] New behaviour is covered by tests
- [ ] `README.md` or `CONTRIBUTING.md` updated if the change affects setup or usage

---

## Code Style

Ruff is configured in `ruff.toml` at the repo root. The same config is used by CI and the pre-commit hooks, so there are no surprises between local and remote.

Key rules enabled: `E` (pycodestyle), `F` (pyflakes), `W` (warnings), `I` (isort), `UP` (pyupgrade), `B` (bugbear), `S` (bandit security).
