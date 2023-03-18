local api = vim.api
-- Note: The functions used here will be upstreamed eventually.
local ts_utils = require('nvim-treesitter.ts_utils')

local function get_children_nodes(node)
  local children = ts_utils.get_named_children(node);
  local result = {};

  for _, child in ipairs(children) do
    table.insert(result, child);
  end

  for _, child in ipairs(children) do
    local gc = get_children_nodes(child)
    for _, gc_child in ipairs(gc) do
      table.insert(result, gc_child);
    end
  end
  return result;
end

local function get_ast_nodes()
  local wininfo = vim.fn.getwininfo(api.nvim_get_current_win())[1]
  -- Get current TS node.
  local cur_node = ts_utils.get_node_at_cursor(0)
  if not cur_node then return end
  -- Get parent nodes recursively.
  local nodes = { cur_node }
  local parent = cur_node:parent()
  while parent do
    table.insert(nodes, parent)
    parent = parent:parent()
  end

  local next_node = ts_utils.get_next_node(cur_node, true, true)
  while next_node do
    table.insert(nodes, next_node)
    print(next_node)
    next_node = ts_utils.get_next_node(next_node, true, true);
  end

  local previous_node = ts_utils.get_previous_node(cur_node, true, true)
  while previous_node do
    table.insert(nodes, previous_node)
    previous_node = ts_utils.get_previous_node(previous_node, true, true);
  end

  local children = get_children_nodes(cur_node);
  for _, child in ipairs(children) do
    table.insert(nodes, child)
  end

  -- Create Leap targets from TS nodes.
  local targets = {}
  local startline, startcol
  for _, node in ipairs(nodes) do
    startline, startcol, _, _ = node:range()  -- (0,0)
    if startline + 1 >= wininfo.topline then
      local target = { node = node, pos = { startline + 1, startcol + 1 } }
      table.insert(targets, target)
    end
  end
  if #targets >= 1 then return targets end
end

local function select_range(target)
  local mode = api.nvim_get_mode().mode
  if not mode:match('n?o') then
    -- Force going back to Normal (implies mode = v | V | ).
    vim.cmd('normal! ' .. mode)
  end
  ts_utils.update_selection(0, target.node,
  mode:match('V') and 'linewise' or
  mode:match('') and 'blockwise' or
  'charwise'
  )
end

local function leap()
  require('leap').leap {
    targets = get_ast_nodes(),
    action = api.nvim_get_mode().mode ~= 'n' and select_range,  -- or jump
    backward = true
  }
end

return { leap = leap }
