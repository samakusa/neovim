-- lewis6991/gitsigns.nvim の設定
--
-- Gitで変更のある行をsign column(番号列。init.vimの`set signcolumn=number`により
-- 番号列に統合表示される)+行全体の背景色(VSCode風)でハイライトし、
-- hunk単位でのプレビュー・移動・リセットを行うためのキーマップを提供する。
--
-- lsp_settings.luaのon_attach(LSPクライアントattach時にバッファローカルな
-- キーマップを設定する)と同様のパターンで、gitsignsがバッファにattachした際
-- (=そのバッファがgit管理下にある場合のみ)にバッファローカルキーマップを設定する。

require('gitsigns').setup({
  -- sign column(追加/変更/削除等のマーク)は既定で有効。
  signcolumn = true,
  -- 行全体の背景色も変更する(要件により、sign columnのみでなくVSCode風に
  -- 行背景も色付けする)。
  linehl = true,

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
    local display_enabled = true
    map('n', '<space>gt', function()
      display_enabled = not display_enabled
      gitsigns.toggle_signs(display_enabled)
      gitsigns.toggle_linehl(display_enabled)
    end)
  end,
})
