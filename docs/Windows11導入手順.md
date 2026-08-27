# Windows 11導入手順

本ドキュメントは、本リポジトリ（`neovim-settings`）で管理しているNeovim設定を、**Windows 11環境**にゼロから導入するための手順書である。前提知識レベルや構成は`docs/基本設計書.md`・`docs/typescript-linter-setup-guide.md`に準じる。

## 0. 前提: ネイティブWindows Neovim を対象とする

Neovimは「WSL上で動かす」か「Windowsネイティブ版（`Neovim.Neovim`）を使う」かの2択があるが、本ドキュメントは**Windowsネイティブ版のNeovim**を対象とする。理由は本リポジトリ自体の実装にある。

- `init.vim`は`has('win32')`ブロックで、`~/AppData/Local/nvim-plugins/dein`や`~/AppData/Local/nvim-ruff/.venv/Scripts/ruff.exe`など、**Windowsネイティブのパス**（`AppData\Local`配下、`.exe`拡張子、`Scripts`ディレクトリ）を明示的に設定している。WSLで使うなら通常はこの分岐ではなく`else`（Linux扱い）側に入るため、これらのパスは使われない。
- `load_ime_control.vim`は`has('win32')`のときだけ`zenhan`（Windows専用のIME切り替えツール）を呼び出す設計になっている。WSL上のNeovim（Linuxバイナリ）は`has('win32')`が偽になるため、この分岐には到達しない。

つまり、このリポジトリはWindows上で使う場合に「ネイティブWindows版Neovim + zenhanによるIME制御」を前提に書かれている。したがって本ドキュメントもネイティブ版を対象に手順を組み立てる。

> WSL上でNeovimを使いたい場合は、`init.vim`のOS分岐が`else`（Linux/Unix扱い）に入り、`im-select`ベースのIME制御（Linux用、環境依存の調整が必要）やLinux向けパスに切り替わる。その場合は事実上「Linux環境への導入」に近くなり、本ドキュメントの手順（winget、`AppData`配下へのパス、zenhan等）はそのまま使えない。WSL運用を希望する場合は別途検討が必要。

以降、単に「Windows」と書いた場合はネイティブWindows環境を指す。

## 1. 前提条件・想定環境

- OS: Windows 11（`winget`が標準搭載されている前提。App Installerが未導入の場合はMicrosoft Storeから導入）
- PowerShell 7（`pwsh`）を利用する。Windows 11に標準搭載の Windows PowerShell 5.1 でも大半の手順は動くが、`lsp_settings.lua`の`powershell_es`設定が`pwsh`コマンドを直接呼び出す構成になっているため、PowerShell 7の導入は必須。
- 管理者権限のあるユーザーアカウント（一部インストール・シンボリックリンク作成で必要になる場合がある）
- 以下、コマンドは特記なき限り「Windows Terminal + PowerShell 7」を起動して実行する想定（`winget`によるインストール自体は通常のユーザー権限で完了するが、一部のツールでUACプロンプトが出ることがある）。

## 2. Neovim本体のインストール

`winget`でインストールする。

```powershell
winget install --id Neovim.Neovim --source winget
```

インストール後、新しいターミナルを開き、バージョンを確認する。

```powershell
nvim --version
```

Neovim on Windowsの設定ディレクトリ（`stdpath('config')`）は`%LOCALAPPDATA%\nvim`、すなわち`~/AppData/Local/nvim`である。これは`init.vim`内の`s:config_dir = expand('~/AppData/Local/nvim')`とも一致する。

## 3. 依存ソフトウェアのインストール

以下、`winget`で導入できるものはコマンドで、そうでないものは個別手順で示す。

### 3.1 Git（必須）

dein.vimのブートストラップ（`load_dein.vim`内の`git clone`）、および各種プラグイン取得に必要。

```powershell
winget install --id Git.Git --source winget
```

インストール後、新しいターミナルで`git --version`が通ることを確認する。Git for Windowsにはbash（Git Bash）も同梱されるが、本手順ではネイティブWindows前提のためPowerShellをメインに使う。

### 3.2 tree-sitter CLI + Cコンパイラ／ビルドツール（Treesitter用、必須）

`load_dein.vim`は`nvim-treesitter`を`{'rev': 'main'}`で固定している（2024年に全面書き換えされた新設計のブランチ。旧`master`ブランチは凍結済みでNeovim 0.12を公式サポート対象外のため、このリポジトリは`main`を前提にしている）。**`main`ブランチではパーサーのビルドが完全に外部の`tree-sitter` CLI（`tree-sitter build`コマンド）に委譲されており**、旧`master`ブランチのようにnvim-treesitter自身がCコンパイラを探して直接呼び出す仕組みは無い（nvim-treesitter公式README「Requirements」節、および`lua/nvim-treesitter/install.lua`のソースで確認済み）。したがって、Treesitterハイライトを機能させるには次の2つが**両方**必要になる。

#### (a) tree-sitter CLI本体

nvim-treesitter公式READMEの要件: `tree-sitter-cli`（0.26.1以上、**npm経由ではなくパッケージマネージャ経由でインストール**、と明記されている）。Windowsでは3.8節で導入するScoopの`main`バケットに`tree-sitter`という名前で存在し（パッケージ名は`tree-sitter-cli`ではなく`tree-sitter`）、2026年8月時点のマニフェストはバージョン0.26.12のため要件を満たす。Scoopをまだ導入していなければ、ここで先に入れてしまってよい。

```powershell
# Scoop未導入の場合のみ（PowerShellの実行ポリシーを一時的に緩和してインストーラを実行する）
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

scoop install tree-sitter
```

導入後、新しいターミナルで`tree-sitter --version`を実行し、`0.26.1`以上が表示されることを確認する。

#### (b) Cコンパイラ（`tree-sitter build`本体が使う）

