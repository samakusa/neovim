-- Setup nvim-treesitter
local ts_ok, ts = pcall(require, 'nvim-treesitter.configs')
if ts_ok then
  ts.setup {
    ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "python" },
    sync_install = false,
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
  }
else
  vim.notify("Failed to load nvim-treesitter.configs", vim.log.levels.ERROR)
end

-- nvim-treesitter(アーカイブ済みmasterブランチ)の独自predicate/directive
-- (query_predicates.lua: set-lang-from-info-string!, set-lang-from-mimetype!等)は、
-- match[capture_id]を単一のTSNodeとして直接扱う実装になっているが、
-- 現在のNeovim(0.12.4)コアAPIではmatch[capture_id]はTSNodeの配列(table)になっている。
-- そのためnode:range()等の呼び出し時にクラッシュする
-- (```vue 等の言語タグ付きフェンスコードブロックや<script type="...">を含むMarkdown/HTMLで発生)。
-- ここではnvim-treesitter本体のadd_directive/add_predicate呼び出しを横取りし、
-- 渡されるmatchテーブルを単一ノード形式に正規化してから元のハンドラへ渡すことで、
-- 個々のdirective/predicateを一つずつ手直しせずに互換性を確保する。
-- 加えて、vueパーサーをMarkdownへの"子"言語として埋め込みハイライトすると
-- (孫言語の有無に関わらず)languagetree.lua内で別のクラッシュが発生するため、
-- set-lang-from-info-string!だけはvueを埋め込み対象から除外する。
-- markdown/injections.scm自体は複製しない。
do
  local query = require('vim.treesitter.query')
  local excluded_markdown_injection_langs = { vue = true }

  local function normalize_match(match)
    local normalized = {}
    for id, value in pairs(match) do
      normalized[id] = (type(value) == 'table' and value[1]) or value
    end
    return normalized
  end

  local orig_add_directive = query.add_directive
  query.add_directive = function(name, handler, opts)
    local original_handler = handler
    handler = function(match, pattern, bufnr, pred, metadata)
      original_handler(normalize_match(match), pattern, bufnr, pred, metadata)
    end
    if name == 'set-lang-from-info-string!' then
      local resolve = original_handler
      handler = function(match, pattern, bufnr, pred, metadata)
        local norm = normalize_match(match)
        local node = norm[pred[2]]
        if node then
          local injection_alias = vim.treesitter.get_node_text(node, bufnr):lower()
          if excluded_markdown_injection_langs[injection_alias] then
            return
          end
        end
        resolve(norm, pattern, bufnr, pred, metadata)
      end
    end
    orig_add_directive(name, handler, opts)
  end

  local orig_add_predicate = query.add_predicate
  query.add_predicate = function(name, handler, opts)
    local original_handler = handler
    handler = function(match, pattern, bufnr, pred)
      return original_handler(normalize_match(match), pattern, bufnr, pred)
    end
    orig_add_predicate(name, handler, opts)
  end

  -- 既にキャッシュ済みでも再登録させ、上のラッパーを確実に噛ませる
  package.loaded['nvim-treesitter.query_predicates'] = nil
  require('nvim-treesitter.query_predicates')
  query.add_directive = orig_add_directive
  query.add_predicate = orig_add_predicate
end
