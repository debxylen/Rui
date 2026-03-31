-- ——— lightweight XML for luau ———————————————————————————
--
-- ported from a Python ElementTree-style API, but trimmed down to preserve my sanity
-- supports:
--   * elements and attributes
--   * nested children
--   * text and tail
--   * XML entities (&lt; &gt; &amp; &quot; &apos; and numeric refs)

local M      = {}
local std    = require(script.Parent.std)

local append, extend = std.append, std.extend
local charAt         = std.charAt

M.VERSION    = "1.3.0-lua"

-- ——— internal helpers ——————————————————————————————————————

local function copy_table(t)
    local out = {}
    if t then for k, v in pairs(t) do out[k] = v end end
    return out
end

local function line_info(src, pos)
    if not src or not pos or pos <= 0 then return 1, 1 end

    local sub          = string.sub(src, 1, pos)
    local _, lines     = string.gsub(sub, "\n", "")
    local last_newline = string.find(sub, "\n[^\n]*$")

    return lines + 1, last_newline and (pos - last_newline) or pos
end

local function craft_message(msg, pos, src)
    local line, col = line_info(src, pos)
    local err       = { position = pos or 0, line = line, column = col, message = msg, source = src }

    return setmetatable(err, {
        __tostring = function(self)
            local res = self.position > 0 and 
                string.format("ParseError at line %d, col %d (byte %d): %s", self.line, self.column, self.position, self.message) or
                "ParseError: " .. self.message

            if self.source and self.line then
                local lines = {}
                for l in string.gmatch(self.source .. "\n", "(.-)\n") do append(lines, l) end

                local start_line, end_line = math.max(1, self.line - 2), math.min(#lines, self.line + 2)
                res ..= "\n\n"
                for i = start_line, end_line do
                    local prefix = (i == self.line) and " > " or "   "
                    res ..= string.format("%s%d | %s\n", prefix, i, lines[i])
                    if i == self.line and self.column then
                        res ..= string.format("     | %s^\n", string.rep(" ", self.column - 1))
                    end
                end
            end
            return res
        end,
    })
end

local function raise(msg, pos, src) error(craft_message(msg, pos, src), 0) end

local function decode_entities(s)
    if not s or s == "" then return s end

    s = s:gsub("&(#x[%da-fA-F]+);", function(hex)
        local n = tonumber(hex:sub(3), 16)
        return n and utf8.char(n) or ""
    end)

    s = s:gsub("&(#[%d]+);", function(dec)
        local n = tonumber(dec:sub(2), 10)
        return n and utf8.char(n) or ""
    end)

    local entities = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }
    return s:gsub("&([%a_][%w_.:-]*);", function(name) return entities[name] or ("&" .. name .. ";") end)
end

-- ——— core element class —————————————————————————————————————

local Element   = {}
Element.__index = Element

function Element:new(tag, attrib, extra)
    local self = setmetatable({
        tag       = tag,
        attrib    = copy_table(attrib or {}),
        text      = nil,
        tail      = nil,
        _children = {},
    }, Element)

    if extra then for k, v in pairs(extra) do self.attrib[k] = v end end
	
    return self
end

function Element:makeelement(tag, attrib) return Element:new(tag, attrib) end
function Element:__len()                   return #self._children end

function Element:__index(key)
    if type(key) == "number" then return self._children[key] end
    return Element[key]
end

function Element:append(sub)
    if getmetatable(sub) ~= Element then raise("expected an Element", 0) end
    append(self._children, sub)
end

function Element:extend(els)            extend(self._children, els) end
function Element:insert(idx, sub)       table.insert(self._children, idx, sub) end
function Element:remove(sub)
    for i, el in ipairs(self._children) do
        if el == sub then table.remove(self._children, i); return end
    end
    raise("subelement not found", 0)
end

function Element:clear()
    self.attrib    = {}
    self._children = {}
    self.text      = nil
    self.tail      = nil
