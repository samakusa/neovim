-- Java用のLSPセットアップ(nvim-jdtls)。
-- 他言語(lsp_settings.luaの共通lspconfigループ)とは異なり、jdtlsはワークスペース
-- ディレクトリ(-data)をプロジェクト(root_dir)ごとに分離する必要があるなど特殊な要件が
-- あるため、nvim-jdtls自身のAPI(require('jdtls').start_or_attach)で個別にセットアップする。
-- ftplugin/java.lua は 'filetype plugin on'(Neovimの既定)により、Java用の
-- filetypeが設定されたバッファでNeovim自身が自動的に読み込む。

-- root_markers / extra_settings は「デフォルト + プロジェクトごとの上書き」という構造にする。
-- 上書きは vim.g.jdtls_project_overrides (プロジェクトルートに置く .nvim.lua から
-- 'vim.o.exrc = true' 経由で設定される想定。詳細は docs/基本設計書.md を参照)経由で行い、
-- vim.g.jdtls_project_overrides が未定義でもデフォルトのみで正常に動作すること。
local defaults = { root_markers = {'.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle'}, extra_settings = {}}
local overrides = vim.g.jdtls_project_overrides or {}
local root_markers = overrides.root_markers or defaults.root_markers
local extra_settings = overrides.extra_settings or defaults.extra_settings

local jdtls = require('jdtls')
-- lsp_settings.lua が定義する共通on_attach(キーマップ等)/capabilities(nvim-cmp連携)を
-- 再利用し、他言語のLSPと同様の挙動をJavaでも揃える。
-- (init.vimのlua << EOFブロックで既にrequire済みのため、ここでは副作用なく
-- キャッシュされたモジュールテーブルが返るだけ)
local lsp_settings = require('lsp_settings')

local root_dir = require('jdtls.setup').find_root(root_markers)
if not root_dir then
  -- ルートマーカーが見つからない場合は起動しない(単発のjavaファイルを開いただけ等)。
  return
end

-- jdtlsのワークスペース状態(-data)は、root_dirごとに完全に独立したディレクトリを
-- 使う必要がある(共有すると異なるプロジェクト間でワークスペース状態が衝突する)。
-- root_dirのパスをファイル名として安全な形にサニタイズし、
-- stdpath('cache')配下の専用ディレクトリ名として使う。
local project_name = vim.fn.fnamemodify(root_dir, ':t')
local workspace_id = root_dir:gsub('[/\\:]', '_')
local workspace_dir = vim.fn.stdpath('cache') .. '/jdtls-workspace/' .. project_name .. '_' .. workspace_id

-- jdtlsのデフォルト設定に、プロジェクトごとのextra_settingsをディープマージする。
local settings = vim.tbl_deep_extend('force', {
  java = {},
}, { java = extra_settings })

local config = {
  -- jdtls本体はPATH上のバイナリを利用する(lsp_settings.luaの共通ループと同様、brew install jdtls等で
  -- 別途導入する前提。このリポジトリの管理対象外)。
  cmd = { 'jdtls', '-data', workspace_dir },
  root_dir = root_dir,
  settings = settings,
  on_attach = lsp_settings.on_attach,
  capabilities = lsp_settings.capabilities,
}

jdtls.start_or_attach(config)
