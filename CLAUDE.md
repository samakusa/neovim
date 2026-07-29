# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a personal Neovim editor configuration repository (not an application codebase). It manages plugin config, LSP-based completion/diagnostics, syntax highlighting, IME auto-switching, outline display, and Markdown/HTML preview, and deploys them via `deploy.sh` to the real Neovim config directory (`~/.config/nvim` on macOS/Linux, `~/AppData/Local/nvim` on Windows).

A detailed design doc already exists at `docs/基本設計書.md` — read it for the full feature/file mapping before making non-trivial changes. `docs/typescript-linter-setup-guide.md` explains the two-sided (project + Neovim) ESLint setup for TypeScript projects.

## Commands

- **Deploy config to the live Neovim config dir**: `./deploy.sh`
  Uses `rsync -av --delete` from the repo root into `$HOME/.config/nvim`, excluding `.git`, `node_modules`, `docs`, `.gitignore`, `package.json`, `package-lock.json`, `deploy.sh`. Because of `--delete`, any file present in the live config dir but not in this repo gets removed — be careful before running it if the live dir has untracked local state.
- **Lint (TypeScript sample/config)**: `npx eslint .` (uses root `.eslintrc.json`; `eslint`/`typescript`/`@typescript-eslint/*` are devDependencies in `package.json`)
- There is no test suite (`npm test` is a placeholder that exits with an error) and no build step — this repo ships Vim script/Lua config files directly.

## Architecture

`init.vim` is the entry point and is responsible for:
- OS detection (`has('win32')` / `has('mac')` / else) to set `g:dein_plugin_root_dir`, LSP binary paths (`g:ruff_lsp_cmd`, `g:pyright_lsp_cmd`, `g:powershell_es_module_path`), and `s:config_dir`.
- Core editor options (indent, statusline, clipboard, search — `hlsearch` defaults OFF, toggled with `<C-h>`; line numbers toggled with `<C-n>`).
- Sourcing the other config files **from `s:config_dir`**, not from the repo directly — meaning `init.vim` expects the rest of the files to already be deployed alongside it. When editing config here, deploy (`./deploy.sh`) to test changes live, since `init.vim`'s `execute 'source' s:config_dir . '/...'` calls won't pick up unreleased repo edits in place.
- A `lua << EOF ... EOF` block that adds the config dir to `package.path` and requires `lsp_settings` and `treesitter_settings`.

File responsibilities:
- `load_dein.vim` — dein.vim plugin manager bootstrap (clones dein.vim itself if missing) and the full plugin list (Markdown, outline/fzf, HTML preview, completion, treesitter/colorscheme). Add new plugins here via `call dein#add(...)`.
- `load_ime_control.vim` — auto-switches IME to alphanumeric input on `InsertLeave`/`CmdlineLeave`, branching by OS: `zenhan` on Windows, `im-select` on macOS/Linux (macOS uses `com.google.inputmethod.Japanese.Roman`, requires `im-select` to be installed separately).
- `lsp_settings.vim` — Vim script globals related to LSP/syntax that must be set before the rest of the config loads (sourced from `init.vim` right after the OS-detection block, before `load_dein.vim`). Currently sets `g:java_ignore_markdown = 1` to work around an `E28` error when opening `.java` files, caused by `preservim/vim-markdown`'s bundled `syntax/markdown.vim` conflicting with `syntax/java.vim`'s Javadoc Markdown integration (see `:h ft-java-plugin`).
- `lsp_settings.lua` — single source of truth for `nvim-cmp` + `nvim-lspconfig` setup. All servers are declared in the `servers` table and configured in one loop; per-server overrides go in `custom_cmds` (just an alternate `cmd`) or `custom_opts` (full option table, merged over the defaults via `vim.tbl_deep_extend`). `on_attach` defines the shared LSP keymaps (`gd`, `gD`, `K`, `gi`, `gr`, `<space>rn`, `<space>ca`, `[d`/`]d`, etc.) and a `CursorHold` autocmd that floats diagnostics for the current line. A separate autocmd group (`LspSymbolHighlight`) highlights the symbol under the cursor via `textDocument/documentHighlight` when supported. `jdtls` (Java) is in the `servers` list and is set up through the generic loop like the other servers, using the default `jdtls` command — this requires a `jdtls` binary on `PATH` (installed separately, e.g. via `brew install jdtls`; not managed by this repo). A separate manual setup with a machine-specific `jdtls_path` is still left commented out at the bottom of the file as a sample but is unused/unnecessary since the generic loop already handles it. `pyright` has diagnostics deliberately disabled (`diagnosticMode = "off"`, and its `publishDiagnostics` handler is a no-op) because `ruff` is used for Python diagnostics instead — pyright is kept only for other features like completion.
- `treesitter_settings.lua` — `nvim-treesitter` highlight config; combined with the `molokai` colorscheme (set at the end of `init.vim`) specifically because it works without True Color terminal support.
- `outline_settings.vim` — Vista.vim + ctags outline sidebar (`<C-k>` toggles), auto-opens for Markdown filetypes, and customizes the ctags invocation for Markdown headings.
- `markdown-preview-settings.vim` — currently just disables folding (`set nofoldenable`); actual Markdown preview plugin registration lives in `load_dein.vim`.

## Notes for changes

- Multi-OS support is a recurring concern: `init.vim` and `load_ime_control.vim` both branch on OS. Any new OS-dependent setting (paths, external binaries) should follow the same `has('win32')` / `has('mac')` / else pattern.
- When adding a new LSP server in `lsp_settings.lua`, add its name to the `servers` table; only add to `custom_cmds`/`custom_opts` if it needs a non-default `cmd` or extra `settings`/`handlers`.
- TypeScript/ESLint analysis is project-side, not global (unlike Ruff for Python) — the LSP server reads each project's own `node_modules`/`package.json`, so `.eslintrc.json` and `package.json` in this repo are just a reference/sample, not something the Neovim LSP setup depends on directly. See `docs/typescript-linter-setup-guide.md` for the reasoning.