end

function Element:get(key, fallback)     return self.attrib[key] or fallback end
function Element:set(key, value)        self.attrib[key] = value end
function Element:keys()                 local out = {}; for k in pairs(self.attrib)       do append(out, k) end; return out end
function Element:items()                local out = {}; for k, v in pairs(self.attrib)    do append(out, { k, v }) end; return out end

function Element:iter(tag)
    local stack = { self }
    return function()
        while #stack > 0 do
            local node = stack[#stack]
            if not node._iter_started then
                node._iter_started = true
                if tag == nil or tag == "*" or node.tag == tag then return node end
            end

            node._iter_idx = (node._iter_idx or 0) + 1
            local child    = node._children[node._iter_idx]
            if child then
                stack[#stack + 1] = child
            else
                node._iter_started, node._iter_idx = nil, nil
                stack[#stack] = nil
            end
        end
        return nil
    end
end

function Element:itertext()
    local pieces = {}
    local function walk(n)
        if n.text and n.text ~= "" then append(pieces, n.text) end
        for _, c in ipairs(n._children) do
            walk(c)
            if c.tail and c.tail ~= "" then append(pieces, c.tail) end
        end
    end
    walk(self)
    local i = 0
    return function() i += 1; return pieces[i] end
end

-- ——— tree management ——————————————————————————————————————

local ElementTree   = {}
ElementTree.__index = ElementTree

function ElementTree:new(root)   return setmetatable({ _root = root }, ElementTree) end
function ElementTree:getroot()     return self._root end
function ElementTree:_setroot(el)  self._root = el end
function ElementTree:iter(tag)     return self._root and self._root:iter(tag) or (function() return nil end) end

-- ——— module api ———————————————————————————————————————————

M.Element      = Element
M.ElementTree  = ElementTree
M.iselement    = function(el) return type(el) == "table" and getmetatable(el) == Element end

function M.SubElement(parent, tag, attrib, extra)
    local el = parent:makeelement(tag, attrib or {})
    if extra then for k, v in pairs(extra) do el.attrib[k] = v end end
    parent:append(el)
    return el
end

function M.Comment(text)
    local el = Element:new("Comment", {})
    el.text  = text
    return el
end

function M.ProcessingInstruction(target, text)
    local el = Element:new("PI", {})
    el.text  = target .. (text and text ~= "" and (" " .. text) or "")
    return el
end
M.PI = M.ProcessingInstruction

local QName      = {}
QName.__index    = QName
function QName:new(uri, tag) return setmetatable({ text = tag and string.format("{%s}%s", uri, tag) or uri }, QName) end
function QName:__tostring()   return self.text end
M.QName = QName

-- ——— da parser ————————————————————————————————————————————

local function parse_name(s, i)
    local start, c = i, charAt(s, i)
    if not c:match("[%a_:]") then return nil end
    i += 1
    while i <= #s and charAt(s, i):match("[%w%._:-]") do i += 1 end
    return s:sub(start, i - 1), i
end

local function skip_ws(s, i)
    while i <= #s and charAt(s, i):match("%s") do i += 1 end
    return i
end

local function parse_attr_value(s, i)
    local quote = s:sub(i, i)
    if quote ~= '"' and quote ~= "'" then return nil end
    local start, j = i + 1, i + 1
    while j <= #s do
        if s:sub(j, j) == quote then return decode_entities(s:sub(start, j - 1)), j + 1 end
        j += 1
    end
    return nil
end

local function parse_attributes(s, i)
    local attrs = {}
    i = skip_ws(s, i)
    while i <= #s do
        local c = s:sub(i, i)
        if c == "/" or c == ">" then return attrs, i end
        
        local name, next_i = parse_name(s, i)
        if not name then raise("invalid attribute name", i, s) end
        i = skip_ws(s, next_i)
        
        if s:sub(i, i) ~= "=" then raise("expected '=' after attribute name", i, s) end
        i = skip_ws(s, i + 1)
        
        local val, next_val_i = parse_attr_value(s, i)
        if val == nil then raise("invalid attribute value", i, s) end
        attrs[name], i = val, skip_ws(s, next_val_i)
    end
    return attrs, i
end

local function add_text(stack, text)
    if not text or text == "" then return end
    local top = stack[#stack]
    if not top then return end

    if #top._children == 0 and (not top.text or top.text == "") then
        top.text = (top.text or "") .. text
    else
        local last = top._children[#top._children]
        if last then last.tail = (last.tail or "") .. text
        else top.text = (top.text or "") .. text end
    end
end

function M.XML(xml)
    if type(xml) ~= "string" then raise("XML input must be a string", 0) end
    if xml:sub(1, 3) == "\239\187\191" then xml = xml:sub(4) end

    local i, n, stack, root = 1, #xml, {}, nil

    while i <= n do
        local lt = xml:find("<", i, true)
        if not lt then add_text(stack, decode_entities(xml:sub(i))); break end
        if lt > i then add_text(stack, decode_entities(xml:sub(i, lt - 1))) end

        i = lt
        if xml:sub(i, i + 3) == "<!--" then
            local finish = xml:find("-->", i + 4, true)
            if not finish then raise("unterminated comment", i, xml) end
            i = finish + 3
        elseif xml:sub(i, i + 8) == "<![CDATA[" then
            local finish = xml:find("]]>", i + 9, true)
            if not finish then raise("unterminated CDATA section", i, xml) end
            add_text(stack, xml:sub(i + 9, finish - 1))
            i = finish + 3
        elseif xml:sub(i, i + 1) == "<?" then
            local finish = xml:find("?>", i + 2, true)
            if not finish then raise("unterminated PI", i, xml) end
            i = finish + 2
        elseif xml:sub(i, i + 1) == "</" then
            i += 2
            local name, next_i = parse_name(xml, i)
            if not name then raise("invalid closing tag", i, xml) end
            i = skip_ws(xml, next_i)
            if xml:sub(i, i) ~= ">" then raise("expected '>'", i, xml) end
            
            local el = table.remove(stack)
            if not el then raise("unexpected closing tag", i, xml) end
            if el.tag ~= name then raise(string.format("tag mismatch: expected %s, got %s", el.tag, name), i, xml) end
            i += 1
        elseif xml:sub(i, i + 1) == "<!" then
            local finish = xml:find(">", i + 2, true)
            if not finish then raise("unterminated declaration", i, xml) end
            i = finish + 1
        else
            i += 1
            local tag, next_i = parse_name(xml, i)
            if not tag then raise("invalid start tag", i, xml) end
            
            local attrs, next_attr_i = parse_attributes(xml, next_i)
            local el = Element:new(tag, attrs)
            i = next_attr_i

            if xml:sub(i, i) == "/" then
                if xml:sub(i + 1, i + 1) ~= ">" then raise("expected '/>'", i, xml) end
                i += 2
                if stack[#stack] then stack[#stack]:append(el) else root = root or el end
            elseif charAt(xml, i) == ">" then
                i += 1
                if stack[#stack] then stack[#stack]:append(el) else root = root or el end
                append(stack, el)
            else
                raise("expected '>' or '/>'", i, xml)
            end
        end
    end

    if #stack ~= 0 then raise("missing end tags", i, xml) end
    if not root then raise("missing toplevel element", i, xml) end
    return root
end

M.fromstring = M.XML

function M.parse(src)
    if type(src) == "string" then
        local f = io.open(src, "rb"); if not f then error("file not found: " .. src, 0) end
        local d = f:read("*a"); f:close()
        return ElementTree:new(M.XML(d))
    elseif type(src) == "table" and src.read then
        return ElementTree:new(M.XML(src:read("*a")))
    end
    raise("unsupported source type", 0)
end

return M