`tree-sitter build`はRust製で、内部的に[`cc`クレート](https://docs.rs/cc/latest/cc/)を使ってCコンパイラを呼び出す。**`cc`クレートは`*-pc-windows-msvc`ターゲットでは既定でMSVC（`cl.exe`）を探しにいく**設計になっており（docs.rs/ccの「External configuration via environment variables」節）、`CC`環境変数等で明示的に上書きしない限り、他のコンパイラ（Zigなど）が`PATH`上にあっても自動的には使われない。**この点が`master`ブランチ時代と異なる**（`master`時代のnvim-treesitterは`cc`/`gcc`/`clang`/`cl`/`zig`を自前で順に探しており、`require("nvim-treesitter.install").compilers = {...}`という設定オプションでコンパイラを明示指定できたが、`main`ブランチではこのオプション自体が存在せず、指定しても何も起きない。nvim-treesitterのGitHub Discussion #7920でメンテナが「On main, we completely rely on `tree-sitter build`, which relies on the `cc` crate」と明言している）。Zigを導入済みのままこの点に気づかずWindowsで`main`ブランチへ移行すると、`cl.exe`が見つからずビルドに失敗する（nvim-treesitterのGitHub Issue #8147等で同種の報告あり）。

以下のいずれかを選ぶ。

**選択肢1（公式が明示的に推奨、確実だがダウンロードサイズが大きい）: Visual Studio Build Tools（C++によるデスクトップ開発）を導入する**

前述のGitHub Discussion #7920で、Windows向けにメンテナが明示的に案内している方法。

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --source winget --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

（`--override`に渡す引数はVisual Studio公式インストーラのコマンドラインパラメータ。Microsoft Learn公式ドキュメント「コマンド ライン パラメーターを使用して Visual Studio をインストールする」で確認済み。）導入後、新しいターミナルで`cl`を実行し、コマンドが見つかる（使用法のヘルプが出力される）ことを確認する。

**選択肢2（このリポジトリがこれまで案内していた軽量な方法を維持したい場合。非公式・自己責任）: Zig + `CC`/`CXX`環境変数**

Zigは`zig cc`というサブコマンドでC/C++コンパイラのドロップイン代替として動作する。`cc`クレートの`CC`環境変数は空白区切りのラッパー呼び出し（`sccache cc`のような形）を受け付けることがdocs.rs/ccに明記されているため、`CC`に`zig cc`をまるごと設定すれば動作させられる。ただし前述の通り、nvim-treesitterのメンテナ自身が「`CC`/`CFLAGS`をいじることは公式には推奨しない」と明言している非公式の方法であり、将来の`tree-sitter` CLIや`cc`クレートの変更で動作しなくなる可能性がある点に注意。

```powershell
winget install --id zig.zig --source winget
```

```powershell
# 新しいターミナルから有効になる（現在のセッションだけで試したい場合は $env:CC = "zig cc" と $env:CXX = "zig c++" を使う）
setx CC "zig cc"
setx CXX "zig c++"
```

導入後、新しいターミナルで`zig version`が通ることと、`$env:CC`/`$env:CXX`が設定されていることを確認する。

**この手順書としては選択肢1（Visual Studio Build Tools）を標準の推奨とする**が、既に旧版の本手順でZigのみを導入済みの環境では、選択肢2の環境変数設定を追加するだけで動く可能性がある。うまく動かない場合は選択肢1に切り替えること。

### 3.3 Node.js（必須）

`typescript-language-server`・`vim-language-server`・`vscode-langservers-extracted`（html/cssls/jsonls/eslint）のインストールに必要。（Markdownプレビューは`selimacerbas/markdown-preview.nvim`への乗り換えによりPure Lua実装となり、npm/Node.jsは不要になった。）

```powershell
winget install --id OpenJS.NodeJS.LTS --source winget
```

新しいターミナルで`node -v`・`npm -v`を確認後、必要なLSPサーバー群をグローバルインストールする。

```powershell
npm install -g typescript typescript-language-server
npm install -g vim-language-server
npm install -g vscode-langservers-extracted
```

- `typescript` / `typescript-language-server` → `lsp_settings.lua`の`ts_ls`（`custom_cmds`で`typescript-language-server --stdio`を明示）
- `vim-language-server` → `vimls`（同様に`custom_cmds`で明示）
- `vscode-langservers-extracted` → `html` / `cssls` / `jsonls` / `eslint`（この1パッケージだけで4サーバー分のバイナリが入る。実行ファイル名は`vscode-html-language-server` / `vscode-css-language-server` / `vscode-json-language-server` / `vscode-eslint-language-server`で、`lsp_settings.lua`の`eslint`サーバーはlspconfig側の既定`cmd`（`vscode-eslint-language-server --stdio`）をそのまま使う設定になっているため、追加設定は不要）

> **注意（旧版からの変更点）**: 以前の版の本ドキュメントでは`npm install -g vscode-eslint-language-server`という独立したコマンドを併記していたが、**そのようなnpmパッケージは存在しない**（`npm install -g vscode-eslint-language-server`を実行すると`npm error code E404`になる。2026年8月時点でnpmレジストリを確認済み）。`vscode-eslint-language-server`という名前の実行ファイルは、`vscode-langservers-extracted`パッケージ自身の`bin`に同梱されている（`vscode-langservers-extracted@4.10.0`の`package.json`で確認済み。nvim-lspconfigの`eslint`サーバーのドキュメントも同パッケージの導入のみを案内している）。したがって上記の`npm install -g vscode-langservers-extracted`を実行するだけでeslintサーバーも含めて導入が完了する。

> **`npm warn install-scripts`について（実行時の注意）**: 上記の`npm install -g vscode-langservers-extracted`実行時、以下のような警告が出ることがある。
> ```
> npm warn install-scripts 1 package had install scripts blocked because they are not covered by allowScripts:
> npm warn install-scripts   core-js@3.50.0 (postinstall: node -e "try{require('./postinstall')}catch(e){}")
> ```
> これは比較的新しいnpm（`allowScripts`機構がデフォルトで有効なバージョン。npm 12系以降）が、依存パッケージ（`vscode-langservers-extracted`が間接的に依存する`core-js`）のインストール後スクリプト（postinstall）を、明示的な許可がない限りデフォルトでブロックするというセキュリティ機能によるもの。**インストール自体やLSPサーバーの動作には影響しない**（実際に配布されている`core-js@3.50.0`の`postinstall.js`の中身を確認したところ、行っているのはコンソールへの支援・寄付案内バナーの表示のみで、`core-js`本体の機能やインストール結果には一切関与しない）。そのため**この警告は無視してよい**。バナー表示自体を有効化したい場合のみ、必要に応じて`npm install -g --allow-scripts=core-js vscode-langservers-extracted`を実行する（必須ではない）。

### 3.4 Python（必須。`ruff`・`pyright`用）

`init.vim`のWindows分岐は、`ruff`と`pyright-langserver`を**専用の仮想環境**（`~/AppData/Local/nvim-ruff/.venv`）配下の`.exe`から起動する設計になっている（`g:ruff_lsp_cmd` / `g:pyright_lsp_cmd`が絶対パスで固定されており、`lsp_settings.lua`側もそのパスをそのまま`cmd`に使う。PATH上の`ruff`/`pyright`コマンドを探す設計ではない）。この仮想環境の作成・Pythonバージョン管理には、Pythonをシステムに直接（グローバルに）インストールする方式ではなく、**`uv`**（Rust製の高速なPythonパッケージ/バージョン管理ツール）を利用する。

まず`uv`本体を導入する。

```powershell
winget install --id=astral-sh.uv -e
```

> wingetで導入できない場合は、公式のインストーラースクリプトでも導入できる。
> ```powershell
> powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
> ```

新しいターミナルで`uv --version`が通ることを確認する。

次に、`uv`でPythonのバージョンを導入する（`uv`はPython本体のダウンロード・バージョン管理も行うため、事前にPython本体を別途wingetで入れる必要はない）。

```powershell
uv python install 3.12
```

> **注意（Zscaler等のTLSインターセプト環境で`invalid peer certificate: UnknownIssuer`が出る場合）**: 社給PC等でZscaler Client Connectorのような通信検査(MITM)型のセキュリティ製品が導入されていると、このコマンドが証明書エラーで失敗することがある。原因と対処法は8節の該当項目にまとめているので、失敗した場合はそちらを参照。

続けて、`init.vim`が期待する既存のパス（`~/AppData/Local/nvim-ruff/.venv`）に、`uv venv`で仮想環境を作成する。

```powershell
uv venv "$env:LOCALAPPDATA\nvim-ruff\.venv" --python 3.12
```

作成した仮想環境に対して、`uv pip install`で`ruff`・`pyright`をインストールする（`--python`で対象の仮想環境のPythonインタプリタを明示することで、仮想環境をアクティベートしなくてもそこへインストールできる）。

```powershell
uv pip install --python "$env:LOCALAPPDATA\nvim-ruff\.venv\Scripts\python.exe" ruff pyright
```

インストール後、以下のパスに実行ファイルが存在することを確認する（`init.vim`のパス設定と一致させる必要がある）。

- `~/AppData/Local/nvim-ruff/.venv/Scripts/ruff.exe`
- `~/AppData/Local/nvim-ruff/.venv/Scripts/pyright-langserver.exe`

> **注意（`uv tool install`ではなくこの方式を選んだ理由）**: `uv`には`uv tool install ruff`のようにCLIツールをグローバルに導入する方式もあるが、その場合の実体は`uv`管理下の専用ディレクトリ（既定では仮想環境自体が`%APPDATA%\uv\data\tools`配下、呼び出し用の実行ファイル（シム）が`%USERPROFILE%\.local\bin`配下）に置かれ、`init.vim`が直接参照している`~/AppData/Local/nvim-ruff/.venv/Scripts/ruff.exe`という固定の絶対パスとは一致しない。本ドキュメントは`init.vim`（Neovim設定側）を変更しない前提のため、`uv venv`で従来と同じパスに仮想環境を作成し、そこへ`uv pip install --python`でインストールする方式を採用している。`init.vim`側のパス指定自体を`uv tool install`が使うパスに合わせて変更してもよいのであれば、`uv tool install`方式（および`uv tool update-shell`によるPATH登録）も選択肢になり得る。

### 3.5 Rust（`rust_analyzer`用。Rustを書かないなら任意）

```powershell
winget install --id Rustlang.Rustup --source winget
```

インストール後、新しいターミナルで以下を実行し、`rustup`経由で`rust-analyzer`コンポーネントを導入する。

```powershell
rustup component add rust-analyzer
```

### 3.6 clangd（C/C++用。使わないなら任意）

LLVM配布物に`clangd`が含まれる。

```powershell
winget install --id LLVM.LLVM --source winget
```

### 3.7 C#（`csharp_ls`用。使わないなら任意）

.NET SDKを導入したうえで、`dotnet tool`経由で`csharp-ls`を入れる。

```powershell
winget install --id Microsoft.DotNet.SDK.8 --source winget
dotnet tool install --global csharp-ls
```

`dotnet tool install --global`で入れたツールは`%USERPROFILE%\.dotnet\tools`に配置され、通常は自動的に`PATH`へ追加される（追加されていない場合は手動で`PATH`に加える）。

### 3.8 Java／jdtls（Javaを書かないなら任意・スキップ可）

`lsp_settings.lua`の`servers`テーブルには`jdtls`が含まれているが、これは「PATH上に`jdtls`コマンドがあれば動く」という前提であり、`jdtls`自体は本リポジトリの管理対象外（macOSでは`brew install jdtls`を利用している）。Windowsには`jdtls`のwinget配布は無いため、Scoopを使うのが簡便。

`jdtls`のScoopマニフェスト（`ScoopInstaller/Main`バケット）は、インストール時に「PATH上で見つかった`python.exe`を使って`jdtls`本体（Pythonスクリプト）を起動するシム」を作成する構成になっている。3.4節で導入した`uv`はPythonをグローバルPATHへ置かない設計（`ruff`/`pyright`は絶対パス参照）にしているため、**このままでは`Get-Command 'python.exe'`がWindows標準の「アプリ実行エイリアス」（実体のないダミー）を拾ってしまい、jdtlsのシムが実際には動作しない可能性がある**。そのため、Javaを実際に使う予定がある場合は、`scoop install jdtls`を実行する**前**に、以下の手順でPATH上に実体のある`python.exe`を用意しておく。

#### 事前準備: `uv`管理のPythonを`python.exe`としてPATHに公開する

3.4節で導入済みの`uv`を使い、`--default`オプション付きで再度Pythonをインストールする（`uv python install`は同じバージョンに対して再実行しても安全で、既にインストール済みなら`python`/`python3`という無印の実行ファイルを追加で公開するだけの処理になる）。

```powershell
uv python install 3.12 --default
uv python update-shell
```

- `--default`を付けると、バージョン番号付きの`python3.12.exe`（3.4節の`uv python install 3.12`だけでも既定でこちらは作られる）に加えて、無印の`python.exe`・`python3.exe`が`uv`の実行ファイル用ディレクトリ（Windowsでは既定で`%USERPROFILE%\.local\bin`）に作成される。これによって`Get-Command 'python.exe'`が実体のあるPythonを指すようになる。
- `uv python update-shell`は、上記のディレクトリをユーザーのPATH環境変数（Windowsの場合はレジストリ）に追加するuv公式のコマンド。実行後は、**新しいターミナルを開き直す**（Windows側がPATH変更を認識するまで反映されないことがあるため）。
- **`--default`の位置付けについて**: 2026年8月時点のuv公式ドキュメントでは、`--default`は依然として「experimental（実験的）」なオプションとして案内されている。将来のuvのバージョンで挙動が変わる可能性はあるが、現時点でuv公式ドキュメントに明記された正式なオプションであり、`uv`自体が管理するPythonの範囲内でPATHに公開する仕組みである点で、3.4節の「Pythonをグローバルに直接インストールしない」という本ドキュメントの方針とは矛盾しない（別途`winget`等で実Pythonを追加導入するよりも方針に沿う）。

#### 確認方法

新しいターミナルを開き直した上で、以下を確認する。

```powershell
(Get-Command python.exe).Source
```

結果が`%USERPROFILE%\.local\bin\python.exe`（またはそれに準じる、`uv`管理のPythonを指すパス）になっていればよい。もし`...\AppData\Local\Microsoft\WindowsApps\python.exe`のようなパスが返る場合は、アプリ実行エイリアスがまだ優先されている（`uv python update-shell`が未反映、またはターミナルを開き直していない可能性が高い）ので、ターミナルを開き直すか、PATHの並び順を確認する。

確認できたら、`jdtls`を（初めて）インストールする（Scoop自体が未導入の場合は、先に導入する）。

```powershell
# Scoop未導入の場合のみ（PowerShellの実行ポリシーを一時的に緩和してインストーラを実行する）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# jdtls本体（JDKも依存関係として入る）
scoop install jdtls
```

**既に`scoop install jdtls`を一度実行してしまっている場合（今回のように）**: シムは**インストール時点の`Get-Command`の解決結果を使って作成済み**のため、後からPATHを直しても、既存のシムは自動的には直らない。上記の事前準備を終えたあと、一度アンインストールしてから入れ直し、シムを作り直す必要がある。

```powershell
scoop uninstall jdtls
scoop install jdtls
```

再インストール後、`~\scoop\shims\jdtls.shim`の中身（`path = "..."`の行）を開き、`%USERPROFILE%\.local\bin\python.exe`のようなuv管理のパスを指していることを確認する。**これが唯一の確実な確認方法であり、後述の`WARN Overwriting shim`メッセージの有無では判断できない**（詳細は下記）。

> **参考: 再インストール時に`Remove-Item: ... An object at the specified path ...\jdtls.shim. does not exist.`というエラーが出る件について**: `scoop uninstall jdtls`のあとに`scoop install jdtls`を実行すると、`Running installer script...`の直後に、`core.ps1`の`Remove-Item -Path "$shim.$path_app" -Force -ErrorAction SilentlyContinue`という行に対するエラー（パス末尾が`jdtls.shim.`のようにドットで終わっている）と、続けて`WARN  Overwriting shim ('jdtls.exe' -> 'python.exe') installed from jdtls`という警告が表示されることがあるが、**これも無視してよい**。
> - **原因**: `shim`関数は、新しいシムを書き込む前に`warn_on_overwrite`という関数を呼び、既存の同名シムがあれば警告を出して退避（リネーム）する。このとき`$path_app`（新しいシムの参照先＝`python.exe`のパスから、Scoopの`apps`フォルダ配下の規約に沿ったアプリ名を抽出しようとする値）は、`python.exe`が`uv`管理のパス（`%USERPROFILE%\.local\bin`。Scoopの管理下ではない）であるため空文字列になる。空文字列になった結果、`"$shim.$path_app"`が`...\jdtls.shim.`という**末尾がドットで終わる不正な形のパス**になり、`Remove-Item`（本来は前回の退避ファイルを消すためのクリーンアップ目的）がこの奇妙なパスに対して失敗する。これはjdtls固有の問題ではなく、**ScoopInstaller/Scoop本体の既知のバグ**として実際にIssueが上がっている（`ScoopInstaller/Scoop` Issue #6194「An object at the specified path ... does not exist.」。同じく`warn_on_overwrite`関連で、末尾がドット/空拡張子になったパスに対する`Remove-Item`が同様のエラーを出す事例として報告されており、2026年8月時点で確認できた範囲ではまだ**Open（未修正）**）。
> - **なぜ`-ErrorAction SilentlyContinue`を指定しているのに表示されるのか**: 断定はできないが（Scoop側のIssueにも明確な原因分析は見当たらなかった）、`-ErrorAction`はコマンドレット自身が通常のエラーストリーム経由で報告する非終了エラーの表示を抑制するものであり、パスの形式そのものが不正であることに起因するファイルシステムプロバイダ側のエラー（末尾ドットのパス解決に関するもの）は、この抑制の対象外として表示されてしまう、という可能性が高い。
> - **実害の有無**: この`Remove-Item`は「前回の退避用ファイルを消す」ための後始末的な処理であり、そもそも`...\jdtls.shim.`という名前のファイルが実在することは想定されていない（実在しないので消せなくて当然、というのが実態に近い）。このあとに続く`Rename-Item`（既存の`jdtls.shim`を退避）や、`shim`関数本体による新しいシムファイルの書き込みは、この`Remove-Item`の成否に依存しておらず、実際にユーザーの環境でも直後に`Linking...`・`'jdtls' (...) was installed successfully!`と表示され正常終了している。**したがって対処不要、無視してよい。**
> - **`WARN Overwriting shim ('jdtls.exe' -> 'python.exe') installed from jdtls`の解釈について（訂正）**: このWARNは、「pythonの参照先が正しく修正された」ことを積極的に示す証拠には**ならない**、という点に注意が必要（当初はそう解釈できるかもしれないと考えていたが、`warn_on_overwrite`のソースを詳しく確認した結果、訂正する）。`$shim_app`（＝`installed from jdtls`の部分）は、シムファイル内の`args = "$dir\bin\jdtls"`という行（`$dir`はjdtls自身のScoopアプリフォルダを指す、Scoopの規約上のパス）から`get_app_name`関数が"jdtls"を抽出した結果であり、`python.exe`側の参照パスがWindowsアプリ実行エイリアスのままだったとしても、uvの正しいPythonに直っていたとしても、**このargsの行は常に"jdtls"を指すため、`$shim_app`は常に"jdtls"になる**。一方`$path_app`は前述の通り`python.exe`がScoopの`apps`フォルダ配下にない限り常に空文字列になる。つまり`$shim_app`（"jdtls"）と`$path_app`（""）は**常に一致せず**、このWARN自体は`python.exe`の参照先が壊れていても直っていても再インストールのたびに毎回表示される、ということが分かった。**したがって、このWARNの有無では「修正できたかどうか」は判断できず、`jdtls.shim`の`path = `行の中身を直接確認する方法（上記）でのみ確実に判断できる。**

> **参考: `scoop install jdtls`実行時に`InvalidOperation: ... You cannot call a method on a null-valued expression.`が出る件について**: `Running installer script...`の直後に、`$binaryReader.Close()`・`$fileStream.Close()`という2行に対する`InvalidOperation`エラーが表示されることがあるが、末尾で`'jdtls' (...) was installed successfully!`と表示されていれば、**この特定のエラー自体はインストール結果に影響しない（無視してよい）**。ScoopInstaller/Scoop本体（`lib/core.ps1`）のソースを直接確認した結果、原因と影響範囲は以下の通り。
> - **原因**: `jdtls`マニフェストの`installer.script`（`shim (Get-Command 'python.exe').Source $global jdtls "$dir\bin\jdtls"`）がScoopの`shim`関数を呼ぶ際、対象実行ファイルがGUIアプリかどうかをPEヘッダから判定するために内部で`Get-PESubsystem`関数を呼び出す。`Get-PESubsystem`は対象ファイル（解決された`python.exe`のパス）を`System.IO.FileStream`で読み込もうとするが、そのパスがアプリ実行エイリアス（実体は0バイトのNTFSリパースポイントで、通常のファイル読み込みでは開けない）を指していると例外が発生する。`catch`ブロックで`-1`を返して処理は続くが、`finally`ブロックの`$binaryReader.Close()`/`$fileStream.Close()`が未代入（`$null`）の変数に対して呼ばれるため、この2つのエラーメッセージが表示される。
> - **シム作成自体は失敗しない**: `shim`関数のソースを確認すると、シム本体（`jdtls.exe`とそのメタデータファイル`jdtls.shim`）の作成処理（`Copy-Item`や`path =`の書き込み）は、この例外を起こす`Get-PESubsystem`呼び出しより**前に**完了している。`Get-PESubsystem`の例外は、GUIサブシステム化（`Set-PESubsystem`呼び出し。対象がGUIアプリの場合のみ実行）をスキップさせるだけで、シム作成自体を失敗させない。したがって、このエラーメッセージ自体は無視してよい（実害があるのは、上記の「シムが指す`python.exe`が実体を持たない」という別の問題の方）。

#### 代替案（今回は不採用。参考として記載）

- **アプリ実行エイリアスを無効化する**: 設定 → アプリ → アプリの詳細設定 → アプリ実行エイリアス で`python.exe`/`python3.exe`のエイリアスをオフにする。`uv`側の対応を一切行わずに済むが、Windows全体の設定変更になり、他のツールが意図的にこのエイリアス経由の`python.exe`（Microsoft Store誘導）を期待している場合に影響する可能性がある。今回は3.4節との一貫性（`uv`側で完結させる）を優先し、この方式は採用しない。
- **`winget install --id Python.Python.3.12`等で別途実Pythonを導入する**: 確実に動くが、3.4節で「Pythonをグローバルに直接インストールする方式を避け、`uv`で管理する」という方針に切り替えた経緯と矛盾するため、今回は不採用。

Javaファイルを一切扱わない場合は、この節全体をスキップしてよい。その場合、Neovim起動時に`jdtls`用のLSPクライアント起動が失敗するログが出ることがあるが、他言語のLSPには影響しない。

### 3.9 PowerShell 7 + PowerShellEditorServices（`powershell_es`用）

まずPowerShell 7本体を導入する。

```powershell
winget install --id Microsoft.PowerShell --source winget
```

`lsp_settings.lua`の`powershell_es`は`pwsh`コマンドで`PowerShellEditorServices.Hosting.EditorServicesHost`を起動する構成であり、`init.vim`は`g:powershell_es_module_path = expand('~/AppData/Local/lsp-server/PowerShellEditorServices')`を参照する。VS Code拡張機能を経由せず、PowerShellEditorServicesの配布物（zip）を直接そのパスに展開する。

```powershell
$DownloadUrl = 'https://github.com/PowerShell/PowerShellEditorServices/releases/latest/download/PowerShellEditorServices.zip'
$ZipPath = "$env:TEMP\PowerShellEditorServices.zip"
$InstallPath = "$env:LOCALAPPDATA\lsp-server\PowerShellEditorServices"

New-Item -ItemType Directory -Force -Path "$env:LOCALAPPDATA\lsp-server" | Out-Null
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
Expand-Archive -Path $ZipPath -DestinationPath $InstallPath -Force
```

PowerShellを書かない場合でも、`servers`テーブルに`powershell_es`が含まれているため、未導入だと起動時にエラーログが出る点に注意（他言語のLSPには影響しない）。

### 3.10 lua_ls（Lua用。Neovim自体のLua設定編集にも便利なため導入推奨）

```powershell
winget install --id LuaLS.lua-language-server --source winget
```

### 3.11 Universal Ctags（`outline_settings.vim`のVista.vim用、必須）

`outline_settings.vim`は`g:vista_default_executive = 'ctags'`としており、アウトライン表示（`<C-k>`）にUniversal Ctagsを使う。

```powershell
winget install --id UniversalCtags.Ctags --source winget
```

### 3.12 fzf（`fzf.vim`用、実質必須）

`load_dein.vim`では`dein#add('junegunn/fzf', {'build': './install --all'})`としているが、この`build`はbashスクリプトであり、Windows上のdein（既定シェルがcmd.exe）ではそのまま実行できず失敗する。**この失敗は無視してよい** — `fzf.vim`は`fzf`という実行ファイルが`PATH`上にあれば動作するため、`junegunn/fzf`リポジトリ自身のインストールスクリプトが走らなくても、`fzf`本体を別途導入すれば問題ない。

```powershell
winget install --id junegunn.fzf --source winget
```

### 3.13 IME自動制御（`load_ime_control.vim`用、日本語入力を使うなら必須）

Windows分岐では`zenhan`コマンドを呼び出す（`IME_Off()`関数内の`system('zenhan 0')`）。`zenhan`はビルド済みバイナリの配布が主流ではないため、GitHubから取得してビルドするか、配布されているバイナリを利用し、`PATH`の通ったディレクトリ（例: `%LOCALAPPDATA%\Microsoft\WindowsApps`や自作の`%LOCALAPPDATA%\bin`を作成して`PATH`に追加）に`zenhan.exe`を配置する。

代表的な実装は以下（利用中のIME・環境に応じて選択）。

- https://github.com/iuchim/zenhan （オリジナル実装）
- https://github.com/kaz399/spzenhan.vim （派生版。`spzenhan.vim`同梱のexeを使う運用も可能）

#### `iuchim/zenhan`を選ぶ根拠

`iuchim/zenhan`のリポジトリを直接確認した結果、以下が分かった。

- **ライセンス**: `LICENSE`ファイルは[Unlicense](https://unlicense.org/)（パブリックドメイン相当）。著作権上の制約なく自由に利用・改変・再配布できる。
- **ソース本体**: `main.cc`1ファイルのみで、外部ライブラリ依存もWin32 API（`<windows.h>`、`GetForegroundWindow`・`ImmGetDefaultIMEWnd`・`SendMessage`）のみ。引数無しで実行すると現在のIME状態（0か1）を標準出力に返し、引数（`0`または`1`）を渡すとその状態に変更する、という非常に小さい実装。`load_ime_control.vim`の`system('zenhan 0')`はこの「引数ありでIME状態を変更する」使い方に対応している。
- **配布**: GitHub Releasesを確認したところ、`v0.0.1`（2019-08-22公開）の`zenhan.zip`が1件のみ存在する。ただしこのリポジトリには GitHub Actions等のビルドワークフロー定義が見当たらず、このビルド済みzipが具体的にどの環境でビルドされたか、第三者が公開情報から検証できる形にはなっていない。公開から7年以上経過している点も踏まえ、**可能であればソースからビルドする方が望ましい**と判断した（ソース自体は上記の通り小さく、ビルドの手間は大きくない）。
- **`iuchim/zenhan`を「最も一般的/公式」とみなす根拠**: リポジトリのREADMEが、VSCodeVimのIME自動切り替え機能（`vim.autoSwitchInputMethod`）の公式ドキュメントから参照されるツールとして書かれており、そこから見つかる実装であること、また本ドキュメントの旧版でも「オリジナル実装」として扱われていたこと（`kaz399/spzenhan.vim`は同じくUnlicenseで、`main.cc`もほぼ同種の実装だが、README上「派生版」の位置付け）から、`iuchim/zenhan`を基準とする。

#### ソースからビルドする（推奨）

3.2節で導入済みの`zig`を使えば、追加のツールを入れずにそのままビルドできる。`iuchim/zenhan`本体の`build.sh`はLinuxホストからmingw-w64のクロスコンパイラ（`x86_64-w64-mingw32-g++-win32`等）でビルドするCI向けスクリプトであり、Windowsネイティブ環境でそのまま実行することは想定されていないため、同等の内容（C++11、コンソールウィンドウを出さない`-mwindows`指定、`imm32`のリンク）をWindows上の`zig`向けに書き直したコマンドを使う。

```powershell
git clone https://github.com/iuchim/zenhan.git
cd zenhan
zig c++ -std=c++11 -mwindows main.cc -o zenhan.exe -limm32 -luser32
```

- `-mwindows`はGUIサブシステム化してコンソールウィンドウを表示させないための指定。`zig c++`はclangベースのフロントエンドであり、`-mwindows`はclang/mingw環境で使われる実績のあるフラグである（`iuchim/zenhan`の派生版`kaz399/spzenhan.vim`の`build.ps1`も、`clang++ -std=c++11 -mwindows main.cc -o spzenhan.exe -limm32 -luser32 -lmsvcrt -fuse-ld=lld-link`という、ほぼ同内容のコマンドで実際にビルドしていることをソースで確認済み）。ただし上記コマンド自体を筆者の環境で実機ビルド検証はできていない（未検証）。ビルドエラーになる場合は`-mwindows`を外して普通のコンソールアプリとしてビルドしても機能的には問題ない（`zenhan`呼び出し時に一瞬コンソールウィンドウが表示される可能性がある程度の違いで、IME切り替え自体の動作には影響しない）。
- Visual Studio Build Tools（`cl.exe`）を使う場合の代替コマンド例（3.2節の代替手段でVS Build Toolsを導入済みの場合。こちらも未検証）。`main.cc`は通常の`int main`を使っているため、GUIサブシステムにする場合は`/ENTRY:mainCRTStartup`の指定が必要になる。
  ```powershell
  cl.exe /EHsc /std:c++14 main.cc /Fe:zenhan.exe /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup Imm32.lib User32.lib
  ```

#### ビルド済みバイナリを使う場合（簡易だが非推奨）

上記の事情（検証可能なビルド元が無く、7年以上更新が無い）を許容できるなら、[Releasesページ](https://github.com/iuchim/zenhan/releases)から`zenhan.zip`をダウンロードして展開し、64bit環境なら`zenhan\bin64\zenhan.exe`（32bit環境なら`zenhan\bin32\zenhan.exe`）を使う方法もある。ライセンス上の問題はない（Unlicense）が、ビルド元を自分で検証できない点はソースビルドより劣る。

#### 配置

いずれの方法で`zenhan.exe`を用意した場合も、`PATH`の通ったディレクトリに配置する。

1. 任意のディレクトリ（例: `%LOCALAPPDATA%\bin`）を作成し、`zenhan.exe`を配置する。
2. そのディレクトリを`PATH`環境変数に追加する（設定 → システム → バージョン情報 → システムの詳細設定 → 環境変数、またはPowerShellで`[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:LOCALAPPDATA\bin", "User")`）。

#### 動作確認

新しいターミナルを開き直した上で、まず`zenhan`単体の動作を確認する。`main.cc`のソースを確認した限り、引数無しで実行すると現在のIME状態（`0`＝半角英数/オフ、`1`＝全角かな/オン）を標準出力に返すだけで状態は変更しない仕様なので、これでビルド・配置が正しいか確認できる。

```powershell
zenhan
```

エラーにならず`0`か`1`が返れば成功。次に、日本語IMEをオンにした状態で以下を実行し、実際に半角英数入力に切り替わるか確認する。

```powershell
zenhan 0
```

最後にNeovim上で確認する。日本語入力をオンにした状態で挿入モードに入り、何か入力してから`<Esc>`でノーマルモードに戻ったときに、自動的に英数入力へ切り替わるか確認する（7節の動作確認方法8番目の項目と同じ）。

IME自動切り替えが不要（英語配列オンリー等）であれば、この節はスキップしてよい。未導入でもNeovim自体の起動やLSP等の他機能には影響しない（`InsertLeave`時に`system('zenhan 0')`が失敗するだけ）。

### 3.14 Nerd Font（任意、推奨）

`treesitter_settings.lua` + `molokai`カラースキームの構成自体はTrue Color非対応ターミナルでも動く設計だが、Vista.vim（`outline_settings.vim`の`g:vista_icon_indent`）やfzf.vim系プラグインは装飾にNerd Fontのグリフを使うことがある。文字化けが気になる場合は導入する。

```powershell
winget install --id DEVCOM.JetBrainsMonoNerdFont --source winget
```

導入後、Windows Terminalの該当プロファイルの「フォント フェイス」で導入したNerd Fontを選択する。

## 4. リポジトリの取得

任意の作業用ディレクトリにこのリポジトリをclone、または既存のmacOS/Linux環境からリポジトリごと同期する。

```powershell
git clone <このリポジトリのURL> "$env:USERPROFILE\dev\neovim-settings"
```

以降、このディレクトリを`$SOURCE_DIR`と呼ぶ。

## 5. 設定ファイルの配置（`deploy.sh`のWindows代替）

`deploy.sh`はbashスクリプトであり、`rsync -av --delete --delete-excluded`でリポジトリ直下から`$HOME/.config/nvim`へ同期する。Windowsのネイティブ環境には`rsync`もbashも標準搭載されていないため、**そのままでは実行できない**。同等の処理をPowerShellで代替する。方式は2通りあり、どちらでもよい。

### 方式A: `robocopy`によるミラーコピー（`deploy.sh`と同じ「同期・削除」挙動、推奨）

`robocopy`の`/MIR`オプションは、コピー先に「コピー元に無いファイル」がある場合に削除するため、`rsync --delete`とほぼ同等の挙動になる。`deploy.sh`の除外リスト（`.git` / `node_modules` / `docs` / `.gitignore` / `package.json` / `package-lock.json` / `deploy.sh` / `.claude`）も`/XD`（ディレクトリ除外）・`/XF`（ファイル除外）で再現する。

```powershell
$SourceDir = "$env:USERPROFILE\dev\neovim-settings"
$DestDir   = "$env:LOCALAPPDATA\nvim"

New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

robocopy $SourceDir $DestDir /MIR `
  /XD ".git" "node_modules" "docs" ".claude" `
  /XF ".gitignore" "package.json" "package-lock.json" "deploy.sh"

Write-Host "Done."
```

`robocopy`は「1件でもコピー/削除が発生すると終了コードが1以上になる」ため、`$LASTEXITCODE -ge 8`のときのみエラーとみなす（0〜7は正常系）。CIやスクリプトに組み込む場合はこの点に注意する。

この方式は`deploy.sh`と同じく「コピー」であるため、設定を編集するたびに再実行が必要になる（`deploy.sh`と同じ運用）。

### 方式B: シンボリックリンク（編集の即時反映が欲しい場合）

`init.vim`は`s:config_dir`から各ファイルを`source`する設計であり、リポジトリを直接編集してもデプロイ先に反映されない（`CLAUDE.md`にも明記されている注意点）。個々のファイルをシンボリックリンクとして配置すれば、リポジトリの編集がそのままNeovim側に反映され、方式Aの再実行の手間を省ける。

Windowsでシンボリックリンクを作成するには、**管理者としてPowerShellを起動する**か、Windows 11の「開発者モード」（設定 → プライバシーとセキュリティ → 開発者向け）を有効にして`SeCreateSymbolicLinkPrivilege`を確保しておく必要がある（既定の標準ユーザーには無い権限のため）。

```powershell
$SourceDir = "$env:USERPROFILE\dev\neovim-settings"
$DestDir   = "$env:LOCALAPPDATA\nvim"

New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

$files = @(
  "init.vim",
  "load_dein.vim",
  "load_ime_control.vim",
  "lsp_settings.vim",
  "lsp_settings.lua",
  "treesitter_settings.lua",
  "outline_settings.vim",
  "markdown-preview-settings.vim",
  "markdown_preview_settings.lua"
)

foreach ($f in $files) {
  $target = Join-Path $SourceDir $f
  $link   = Join-Path $DestDir $f
  if (Test-Path $link) { Remove-Item $link -Force }
  New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
}
```

`deploy.sh`の除外対象（`.git` / `node_modules` / `docs` / `package.json`等）はそもそもリンクを作らないため、方式Bでも「デプロイ先に不要なファイルが混ざらない」という`deploy.sh`の意図は保たれる。ただしファイルを新規追加した場合はこのリスト（およびdein設定を読み込む`init.vim`側の`execute 'source'`呼び出し）への追記を忘れないこと。

## 6. 初回起動・プラグインインストール

配置が終わったら、新しいターミナルでNeovimを起動する。

```powershell
nvim
```

- 初回起動時、`load_dein.vim`が`dein.vim`本体を`g:dein_plugin_root_dir`（`~/AppData/Local/nvim-plugins/dein`）へ`git clone`し、続けて`dein#install()`が全プラグインを自動インストールする。ネットワーク環境によっては数分かかる。
- インストールログにエラーが出ないか確認する。特に`junegunn/fzf`の`build`（`./install --all`）はWindows上では失敗する想定だが、これは3.12節の通り無視してよい（`fzf`本体をwingetで導入済みであれば実害はない）。
- Treesitterのパーサーは`treesitter_settings.lua`の`FileType`autocmd（`nvim-treesitter`の旧`ensure_installed`/`auto_install`相当の自前実装）により、起動時によく使う言語（c/lua/vim/vimdoc/query/python）と、その後開いたfiletypeに対応するパーサーが自動でダウンロード・コンパイルされる。手動で全部入れたい場合は`:TSInstall all`や、設定済み言語のみなら`:TSUpdate`を実行する（いずれも3.2節のtree-sitter CLIとCコンパイラの両方が導入・PATH到達済みであることが前提）。
- **3.2節の対処が未完了（tree-sitter CLI未導入、またはCコンパイラが`tree-sitter build`から認識されない状態）のままだと、この自動インストールは失敗し続け、しかも`起動のたびに`同じダウンロード〜コンパイル試行が繰り返される**（`[nvim-treesitter/install/xxx]: Downloading ...`や`error: Error during "tree-sitter build": ... ENOENT ... 'tree-sitter'`のようなログが毎回出る）。これはnvim-treesitter側の仕様上の挙動であり、`treesitter_settings.lua`側の不具合ではない: 各パーサーの「インストール済み」判定はコンパイル成功時にのみ書き込まれる記録（リビジョンファイル）の有無で行われ、ビルドが失敗した場合はこの記録が残らないため、次回起動時も「未インストール」として毎回再試行される。3.2節の対処が完了すれば、次回以降はビルドが1度成功した時点でこのログは出なくなる。

## 7. 動作確認方法

1. **健全性チェック**: `:checkhealth`（または個別に`:checkhealth nvim-treesitter`）を実行し、`provider`・`treesitter`・`lspconfig`関連の項目にエラーが出ていないか確認する。`nvim-treesitter`の`main`ブランチのhealthcheckは`tree-sitter` CLI本体の有無とバージョン（3.2節の要件どおり0.26.1以上か）をチェックする項目を持つ（`lua/nvim-treesitter/health.lua`で確認済み）ので、ここで`tree-sitter-cli not found`や`tree-sitter-cli vX.Y.Z is required`のようなエラーが出ていないか確認する。ただしCコンパイラの検出可否まではこのhealthcheckではチェックされないため、Cコンパイラ側（3.2節の(b)）が正しく機能しているかは次項の実際のハイライト確認と、6節に記載した「起動のたびに同じダウンロード/コンパイルログが出ないか」で判断する。
2. **LSP動作確認**: 適当な`.py`/`.ts`/`.lua`ファイルを開き、`:LspInfo`でクライアントが`attached`になっているか確認する。`K`（ホバー）・`gd`（定義ジャンプ）・`<space>rn`（リネーム）などのキーマップ（`lsp_settings.lua`の`on_attach`参照）が動作するか試す。
3. **補完**: 何らかのコード入力中に`nvim-cmp`の補完ポップアップが出るか確認する。
4. **Treesitterハイライト**: `.py`や`.lua`ファイルを開き、シンタックスハイライトが`molokai`カラースキームで色付けされているか確認する。加えて、一度この確認ができたら**Neovimを再起動し、起動時に`[nvim-treesitter/install/...]: Downloading ...`のようなログや`ENOENT ... 'tree-sitter'`のようなエラーが再度出ないこと**を確認する。ここで出なくなっていれば、3.2節のtree-sitter CLI・Cコンパイラの両方が正しく機能しており、6節で説明した「起動のたびに再試行される」状態から抜けたことになる（出続ける場合は3.2節の(a)(b)いずれかが未完了）。
5. **アウトライン**: Markdownファイルを開き、自動でVistaのアウトラインが開くか、`<C-k>`でトグルできるか確認する（`outline_settings.vim`はUniversal Ctagsに依存するため、3.11節が正しく導入されていないと空になる）。
6. **Markdownプレビュー**: `.md`ファイルを開き`:MarkdownPreview`（`selimacerbas/markdown-preview.nvim`のコマンド。依存プラグイン`selimacerbas/live-server.nvim`が導入されていることが前提）でブラウザプレビューが立ち上がるか確認する。mermaid記法の図を含むMarkdownを開いた場合、図がインラインSVGとして描画され、クリックでズーム/パン可能なフルスクリーン表示になるかも合わせて確認する。見出しを含むMarkdownでは、画面右側に「☰ 目次」ボタン（`markdown_preview_toc.css`で追加した見出し一覧サイドバー、既定は閉じた状態）が表示され、クリックで開閉できること、一覧内の見出しをクリックすると本文の該当箇所へスクロールジャンプすることも確認する（公式サポート外の実装のため、`selimacerbas/markdown-preview.nvim`を更新した際は特に目視確認すること）。
7. **HTMLプレビュー**: `.html`ファイルを開き、`live-preview.nvim`のコマンド（例: `:LivePreview start`）でブラウザプレビューが立ち上がるか確認する。このプラグインはWindowsではバックエンドにPowerShellを利用する設計だが、追加インストールは不要（Windows標準搭載のPowerShellで動作する）。
8. **IME制御**: 日本語入力をオンにした状態で挿入モードに入り、`<Esc>`でノーマルモードに戻ったときに自動的に英数入力へ切り替わるか確認する（3.13節の`zenhan`が正しく`PATH`に通っている必要がある）。
9. **キーマップ**: `<C-n>`（行番号トグル）、`<C-h>`（検索ハイライトトグル）が動作するか確認する。

## 8. Windows特有の注意点・つまずきやすいポイント

- **パス区切り文字**: PowerShellの`Join-Path`や`expand()`（Vim script側）は内部でよしなに扱うため通常は問題にならないが、手作業でパスを組み立てる場合は`\`と`/`の混在に注意する。Vim scriptの`expand('~/AppData/Local/nvim')`はWindows上でも`/`のまま解釈されるため、`init.vim`の記述自体は変更不要。
- **シンボリックリンクの権限**: 方式B（5節）を使う場合、`SeCreateSymbolicLinkPrivilege`が無い標準ユーザーでは`New-Item -ItemType SymbolicLink`が失敗する。管理者としてPowerShellを実行するか、開発者モードを有効化する。
- **`system()`呼び出しとシェル**: `load_ime_control.vim`の`system('zenhan 0')`や`load_dein.vim`の`system('git clone ...')`は、Neovimの`'shell'`オプション（既定で`cmd.exe`）経由で実行される。`zenhan`や`git`が`PATH`に通っていないと、これらは（エラーメッセージを出すこともなく）静かに失敗することがあるため、`PATH`の確認は都度`where.exe <コマンド名>`で行うとよい。
- **dein系プラグインのbuildフック**: `junegunn/fzf`（`./install --all`）以外にも、bashスクリプトや`Makefile`をbuildフックに使っているプラグインはWindows上のdeinでは自動ビルドされないことがある。エラーログを都度確認し、失敗した場合は該当プラグインの配布バイナリを手動導入するか、Windows対応状況をプラグイン側のREADMEで確認する。
- **PowerShell実行ポリシー**: 既定の実行ポリシー（`Restricted`）のままだとスクリプト実行がブロックされることがある。Scoopの導入（3.8節）で`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`を使用しているが、これはシステム全体ではなく現在のユーザーのみに影響するスコープであり、比較的安全な設定である。
- **`init.vim`と`init.lua`の共存不可**: Neovimインストール直後に何らかのインストーラ（他のディストリビューション等）が`init.lua`の空ファイルを作っている場合、`init.vim`と`init.lua`が同時に存在するとNeovimが起動時にエラーを出す。`%LOCALAPPDATA%\nvim`配下を導入前に一度確認し、不要な`init.lua`があれば削除する。
- **Windows Defender / セキュリティソフトの影響**: `dein#install()`によるプラグインの大量git clone、Treesitterのパーサーコンパイル（`zig`/`cl`実行）は、リアルタイム保護のスキャン対象になり体感速度が落ちることがある。必要に応じて`%LOCALAPPDATA%\nvim-plugins`と`%LOCALAPPDATA%\nvim`をWindows Defenderの除外リストに追加すると改善する場合がある（セキュリティ上のトレードオフがあるため、社給PC等では情報システム部門のポリシーを確認すること）。
- **`.venv`のパス長・移動不可**: 3.4節で作成する仮想環境はパスに依存するフルパスの`.exe`を`init.vim`から直接参照する構成のため、後から`nvim-ruff`ディレクトリを移動するとリンク切れになる。移動した場合は`init.vim`の該当パスも合わせて修正するか、`.venv`を作り直す。
- **`uv python install`/`uv venv`が`invalid peer certificate: UnknownIssuer`で失敗する場合（Zscaler等のTLSインターセプト環境）**: 社給PCにZscaler Client Connectorのような、通信を一度復号して検査するTLS中間者検査(MITM)型のセキュリティ製品が導入されている場合、3.4節の`uv python install 3.12`（`python-build-standalone`のリリースをGitHubから取得する処理）や`uv pip install`等のダウンロードが`invalid peer certificate: UnknownIssuer`で失敗することがある。`UnknownIssuer`は「証明書の発行元（ルートCA）が信頼リストに存在しない」ことを示すエラーで、Zscalerが自身のルート証明書で通信を再署名する構成と機構的に一致する。
  - **原因**: `uv`（Rust製、rustls使用）は既定では**OSの証明書ストアを見ず**、`uv`にビルド時に組み込まれたMozillaのルート証明書セットのみを信頼する設計になっている（uv公式ドキュメント: 「By default, uv relies on bundled Mozilla root certificates for TLS verification rather than system-level certificate stores」）。そのため、WindowsのOS証明書ストアにZscalerのルート証明書が（IT部門により）インストール済みであっても、`uv`自身はそれを信頼しない。
  - **対処法1（まず試す）**: `--system-certs`フラグ、または環境変数`UV_SYSTEM_CERTS`を`true`に設定して実行すると、OSネイティブの証明書ストア（Windowsの場合は`rustls-platform-verifier`経由でWindowsの証明書ストアに委譲）を使う検証に切り替わる。
    ```powershell
    $env:UV_SYSTEM_CERTS = "true"
    uv python install 3.12
    ```
    これでOS側にインストール済みのZscalerルート証明書が信頼され、解決することが期待される。（`--system-certs`は`uv 0.11.0`より前の`--native-tls`フラグ/`UV_NATIVE_TLS`環境変数の後継で、`--native-tls`は非推奨扱いだが動作自体は同等。今後は`--system-certs`/`UV_SYSTEM_CERTS`を使うこと。）
  - **恒久化（毎回`--system-certs`を指定しなくて済むようにする）**: 対処法1で解決した場合、コマンドのたびに指定するのは煩わしいので、以下のいずれかの方法で恒久化できる（uv公式ドキュメントで確認済み）。**このユーザー（Windows環境全体でuvを使う・プロジェクト単位ではない）用途には、下記のうち方法A（ユーザーレベルの`uv.toml`）を推奨**する。理由は、設定ファイルを置くだけでその場から反映され新しいターミナルを開き直す必要がない点、および`uv`固有の設定として明示的に管理できる点（環境変数のように他のツールと名前空間を共有しない）。
    - **方法A（推奨）: ユーザーレベルの`uv.toml`に設定する**。uvはプロジェクト直下の設定（`uv.toml`/`pyproject.toml`の`[tool.uv]`）とは別に、ユーザーレベルの設定ファイル`%APPDATA%\uv\uv.toml`を読み込む（Windowsでのパスはuv公式ドキュメントで確認済み。優先順位はプロジェクトレベル＞ユーザーレベル＞システムレベルで、`uv tool`のようにユーザーレベルで動作するコマンド群はプロジェクトレベルの設定を無視してユーザーレベル・システムレベルの設定のみを読む、とも明記されている）。`uv python install`のような特定プロジェクトに紐付かない操作についても、ユーザーレベルの設定ファイルは読み込みチェーンに含まれるため、ここに設定しておけばWindows上のどのディレクトリで実行しても有効になる。
      ```powershell
      New-Item -ItemType Directory -Force -Path "$env:APPDATA\uv" | Out-Null
      Set-Content -Path "$env:APPDATA\uv\uv.toml" -Value "system-certs = true" -Encoding utf8
      ```
      設定後は`--system-certs`フラグや`$env:UV_SYSTEM_CERTS`の指定なしで、`uv python install`・`uv pip install`・`uv tool install`等すべてのuvコマンドでOSネイティブ証明書ストアが使われる。
    - **方法B（代替）: Windowsのユーザー環境変数として`UV_SYSTEM_CERTS`を永続化する**。`$env:UV_SYSTEM_CERTS = "true"`はそのPowerShellセッション内でのみ有効な一時的な設定だが、`setx`コマンドでユーザー環境変数として永続化できる。
      ```powershell
      setx UV_SYSTEM_CERTS "true"
      ```
      ただし`setx`で設定した環境変数は、**新しいターミナルを開き直すまで反映されない**（既存のターミナルセッションには適用されない）点に注意。GUIから設定する場合は「設定 → システム → バージョン情報 → システムの詳細設定 → 環境変数」からユーザー環境変数に`UV_SYSTEM_CERTS=true`を追加してもよい。
    - なお、プロジェクトの`pyproject.toml`の`[tool.uv]`セクションに書く方法も存在するが、これは特定のプロジェクトディレクトリ配下でのみ有効な設定であり、`uv python install`のようにプロジェクトに紐付かない操作全般には及ばない可能性が高い（uv公式ドキュメントは「`uv tool`のようなユーザーレベルで動作するコマンドはプロジェクトレベルの設定ファイルを無視する」と明記しており、`uv python install`が同様の扱いになるかは公式ドキュメント上に明示的な記載がなく未確認）。今回の「Windows環境全体で毎回有効にしたい」という用途には**そもそも不向き**なため、方法A・Bのどちらかを使うこと。
  - **設定が実際に反映されているか確認する方法**: `%APPDATA%\uv\uv.toml`を保存した後、それが本当に読み込まれているかを確認したい場合、以下の2段階で確認する。
    - **1. 診断コマンド・詳細ログでの確認（限定的）**: `uv`には、現在有効な設定内容や読み込んだ設定ファイルのパスを表示する専用サブコマンド（`uv config show`のようなもの）は**存在しない**（公式CLIリファレンスで確認済み）。`-v`/`-vv`（`--verbose`）で詳細ログを出す仕組みはあるが、既定の場所（`%APPDATA%\uv\uv.toml`等）から**自動検出された**設定ファイルの読み込みそのものをログ表示する機能は無いことを確認した。根拠: astral-sh/uvのIssue #17182「`--config-file`/`UV_CONFIG_FILE`の使用をverbose出力で見えるようにしてほしい」が2026年3月にPR #18353で対応・クローズ済みだが、これは**明示的に`--config-file`/`UV_CONFIG_FILE`を指定した場合のみ**ログに出す変更であり、既定の自動検出パスの読み込みをログ出力する機能ではない。また実際に手元の環境（uv 0.8.3）で`-v`/`-vv`付きで実行して確認したところ、ユーザーレベル設定ファイルの読み込みを示すログ行は出力されなかった。
      - 補足として、`uv.toml`に存在しないキー名（バージョンが古く`system-certs`に未対応、または単純なタイプミス等）を書いた場合は、`unknown field`エラーで**あらゆる`uv`コマンドの実行時に**即座に失敗する（これも手元で再現・確認済み）。したがって、設定ファイル保存後に何か`uv`コマンドを実行してエラーなく完了するなら、少なくとも「TOMLとして構文的に正しく、`system-certs`というキー名が使用中のuvバージョンで認識されている」ことは確認できる。ただし、これは値が実際に証明書検証に反映されていることの証明にはならない。
    - **2. 実地確認（推奨・最も確実）**: 上記の通り診断コマンドが無いため、`--system-certs`フラグや`$env:UV_SYSTEM_CERTS`を**指定せずに**、以前証明書エラーで失敗していたコマンドを再実行し、成功するかどうかで確認するのが最も確実な方法。理屈としても妥当（変えた条件は設定ファイルの有無だけなので、フラグなしで成功する＝設定ファイルが効いている、と言える）。ただし1点注意が必要:
      - `uv python install 3.12`は、そのバージョンが**既にインストール済みの場合は再ダウンロードを行わず**「既にインストール済み」という結果を返すだけで、ネットワーク／証明書検証を経由しない。そのため、一度`--system-certs`付きでインストールに成功した後にフラグ無しで同じコマンドを再実行しても、実際には検証を通っておらず「見かけ上成功した」だけになる可能性がある。
      - 確実に検証するには、既存のインストールを無視して強制的に再ダウンロードさせるか、未導入の別バージョンを試す。
        ```powershell
        # 既存のインストールを無視して強制的に再ダウンロードさせる
        uv python install 3.12 --reinstall
        # または、未導入の別バージョンで試す
        uv python install 3.13
        ```
        （`--reinstall`／`-r`フラグは手元で`uv python install --help`を実行して存在を確認済み。正確なオプション名は使用中の`uv`バージョンで`uv python install --help`を実行して確認するのが確実。）
      - いずれの方法でも、`--system-certs`フラグや`$env:UV_SYSTEM_CERTS`を明示指定しないコマンドが証明書エラー無く完了すれば、`%APPDATA%\uv\uv.toml`の`system-certs = true`設定が有効に働いている強い証拠になる。
  - **既知の限界**: ただし、Windows環境ではこの`--system-certs`（`--native-tls`）を指定しても`UnknownIssuer`エラーが解消しないという報告がuvのGitHub Issueに複数存在し、明確な解決策が示されていないケースもある。その場合は対処法2を試す。
  - **対処法2（対処法1で解決しない場合）**: Zscalerのルート証明書をWindowsの証明書ストアからPEM形式でエクスポートし（`certmgr.msc`を開き「信頼されたルート証明機関」からZscaler発行の証明書を探し、「Base-64 encoded X.509 (.CER)」形式でエクスポート後、拡張子を`.pem`にして使う）、環境変数`SSL_CERT_FILE`でそのファイルを明示的に指定する。
    ```powershell
    $env:SSL_CERT_FILE = "C:\path\to\zscaler-root.pem"
    uv python install 3.12
    ```
    `SSL_CERT_FILE`を設定すると、そのファイルに含まれる証明書のみが信頼され、既定のバンドルは使われなくなる（uv公式ドキュメントで明記）。Zscalerを経由しない接続先の検証も引き続き必要な場合は、標準的なCAバンドルにZscalerの証明書を追記した1つのPEMファイルを作る方が安全。
  - **対処法3（最終手段・非推奨）**: `--allow-insecure-host <ホスト名>`（例: `--allow-insecure-host github.com`）で証明書検証自体をスキップする方法もあるが、公式ドキュメントでも「信頼できるネットワーク環境でのみ使用すること」と明記されている、TLS検証を無効化する手段。恒久対応としては避けるべき。
  - **会社のセキュリティポリシーに起因する可能性**: 対処法1・2はいずれも個人のPowerShell環境変数設定だけで完結する対処だが、Zscalerの構成（インターセプト対象ドメインの範囲、ルート証明書の配布・更新方法）自体は情報システム部門のポリシーに依存する。対処法1・2を試しても解決しない場合、以前のSSH接続調査の際と同様に、個人の設定変更だけでは解決できない可能性があり、情報システム部門への確認が必要になることがある。
- **`deploy.sh`自体はWindows上では未使用**: 本リポジトリの`deploy.sh`はbash/rsync前提のため、Windows環境では5節の方式A/Bで代替する。`deploy.sh`をリポジトリから削除する必要はない（macOS/Linux側の運用でそのまま使われ続けるため）。

## 9. 参考情報源

- Neovim公式ドキュメント（`stdpath('config')`、Windows上の設定ファイルパス）
- `astral-sh/uv`公式ドキュメント（インストール方法、`uv python install`、`uv venv`、`uv pip install --python`、`uv tool install`の既定ディレクトリ、TLS証明書設定（`--system-certs`/`SSL_CERT_FILE`等））
- `ScoopInstaller/Scoop`本体のソース（`lib/core.ps1`の`shim`/`warn_on_overwrite`/`get_app_name`/`Get-PESubsystem`/`Set-PESubsystem`関数）、`ScoopInstaller/Main`バケットの`jdtls`マニフェスト（`scoop install jdtls`実行時の`InvalidOperation`エラー、再インストール時の`Remove-Item`エラーの原因調査）
- `ScoopInstaller/Scoop`のGitHub Issue #6194（`warn_on_overwrite`関連の`Remove-Item`が末尾ドットのパスで「does not exist」エラーを出す既知の未修正バグ）
- Windowsのアプリ実行エイリアス（App Execution Alias）に関する解説（`%LOCALAPPDATA%\Microsoft\WindowsApps`配下の`python.exe`等がNTFSリパースポイントである点について）
- `astral-sh/uv`のGitHub Issue（Windows + 企業プロキシ/TLSインターセプト環境での`invalid peer certificate: UnknownIssuer`関連の報告、`--system-certs`/`--native-tls`でも解消しない事例）
- `nvim-treesitter/nvim-treesitter`公式README「Requirements」節（`main`ブランチの`tree-sitter-cli`・Cコンパイラ要件）、および`lua/nvim-treesitter/install.lua`・`lua/nvim-treesitter/config.lua`・`lua/nvim-treesitter/health.lua`のソース（インストール処理が`tree-sitter build`に委譲されている点、インストール成否の判定方法、healthcheckの内容）
- `nvim-treesitter/nvim-treesitter`のGitHub Discussion #7920「Treesitter compiler setting in the 'main' branch」（`main`ブランチでは`compilers`オプションが機能しないこと、Windows向けにVisual Studio Build Toolsが公式推奨であること、`CC`/`CFLAGS`環境変数は非公式扱いであることのメンテナ回答）
- `nvim-treesitter/nvim-treesitter`のGitHub Issue #8147（Windows 11でZig導入済みでも`cl.exe`が見つからずパーサーインストールに失敗する報告）
- `docs.rs/cc`（Rust `cc`クレート）の環境変数ドキュメント（`CC`/`CFLAGS`の扱い、Windows `*-pc-windows-msvc`ターゲットでの既定のコンパイラ探索がMSVC/`cl.exe`前提であること）
- `ScoopInstaller/Main`バケットの`tree-sitter`マニフェスト（2026年8月時点でバージョン0.26.12、nvim-treesitterの要件0.26.1以上を満たすことの確認）
- Microsoft Learn公式ドキュメント「コマンド ライン パラメーターを使用して Visual Studio をインストールする」（`winget`の`--override`経由で`Microsoft.VisualStudio.Workload.VCTools`ワークロードをサイレントインストールする方法）
- `PowerShell/PowerShellEditorServices`公式リポジトリ（スタンドアロン導入手順）
- `selimacerbas/markdown-preview.nvim`公式README（Pure Lua実装でnpm/Node.js不要である点、依存プラグイン`selimacerbas/live-server.nvim`、`require("markdown_preview").setup({...})`の設定項目、mermaid図のズーム/パン/フルスクリーン表示/SVGエクスポートがブラウザUI標準機能である点）
- `selimacerbas/live-server.nvim`公式README（Pure Lua製ローカルWebサーバーで`markdown-preview.nvim`が内部的に利用する依存プラグインである点）
- `brianhuster/live-preview.nvim`公式README（Windows上ではPowerShellのみが追加要件）
- `junegunn/fzf.vim` / `junegunn/fzf` のWindows関連Issue（`./install --all`のbuildフックがWindows上で機能しない件）
- `iuchim/zenhan`（Windows向けIME切り替えツール。`main.cc`ソース本体、`LICENSE`〈Unlicense〉、`build.sh`、GitHub Releases一覧を直接確認）
- `kaz399/spzenhan.vim`（`iuchim/zenhan`の派生版。`build.ps1`〈`clang++`での実際のビルドコマンド〉を`zig c++`向けコマンドの妥当性確認の参考として確認）
- `ziglang/zig`リポジトリ（`lib/libc/mingw/lib32/imm32.def`の存在確認。zigのWindows向けビルドが`imm32`のインポートライブラリ定義をバンドルしていることの根拠）
- 各種winget パッケージID（`winget.run` / `winstall.app`で確認可能）
