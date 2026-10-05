# terminal-dotfiles

Public slice of terminal tooling config: **WezTerm**, **herdr**, and **Neovim**.

## Install

```bash
git clone git@github.com:Jovian-Dsouza/terminal-dotfiles.git
cd terminal-dotfiles
git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/validate-no-secrets.sh

ln -sf "$(pwd)/.wezterm.lua" ~/.wezterm.lua
mkdir -p ~/.config/herdr
ln -sf "$(pwd)/.config/herdr/config.toml" ~/.config/herdr/config.toml
ln -sfn "$(pwd)/.config/nvim" ~/.config/nvim
```

## Validate before push

```bash
bash scripts/validate-no-secrets.sh
```

See [AGENTS.md](./AGENTS.md) for contributor and agent rules.
