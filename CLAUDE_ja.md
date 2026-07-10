# CLAUDE_ja.md

このファイルは、このリポジトリで作業する際にClaude Code（claude.ai/code）へガイダンスを提供するものです。

## このリポジトリについて

本リポジトリは、個人用のNeovimエディタ設定一式を管理するリポジトリであり、アプリケーションのコードベースではない。プラグイン設定、LSPによるコード補完・診断、シンタックスハイライト、IME自動切り替え、アウトライン表示、Markdown/HTMLプレビューなどを管理し、`deploy.sh`によって実際のNeovim設定ディレクトリ（macOS/Linuxでは`~/.config/nvim`、Windowsでは`~/AppData/Local/nvim`）へデプロイする。

詳細な設計書が`docs/基本設計書.md`にすでに存在するため、非自明な変更を行う前には機能とファイルの対応関係を含めてそちらを参照すること。`docs/typescript-linter-setup-guide.md`には、TypeScriptプロジェクトにおける（プロジェクト側・Neovim側の）両面にわたるESLint導入方法が説明されている。

## コマンド

- **設定を実際のNeovim設定ディレクトリへデプロイする**: `./deploy.sh`
  リポジトリルートから`$HOME/.config/nvim`へ`rsync -av --delete`で同期する。除外対象は`.git`、`node_modules`、`docs`、`.gitignore`、`package.json`、`package-lock.json`、`deploy.sh`。`--delete`オプションを使用しているため、実行環境の設定ディレクトリ内に存在しリポジトリには存在しないファイルは削除される点に注意。実行環境側に未追跡のローカル状態がある場合は、実行前に注意が必要。
- **Lint（TypeScriptのサンプル/設定用）**: `npx eslint .`（ルートの`.eslintrc.json`を使用。`eslint`/`typescript`/`@typescript-eslint/*`は`package.json`のdevDependenciesとして定義）
- テストスイートは存在しない（`npm test`はエラーを返すプレースホルダー）。ビルドステップもない。本リポジトリはVim script/Luaの設定ファイルをそのまま配布する構成である。

## アーキテクチャ

`init.vim`がエントリポイントであり、以下を担う。
- OS判定（`has('win32')` / `has('mac')` / それ以外）による、`g:dein_plugin_root_dir`、LSPバイナリパス（`g:ruff_lsp_cmd`、`g:pyright_lsp_cmd`、`g:powershell_es_module_path`）、`s:config_dir`の設定
- エディタ基本オプション（インデント、ステータスライン、クリップボード、検索 — `hlsearch`はデフォルトOFFで`<C-h>`によりトグル、行番号表示は`<C-n>`でトグル）
- 他の設定ファイルを**リポジトリ直下ではなく`s:config_dir`から**読み込む処理 — つまり`init.vim`は、他の設定ファイル群がすでにデプロイ済みであることを前提としている。したがって本リポジトリの設定を編集した場合、動作確認のためには`./deploy.sh`でデプロイする必要がある。`init.vim`内の`execute 'source' s:config_dir . '/...'`は、リポジトリ側の未デプロイな変更を反映しない点に注意。
- `package.path`に設定ディレクトリを追加し、`lsp_settings`と`treesitter_settings`を`require`する`lua << EOF ... EOF`ブロック

各ファイルの役割:
- `load_dein.vim` — dein.vimプラグインマネージャのブートストラップ（未導入時はdein.vim自体をclone）と、プラグイン一覧全体（Markdown、アウトライン/fzf、HTMLプレビュー、補完、treesitter/カラースキーム）を定義する。新規プラグインは`call dein#add(...)`で追加する。
- `load_ime_control.vim` — `InsertLeave`/`CmdlineLeave`時にIMEを自動的に英数入力モードへ切り替える。OSごとに分岐しており、Windowsでは`zenhan`、macOS/Linuxでは`im-select`を利用する（macOSでは`com.google.inputmethod.Japanese.Roman`を指定し、`im-select`の別途インストールが必要）。
- `lsp_settings.lua` — `nvim-cmp`と`nvim-lspconfig`のセットアップの一元管理箇所。全サーバーは`servers`テーブルで宣言され、単一のループでセットアップされる。サーバーごとの上書きは、`custom_cmds`（`cmd`のみを変更する場合）または`custom_opts`（`vim.tbl_deep_extend`でデフォルトにマージされる完全なオプションテーブルが必要な場合）に記述する。`on_attach`では共通のLSPキーマップ（`gd`、`gD`、`K`、`gi`、`gr`、`<space>rn`、`<space>ca`、`[d`/`]d`など）と、現在行の診断をフロート表示する`CursorHold`オートコマンドを定義している。別のオートコマンドグループ（`LspSymbolHighlight`）では、`textDocument/documentHighlight`をサポートする場合にカーソル下のシンボルをハイライトする。`jdtls`（Java）は`servers`リストには含まれているものの、実際のセットアップ処理はファイル末尾でコメントアウトされている — 有効化するには`jdtls_path`を環境ごとに調整する必要がある。`pyright`は診断機能を意図的に無効化している（`diagnosticMode = "off"`、かつ`publishDiagnostics`ハンドラを何もしない関数にしている）。これはPythonの診断には代わりに`ruff`を使用しているためであり、pyrightは補完など他の機能のためだけに残されている。
- `treesitter_settings.lua` — `nvim-treesitter`のハイライト設定。`init.vim`末尾で設定されている`molokai`カラースキームと組み合わせて使用する。これは、True Color非対応のターミナルでも動作するという理由で選定されたものである。
- `outline_settings.vim` — Vista.vimとctagsによるアウトラインサイドバー（`<C-k>`でトグル）。Markdownファイルタイプでは自動的に開き、Markdownの見出し検出用にctagsの呼び出しをカスタマイズしている。
- `markdown-preview-settings.vim` — 現状は折り畳み機能の無効化（`set nofoldenable`）のみを行う。実際のMarkdownプレビュープラグインの登録は`load_dein.vim`側にある。

## 変更時の注意点

- 複数OSへの対応が繰り返し登場する関心事である。`init.vim`と`load_ime_control.vim`はともにOSで分岐している。新たにOS依存の設定（パス、外部バイナリなど）を追加する場合は、同様の`has('win32')` / `has('mac')` / それ以外というパターンに従うこと。
- `lsp_settings.lua`に新しいLSPサーバーを追加する場合は、`servers`テーブルにサーバー名を追加する。デフォルトと異なる`cmd`や追加の`settings`/`handlers`が必要な場合のみ、`custom_cmds`/`custom_opts`に追記する。
- TypeScript/ESLintの静的解析は（PythonにおけるRuffとは異なり）プロジェクト側に依存する。LSPサーバーは各プロジェクト自体の`node_modules`/`package.json`を読み込むため、本リポジトリの`.eslintrc.json`と`package.json`はあくまで参考/サンプルであり、NeovimのLSP設定が直接依存しているものではない。詳細な理由は`docs/typescript-linter-setup-guide.md`を参照。
