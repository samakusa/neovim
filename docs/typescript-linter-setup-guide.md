# NeovimへのTypeScript静的解析機能の導入ガイド

## 1. 全体像

NeovimでTypeScriptの静的解析（Lint）を有効にするには、2つの領域での設定が必要です。

1.  **TypeScriptプロジェクト側の設定**: 解析対象のプロジェクト自体に静적解析ツール（ESLint）とルールを定義します。
2.  **Neovim側の設定**: NeovimがプロジェクトのESLintと連携し、エディタ上でリアルタイムにフィードバックを表示できるように設定します。

この構成により、Neovimの設定は一度だけで、どのTypeScriptプロジェクトでも静的解析が機能するようになります。

## 2. 設定手順

### 2.1. TypeScriptプロジェクト側の設定

これは、静的解析を行いたい個々のTypeScriptプロジェクト（Webアプリ、ライブラリ等）のディレクトリで行う作業です。

1.  **Node.jsプロジェクトの初期化**:
    `package.json`（プロジェクトの依存関係や情報を管理するファイル）を作成します。
    ```bash
    npm init -y
    ```

2.  **ESLint関連パッケージのインストール**:
    静的解析に必要なツールを開発時依存としてインストールします。
    ```bash
    npm install --save-dev eslint typescript @typescript-eslint/parser @typescript-eslint/eslint-plugin
    ```

3.  **ESLint設定ファイルの作成**:
    プロジェクトのルートに`.eslintrc.json`を作成し、解析ルールを定義します。
    ```json
    {
      "root": true,
      "parser": "@typescript-eslint/parser",
      "plugins": [
        "@typescript-eslint/eslint-plugin"
      ],
      "extends": [
        "eslint:recommended",
        "plugin:@typescript-eslint/recommended"
      ]
    }
    ```

### 2.2. Neovim側の設定

これは、あなたのNeovim設定リポジトリ（この`neovim-settings`）で行う一度きりの作業です。

1.  **LSPサーバーのインストール**:
    `mason.nvim`などを利用して、`eslint-lsp`（パッケージ名は`eslint`）をグローバルにインストールします。

2.  **LSP設定ファイルへの追記**:
    `lsp_settings.lua`に、`eslint-lsp`をLSPクライアントとして登録する設定を追記します。

    ```lua
    -- lsp_settings.lua
    local lspconfig = require('lspconfig')

    -- ... 他サーバーの設定

    -- TypeScript向けのESLint-LSP設定
    lspconfig.eslint.setup{}
    ```

## 3. 重要な概念: Ruff (Python) と ESLint (TypeScript) の違い

なぜTypeScriptではプロジェクトごとに`eslint`のインストールが必要なのか、その背景を解説します。

| | Ruff (Python) | ESLint (TypeScript) |
| :--- | :--- | :--- |
| **アーキテクチャ** | 単一の実行可能バイナリ | コアエンジン + プラグイン |
| **動作** | LSPサーバー自体が解析能力を持つ | LSPサーバーはプロジェクトのESLintとプラグインを呼び出して使う |
| **プロジェクトへの**<br>**インストール** | 不要 | **必須** |

-   **Ruff**は、必要な機能がすべて詰まった自己完結型のツールです。そのため、グローバルにインストールされたLSPサーバーだけで、どのプロジェクトのコードも解析できます。

-   **ESLint**は、コアエンジンに、TypeScript用、React用といった様々な**プラグイン**を組み合わせて使う設計です。LSPサーバー(`eslint-lsp`)は、プロジェクトの`package.json`と`node_modules`を見て、そのプロジェクトで定義されたバージョンのESLint本体やプラグインを動的に読み込んで利用します。

この仕組みにより、ESLintはプロジェクトごとに最適なルールセットやバージョンを柔軟に適用できるという利点があります。これは、JavaScript/TypeScriptエコシステムの標準的なアプローチです。
