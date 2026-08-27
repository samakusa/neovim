-- selimacerbas/markdown-preview.nvim の設定
--
-- 旧 iamcco/markdown-preview.nvim から乗り換え。乗り換えの理由:
--   - mermaid.js を CDN から動的ロードするため、同梱バージョンが古くなることがなく、
--     句読点・全角スペースを含むラベルでの描画エラーが解消される見込みがある。
--   - mermaid 図のクリックによるフルスクリーン表示・ズーム/パン・SVGエクスポートが
--     ブラウザUIに標準搭載されており、追加設定なしで利用できる。
--   - Pure Lua 実装で npm/Node.js 不要（依存プラグイン selimacerbas/live-server.nvim も同様）。
--
-- 見出し一覧(アウトライン)はNeovim側では既存の liuchengxu/vista.vim
-- (outline_settings.vim, <C-k>) を引き続き利用する。加えて、ブラウザプレビュー画面内でも
-- 見出し一覧からジャンプできるよう、custom_css オプションで markdown_preview_toc.css を
-- 読み込ませている。このファイルは「CSSファイルの中身を無加工のまま<style>として挿入する」
-- という custom_css の実装の隙を突いて、見出し一覧の折りたたみサイドバーをJavaScriptで
-- 注入する(公式サポート外の実装依存の方法。詳細はファイル冒頭のコメントを参照)。
--
-- コマンドは :MarkdownPreview / :MarkdownPreviewRefresh / :MarkdownPreviewStop で、
-- 旧プラグインと同名の :MarkdownPreview を引き続き使用できる。
--
-- オプション一覧は公式README(https://github.com/selimacerbas/markdown-preview.nvim)の
-- デフォルト値をそのまま明示している。mermaid図のズーム/パン/フルスクリーン/SVGエクスポートは
-- ブラウザUI側の標準機能であり、setup()側のオプションでの有効化は不要。
require('markdown_preview').setup({
  instance_mode = 'takeover',  -- 'takeover'(全Neovimインスタンスでタブ共有) or 'multi'(インスタンスごとに別タブ)
  port = 0,                    -- 0 = 自動 (takeoverでは8421)
  host = '127.0.0.1',          -- ローカルのみにバインド
  open_browser = true,         -- プレビュー開始時にブラウザを自動で開く

  content_name = 'content.md',
  index_name = 'index.html',
  -- ブラウザプレビュー内の見出し一覧サイドバー(JS注入)。stdpath('config')はOS別分岐なしで
  -- 常にNeovim設定ディレクトリを指す(init.vimのlua << EOFブロックと同じ考え方)。
  custom_css = vim.fn.stdpath('config') .. '/markdown_preview_toc.css',
  workspace_dir = nil,

  overwrite_index_on_start = true,

  auto_refresh = true,
  auto_refresh_events = {
    'InsertLeave', 'TextChanged', 'TextChangedI', 'BufWritePost'
  },
  debounce_ms = 300,
  notify_on_refresh = false,

  -- 'js' = ブラウザ同梱のmermaid.js(CDNから常に最新版をロード)。
  -- 'rust' は別途 mermaid-rs-renderer(cargo install)が必要な高速化オプションのため未使用。
  mermaid_renderer = 'js',

  default_theme = 'dark',

  yaml_mode = 'panel',

  allow_raw_html = true,

  scroll_sync = true,
  bottom_padding = 0.5,

  hooks = {
    on_start = nil,
    on_stop = nil,
  },
})
