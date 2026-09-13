-- <space>hp用の、折り返し(wrap)対応インライン差分プレビュー。
--
-- 背景: gitsigns.nvim標準のpreview_hunk_inline()は、削除された行の内容を
-- Neovimのvirt_lines(仮想行)機能で表示するが、virt_linesは「1エントリ=1画面行」
-- でしかなく、Neovim自身の通常のバッファテキストのような自動ソフトラップ機能を
-- 持たない。そのためウィンドウ幅を超える長さの削除行は、画面上で切り詰められて
-- しまい、内容の続きを確認できない不具合があった(実機のスクリーンショットで
-- 確認・調査済み)。
--
-- 原因の詳細: gitsigns自身はNeovim 0.11以降で`virt_lines_overflow = 'scroll'`を
-- 使っているが、:h api-extended-marksの記載通り、この'scroll'は該当ウィンドウの
-- 'nowrap'時にしか機能せず、このリポジトリの既定である'wrap'時は実質'trunc'
-- (切り詰め)と同じ挙動になる。Neovimのvirt_lines自体に「複数画面行に自動で
-- 折り返す」機能は存在しない(選択肢は'trunc'/'scroll'の2つのみ)。
--
-- 対応方針: 長い削除行を、あらかじめウィンドウの表示幅で複数の短い文字列に
-- 分割し、それぞれを別々のvirt_lines行として渡すことで、疑似的に「複数行に
-- 同時に折り返して表示される」状態を作る。
--
-- 設計方針(重要): gitsigns.nvimの非公開の内部モジュール
-- (gitsigns.deleted_preview / gitsigns.hunk_preview / gitsigns.render.virt 等)
-- には一切依存しない。この折り返し要望はこちら側の要望であり、gitsigns本体の
-- 将来のアップデートで無警告に壊れることのないよう、以下の「公開・文書化された
-- API」のみで完結させている:
--   - require('gitsigns').get_hunks(bufnr)   … 削除/追加行の内容取得(:h gitsigns.get_hunks())
--   - vim.diff()                              … 文字単位の差分計算(:h vim.diff())
--   - vim.api.nvim_buf_set_extmark()          … virt_linesの配置(:h api-extended-marks)
--   - vim.api.nvim_create_autocmd()           … カーソル移動時の自動クローズ
--
-- 単語(文字)単位の差分ハイライトは、gitsigns自身(gitsigns/diff_int.lua)が
-- 採用しているのと同じ手法(1文字ずつ改行区切りにしたテキストをvim.diff()に
-- 行単位diffとして渡す)を、コードを一切参照せず独自に実装している。この手法は
-- 文字単位ではなく実際にはバイト単位での分割になる(vim.split(s, '')や本実装の
-- 手動バイト分割は、日本語等のマルチバイト文字ではUTF-8のバイト列をそのまま
-- 分割するため)。有効なUTF-8バイト列同士の比較である限り実用上は正しく機能する
-- (gitsigns自身も同じ特性を持つ)。
--
-- 簡略化した点(意図的な設計判断):
--   - 削除行プレビューの行番号ガター相当の表示は省略している(実バッファの
--     折り返し継続行に行番号が付かないのと同様の考え方)。
--   - ウィンドウリサイズ時の自動再描画は行わない。リサイズ後は<space>hpを
--     再度押せば新しい幅で正しく再分割される。
--   - 単語単位の差分ハイライトは、削除行数と追加行数が1:1で対応する場合のみ
--     計算する(gitsigns自身のrun_word_diff()も同じ条件で単語差分をスキップする)。
--
-- 表示のON/OFFは<space>hw で切り替える(既存の差分表示全体トグル<space>gtとは
-- 別物)。OFF時は本来のgitsigns.preview_hunk_inline()(切り詰め版)を呼び出す。

local M = {}

local ns = vim.api.nvim_create_namespace('gitsigns_wrap_preview')

-- 既定はON(このリポジトリの目的そのものがこの折り返し表示のため)。
local wrap_enabled = true

