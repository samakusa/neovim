-- lewis6991/gitsigns.nvim の設定
--
-- Gitで変更のある行をsign column(番号列。init.vimの`set signcolumn=number`により
-- 番号列に統合表示される)+行全体の背景色(VSCode風)でハイライトし、
-- hunk単位でのプレビュー・移動・リセットを行うためのキーマップを提供する。
-- 表示(sign column・行背景色)は起動直後は非表示(OFF)で、<space>gtキーで
-- 必要な時だけONにする運用にしている。
--
-- lsp_settings.luaのon_attach(LSPクライアントattach時にバッファローカルな
-- キーマップを設定する)と同様のパターンで、gitsignsがバッファにattachした際
-- (=そのバッファがgit管理下にある場合のみ)にバッファローカルキーマップを設定する。

require('gitsigns').setup({
  -- 起動直後は差分表示(sign column・行背景色)を非表示にしておく。
  -- 必要な時だけ<space>gt(下記on_attach内)で明示的にONにする運用。
  signcolumn = false,
  linehl = false,

  on_attach = function(bufnr)
    local gitsigns = require('gitsigns')

    local function map(mode, lhs, rhs, opts)
      opts = opts or {}
      opts.buffer = bufnr
      opts.noremap = true
      opts.silent = true
      vim.keymap.set(mode, lhs, rhs, opts)
    end

    -- 前後のhunkへジャンプ。
    -- lsp_settings.luaの[d/]d(診断のprev/next)と同じ「ブラケット+prev/next」の
    -- 慣習に合わせる。差分モード(:h 'diff')中は組み込みの[c/]cへフォールバックする
    -- (gitsigns公式サンプルと同じパターン)。
    map('n', ']c', function()
      if vim.wo.diff then
        vim.cmd.normal({ ']c', bang = true })
      else
        gitsigns.nav_hunk('next')
      end
    end)

    map('n', '[c', function()
      if vim.wo.diff then
        vim.cmd.normal({ '[c', bang = true })
      else
        gitsigns.nav_hunk('prev')
      end
    end)

    -- カーソル位置のhunkの差分をバッファ内にインライン表示(トグル。再実行で閉じる)。
    map('n', '<space>hp', gitsigns.preview_hunk_inline)

    -- カーソル位置のhunkを変更前(コミット済み)の内容に戻す。
    map('n', '<space>hr', gitsigns.reset_hunk)

    -- gitsigns自体の表示(sign column + 行背景色)のON/OFFをまとめてトグルする。
    -- gitsignsにはこれらをまとめて切り替える単一のAPIが無いため、
    -- toggle_signs()/toggle_linehl()を明示的なbool値で同期させて呼び出す
    -- (:h gitsigns.toggle_signs / :h gitsigns.toggle_linehl 参照)。
    -- 起動直後はsetup()側でsigncolumn/linehlともにfalse(非表示)にしているため、
    -- ここも false から始め、最初の<space>gtでON(true)になるようにする。
    local display_enabled = false
    map('n', '<space>gt', function()
      display_enabled = not display_enabled
      gitsigns.toggle_signs(display_enabled)
      gitsigns.toggle_linehl(display_enabled)
    end)
  end,
})

-- linehl(行背景色)用のGitSigns*Lnハイライトグループは、既定では(colorscheme側に
-- 専用定義が無い場合)DiffAdd/DiffChange等にリンクされ、これらは背景色だけでなく
-- 前景色(fg)も持つ。結果として変更行の文字が(colorscheme依存の)灰色等で塗り
-- つぶされ、シンタックスハイライトが読みにくくなる。
-- 「背景色は変更するが文字色は元のシンタックスハイライトのまま」にしたいため、
-- 現在解決されている背景色のみを引き継いだ形で各グループを再定義し、fgは
-- 一切指定しない(=そのグループ単体としてはfgを持たない状態にする。extmarkの
-- ハイライト合成では、指定していない属性は下層のシンタックスハイライトの値が
-- そのまま使われる)。
local function strip_linehl_fg()
  for _, name in ipairs({
    'GitSignsAddLn', 'GitSignsChangeLn', 'GitSignsChangedeleteLn', 'GitSignsUntrackedLn',
    'GitSignsStagedAddLn', 'GitSignsStagedChangeLn', 'GitSignsStagedChangedeleteLn', 'GitSignsStagedUntrackedLn',
  }) do
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    if hl.bg then
      vim.api.nvim_set_hl(0, name, { bg = hl.bg })
    end
  end
end

strip_linehl_fg()

-- gitsigns自身も`ColorScheme`イベントでこれらのハイライトを再定義し直す
-- (`:h gitsigns-highlight-groups`)。`:colorscheme`はハイライトを一旦クリアしてから
-- 再定義するため、上記の初回呼び出しだけではcolorscheme切り替え後にfgが復活して
-- しまう。gitsigns自身のColorSchemeオートコマンドより後に実行されるよう、
-- gitsigns.setup()呼び出しの後でこちらのオートコマンドを登録する
-- (同一イベントに対する複数グループのオートコマンドは登録順に実行される)。
vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('GitSignsLinehlFgFix', { clear = true }),
  callback = strip_linehl_fg,
})
