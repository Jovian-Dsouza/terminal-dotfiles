# Agent instructions (public terminal dotfiles)

This repository is **public**. Treat every change as world-readable forever.

## Scope

Only maintain these configs (do not add unrelated dotfiles):

- `.wezterm.lua` — WezTerm
- `.config/herdr/config.toml` — herdr

Never add herdr runtime files: `*.log`, `.plugins.lock`, `release-notes.json`.

## Secret policy (mandatory)

Do **not** commit:

- API keys, tokens, passwords, private keys, `.env` files, credential JSON
- GitHub tokens (`ghp_`, `gho_`, `github_pat_`, etc.)
- AWS keys, Slack tokens, JWTs, or session cookies
- Personal email addresses, home paths, or hostnames unless the user explicitly wants them public

Use placeholders such as `YOUR_TOKEN_HERE` in examples only.

Before any commit or push, run:

```bash
bash scripts/validate-no-secrets.sh
```

## Git hooks

After clone, enable repo hooks once:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/validate-no-secrets.sh
```

`pre-push` runs the same validator locally so pushes are blocked if secrets are detected.

## CI

Every push and pull request runs:

1. `scripts/validate-no-secrets.sh`
2. [Gitleaks](https://github.com/gitleaks/gitleaks) via GitHub Actions

If validation fails, fix or revert the offending content before merging.

## Workflow for agents

1. Read only the files above unless the user expands scope.
2. Edit with minimal diffs; match existing style (tabs in Lua, TOML comments as in repo).
3. Run `bash scripts/validate-no-secrets.sh`.
4. Commit with a clear message; push only after validation passes.

If the user asks to sync from private yadm dotfiles, copy **only** the two config paths listed in Scope — never copy logs, lockfiles, or entire home-directory trees.