--- 文字列を、Unicode文字単位の断片のリストに分解する(各断片が元の文字列の
--- どのバイト範囲に対応するかを記録する)。gitsigns/diff_int.luaのsplit_word_diff_line
--- は`vim.split(line, '')`で「1バイトずつ」に分割しているが(確認済み)、これは
--- 日本語等のマルチバイト文字ではハイライト範囲が文字の途中で切れてしまう
--- 危険がある。本実装では、代わりにNeovimの文字単位API(strcharpart)のみを
--- 使って安全に1文字ずつ分解し、後段のvim.diff()には文字単位の要素を渡す。
--- @param s string
--- @return {text:string, byte_start:integer, byte_end:integer}[]
local function char_pieces(s)
  local pieces = {}
  local nchars = vim.fn.strchars(s)
  local byte_offset = 0
  for i = 0, nchars - 1 do
    local ch = vim.fn.strcharpart(s, i, 1)
    pieces[#pieces + 1] = { text = ch, byte_start = byte_offset, byte_end = byte_offset + #ch }
    byte_offset = byte_offset + #ch
  end
  return pieces
end

--- 2つの文字列間の、文字単位の差分範囲をバイトオフセットで計算する。
--- gitsigns自身(diff_int.lua)が使う手法(文字ごとに改行区切りにしてvim.diff()に
--- 行単位diffとして計算させる)と同じ考え方だが、1文字ずつの分解に上記の
--- char_pieces()(strcharpart、Unicode文字単位で安全)を使う点が異なる。
--- @param a string 変更前
--- @param b string 変更後
--- @return {[1]:integer,[2]:integer}[] removed_regions aの中で変更/削除された範囲(0-indexed, end exclusive, バイトオフセット)
--- @return {[1]:integer,[2]:integer}[] added_regions bの中で変更/追加された範囲(0-indexed, end exclusive, バイトオフセット)
local function char_diff(a, b)
  if a == b then
    return {}, {}
  end
  local pieces_a, pieces_b = char_pieces(a), char_pieces(b)
  if #pieces_a == 0 and #pieces_b == 0 then
    return {}, {}
  end

  local function joined(pieces)
    if #pieces == 0 then
      return ''
    end
    local texts = {}
    for _, p in ipairs(pieces) do
      texts[#texts + 1] = p.text
    end
    return table.concat(texts, '\n') .. '\n'
  end

  local ok, hunks = pcall(vim.diff, joined(pieces_a), joined(pieces_b), { result_type = 'indices' })
  if not ok or not hunks then
    return {}, {}
  end

  local removed, added = {}, {}
  for _, h in ipairs(hunks) do
    local rs, rc, as_, ac = h[1], h[2], h[3], h[4]
    if rc > 0 then
      local first, last = pieces_a[rs], pieces_a[rs + rc - 1]
      if first and last then
        table.insert(removed, { first.byte_start, last.byte_end })
      end
    end
    if ac > 0 then
      local first, last = pieces_b[as_], pieces_b[as_ + ac - 1]
      if first and last then
        table.insert(added, { first.byte_start, last.byte_end })
      end
    end
  end
  return removed, added
end

--- textを、表示幅がmax_widthに収まるように複数の断片へ分割する。
--- マルチバイト文字(全角文字等)の途中では絶対に切断しない
--- (vim.fn.strcharpart/strdisplaywidthという文字単位のAPIのみを使って
--- 判定するため、UTF-8バイト列を手動で扱う必要がない)。
--- @param text string
--- @param max_width integer
--- @return {text:string, byte_start:integer, byte_end:integer}[]
local function split_by_width(text, max_width)
  if max_width < 1 then
    max_width = 1
  end
  local segments = {}
  local byte_offset = 0
  local remaining = text
  while true do
    if vim.fn.strdisplaywidth(remaining) <= max_width then
      segments[#segments + 1] =
        { text = remaining, byte_start = byte_offset, byte_end = byte_offset + #remaining }
      break
    end

    local nchars = vim.fn.strchars(remaining)
    local lo, hi, best = 1, nchars, 0
    while lo <= hi do
      local mid = math.floor((lo + hi) / 2)
      local part = vim.fn.strcharpart(remaining, 0, mid)
      if vim.fn.strdisplaywidth(part) <= max_width then
        best = mid
        lo = mid + 1
      else
        hi = mid - 1
      end
    end
    -- 1文字も収まらない極端に狭いウィンドウでも無限ループしないよう、
    -- 最低でも1文字は必ず進める。
    if best < 1 then
      best = 1
    end

    local piece = vim.fn.strcharpart(remaining, 0, best)
    segments[#segments + 1] = { text = piece, byte_start = byte_offset, byte_end = byte_offset + #piece }
    byte_offset = byte_offset + #piece
    remaining = remaining:sub(#piece + 1)
  end
  return segments
end

local BASE_HL = 'GitSignsDeleteVirtLn' -- gitsigns標準の「削除行」ハイライトグループ名を流用(見た目を揃えるため)
local WORD_HL = 'GitSignsDeleteVirtLnInLine' -- gitsigns標準の「削除行内の単語差分」ハイライトグループ名を流用
local ADDED_WORD_HL = 'GitSignsChangeInline' -- gitsigns標準の「変更後(追加)側の単語差分」ハイライトグループ名を流用

--- 1つの分割断片(segment)を、regions(元の行全体でのバイト範囲)に基づいて
--- 「通常ハイライト/単語差分ハイライト」の連続したチャンク列に変換する。
--- @param seg {text:string, byte_start:integer, byte_end:integer}
--- @param regions {[1]:integer,[2]:integer}[]
--- @param pad_width integer
--- @return {[1]:string,[2]:string}[]
local function build_segment_chunks(seg, regions, pad_width)
  local text = seg.text
  local base = seg.byte_start

  -- セグメント内に現れる境界点(バイトオフセット、セグメント先頭からの相対値)を集める。
  local points = { [0] = true, [#text] = true }
  for _, r in ipairs(regions) do
    local s = r[1] - base
    local e = r[2] - base
    if e > 0 and s < #text then
      if s > 0 and s < #text then
        points[s] = true
      end
      if e > 0 and e < #text then
        points[e] = true
      end
    end
  end

  local sorted = {}
  for p in pairs(points) do
    sorted[#sorted + 1] = p
  end
  table.sort(sorted)

  local chunks = {}
  for i = 1, #sorted - 1 do
    local s, e = sorted[i], sorted[i + 1]
    if e > s then
      local hl = BASE_HL
      for _, r in ipairs(regions) do
        local rs, re = r[1] - base, r[2] - base
        if s >= rs and e <= re then
          hl = WORD_HL
          break
        end
      end
      chunks[#chunks + 1] = { text:sub(s + 1, e), hl }
    end
  end

  if #chunks == 0 then
    chunks[1] = { '', BASE_HL }
  end

  if pad_width then
    local w = vim.fn.strdisplaywidth(text)
    if pad_width > w then
      chunks[#chunks + 1] = { string.rep(' ', pad_width - w), BASE_HL }
    end
  end

  return chunks
end

--- カーソル行を含むhunkをrequire('gitsigns').get_hunks()の結果から探す。
--- (gitsignsの非公開のカーソル位置hunk探索ロジックには依存せず、
--- 独自に実装したもの)
--- @param bufnr integer
--- @return table? hunk
local function get_hunk_at_cursor(bufnr)
  local ok, gitsigns = pcall(require, 'gitsigns')
  if not ok then
    return nil
  end
  local hunks = gitsigns.get_hunks(bufnr)
  if not hunks then
    return nil
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  for _, hunk in ipairs(hunks) do
    local s, c = hunk.added.start, hunk.added.count
    if c > 0 then
      if lnum >= s and lnum <= s + c - 1 then
        return hunk
      end
    else
      -- 純粋な削除hunk(added.count==0)。added.startは
      -- 「この行の直後で削除が発生した」ことを表す(0なら先頭行より前)。
      if lnum == s or lnum == s + 1 then
        return hunk
      end
    end
  end
  return nil
end

--- 削除行プレビューをどこに(above/belowどちら向きで)配置するかを求める。
--- get_hunks()が返すadded.start/added.count/typeのみから独自に導出したもの
--- (実機でtype='delete'の場合added.startが「削除の直前の行番号」を指すことを
--- 確認済み)。
---
--- 注意: `virt_lines_above = true` を行0(バッファ先頭行)に対して指定した場合、
--- 素朴な(ウィンドウにスコープしていない)extmarkでは実機で正しく描画されない
--- ことを確認済み(gitsigns本体はNeovimの非公開API`nvim__ns_set`でnamespaceを
--- ウィンドウにスコープすることでこれを回避しているが、本実装は非公開APIに
--- 依存しない方針のため採用しない)。そのため、バッファ先頭行が対象になる
--- 場合のみ`above = false`(その行の直後に表示)にフォールバックする
--- (視覚的な前後関係が他の行の場合と入れ替わる点は許容する)。
--- @param hunk table
--- @return integer row 0-indexed
--- @return boolean above
local function removed_placement(hunk)
  if hunk.type == 'delete' then
    if hunk.added.start == 0 then
      return 0, false -- ファイル先頭より前での削除(above=trueは行0で描画されないため)
    end
    return hunk.added.start - 1, false -- その行の直後(下)に表示
  end
  if hunk.added.start <= 1 then
    return 0, false -- change等でバッファ先頭行が対象の場合も同様にfalseへ
  end
  return hunk.added.start - 1, true
end

--- @param bufnr integer
local function clear_preview(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

--- hunk.removed.linesを、ウィンドウ幅で折り返した複数のvirt_lines行に変換する。
--- @param hunk table
--- @param width integer
--- @return {[1]:string,[2]:string}[][]? virt_lines
local function build_removed_virt_lines(hunk, width)
  local removed = hunk.removed.lines or {}
  if #removed == 0 then
    return nil
  end
  local added = hunk.added.lines or {}
  -- gitsigns自身のrun_word_diff()と同じく、削除/追加行数が1:1で対応する場合のみ
  -- 単語単位の差分ハイライトを計算する。
  local pair_word_diff = #removed == #added

  local virt_lines = {}
  for i, line in ipairs(removed) do
    local regions = {}
    if pair_word_diff then
      regions = select(1, char_diff(line, added[i] or ''))
    end
    local segments = split_by_width(line, width)
    for _, seg in ipairs(segments) do
      virt_lines[#virt_lines + 1] = build_segment_chunks(seg, regions, width)
    end
  end
  return virt_lines
end

--- 変更後(追加)側の実バッファテキストに、単語単位の差分ハイライトを付与する。
--- @param bufnr integer
--- @param hunk table
local function highlight_added_words(bufnr, hunk)
  local removed = hunk.removed.lines or {}
  local added = hunk.added.lines or {}
  if #removed ~= #added or #added == 0 then
    return
  end
  for i, added_line in ipairs(added) do
    local _, added_regions = char_diff(removed[i] or '', added_line)
    local row0 = hunk.added.start - 1 + (i - 1)
    for _, r in ipairs(added_regions) do
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row0, r[1], {
        end_row = row0,
        end_col = r[2],
        hl_group = ADDED_WORD_HL,
        priority = 200,
      })
    end
  end
end

--- <space>hpの実処理。wrap_enabledがfalseの場合は本来のgitsigns.preview_hunk_inline()
--- (切り詰め版)をそのまま呼び出す。
function M.preview_hunk_inline()
  local ok, gitsigns = pcall(require, 'gitsigns')
  if not ok then
    return
  end

  if not wrap_enabled then
    return gitsigns.preview_hunk_inline()
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local hunk = get_hunk_at_cursor(bufnr)
  if not hunk then
    return
  end

  clear_preview(bufnr)

  local win = vim.api.nvim_get_current_win()
  local width = vim.api.nvim_win_get_width(win)

  highlight_added_words(bufnr, hunk)

  local virt_lines = build_removed_virt_lines(hunk, width)
  if virt_lines and #virt_lines > 0 then
    local row, above = removed_placement(hunk)
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, -1, {
      virt_lines = virt_lines,
      virt_lines_above = above,
      virt_lines_leftcol = true,
    })
  end

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'InsertEnter', 'BufLeave' }, {
    buffer = bufnr,
    once = true,
    callback = function()
      clear_preview(bufnr)
    end,
  })
end

--- <space>hw: この折り返し表示自体のON/OFFをトグルする
--- (既存の<space>gt=gitsigns全体の表示トグルとは別物)。
function M.toggle_wrap_preview()
  wrap_enabled = not wrap_enabled
  vim.notify('gitsigns 折り返しプレビュー: ' .. (wrap_enabled and 'ON' or 'OFF'), vim.log.levels.INFO)
end

return M
