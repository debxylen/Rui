local M = {}

function M.append(t, v)     table.insert(t, v) end
function M.extend(t, o)     for _, v in ipairs(o) do table.insert(t, v) end end
function M.strip(s)         return string.match(s, "^%s*(.-)%s*$") or "" end
function M.lower(s)         return string.lower(s) end
function M.str(v)           return string.format("%q", v) end
function M.charAt(str, i)   return str:sub(i, i) end
function M.startswith(s, p) return string.sub(s, 1, #p) == p end
function M.endswith(s, p)   return string.sub(s, -#p) == p end

return M
