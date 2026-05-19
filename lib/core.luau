local M   = {} :: any
local std = require(script.Parent.std)

local append, extend, strip, lower, str, charAt = std.append, std.extend, std.strip, std.lower, std.str, std.charAt
local startswith, endswith = std.startswith, std.endswith

local EVENT_MAP = {
	onClick              = "Activated",
	onInputBegan         = "InputBegan",
	onInputChanged       = "InputChanged",
	onInputEnded         = "InputEnded",
	onMouseEnter         = "MouseEnter",
	onMouseLeave         = "MouseLeave",
	onMouseMoved         = "MouseMoved",
	onMouseWheelForward  = "MouseWheelForward",
	onMouseWheelBackward = "MouseWheelBackward",
	onSelectionGained    = "SelectionGained",
	onSelectionLost      = "SelectionLost",
	onTouchTap           = "TouchTap",
	onMouseButton1Click  = "MouseButton1Click",
	onMouseButton1Down   = "MouseButton1Down",
	onMouseButton1Up     = "MouseButton1Up",
	onMouseButton2Click  = "MouseButton2Click",
	onMouseButton2Down   = "MouseButton2Down",
	onMouseButton2Up     = "MouseButton2Up",
	onFocused            = "Focused",
	onFocusLost          = "FocusLost",
}

local ALLOWED_RAWPROPS = {
	IgnoreGuiInset = true,
	Active = true,
}

-- ——— parsing helpers —————————————————————————————————————

local function parse_bool(value)
	local l = lower(value)
	return l == "true" or l == "1" or l == "yes" or l == "on"
end

local function parse_scalepair(value)
	local x, y = string.match(value, "^%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*$")
	return { "scale", tonumber(x), tonumber(y) }
end

local function parse_rgb(value)
	local r, g, b = string.match(value, "^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
	return { tonumber(r), tonumber(g), tonumber(b) }
end

local function parse_scalar(value)
	local l = lower(value)
	if l == "true" or l == "false" or l == "1" or l == "0" or l == "yes" or l == "no" or l == "on" or l == "off" then return parse_bool(value) end
	if string.match(value, "^-?%d+$") then return tonumber(value) end
	if string.match(value, "^-?%d+%.%d*$") or string.match(value, "^-?%d*%.%d+$") then return tonumber(value) end
	return value
end

local function is_luaexpr(value)     return type(value) == "string" and #value >= 2 and startswith(value, "{") and endswith(value, "}") end
local function parse_expr(value)     return { kind = "expr", code = strip(string.sub(value, 2, -2)) } end
local function is_expr(value)        return type(value) == "table" and value.kind == "expr" end

local PROP_SETTERS = {
	size            = { "Size",                   parse_scalepair },
	position        = { "Position",               parse_scalepair },
	backgroundColor = { "BackgroundColor3",       parse_rgb },
	textColor       = { "TextColor3",             parse_rgb },
	cornerRadius    = { "__cornerRadius",         tonumber },
	textScaled      = { "TextScaled",             parse_bool },
	text            = { "Text",                   function(v) return v end },
	visible         = { "Visible",                parse_bool },
	backgroundTransparency = { "BackgroundTransparency", tonumber },
	textTransparency       = { "TextTransparency",       tonumber },
}

local LAYOUT_KEYS     = { direction = "direction", gap = "gap", padding = "padding", align = "align" }
local TWEEN_KEYS      = { tweenTime = "time", tweenStyle = "style", tweenDirection = "direction" }
local TRANSITION_KEYS = { transition = "preset", transitionTime = "time", transitionStyle = "style", transitionDirection = "direction" }

-- ——— builds ——————————————————————————————————————————

local function parse_props(node)
	local props      = {}
	local layout     = {}
	local tween      = {}
	local transition = {}

	for k, v in pairs(node.attrib) do
		local setter = PROP_SETTERS[k]
		if setter then props[setter[1]] = is_luaexpr(v) and parse_expr(v) or setter[2](v)

		elseif k == "transparency" then
			local val = is_luaexpr(v) and parse_expr(v) or tonumber(v)
			props.BackgroundTransparency, props.TextTransparency = val, val

		elseif LAYOUT_KEYS[k]     then layout[LAYOUT_KEYS[k]]         = v
		elseif TWEEN_KEYS[k]      then tween[TWEEN_KEYS[k]]           = tonumber(v) or v
		elseif TRANSITION_KEYS[k] then transition[TRANSITION_KEYS[k]] = tonumber(v) or v

		elseif EVENT_MAP[k]       then props[k]     = is_luaexpr(v) and parse_expr(v) or v
		elseif k == "id"          then props.__id   = v
		elseif k == "name"        then
			if is_luaexpr(v) then props.__runtimeName = parse_expr(v)
			else props.__name = v end

		elseif startswith(k, "__") then -- internal metadata, ignore(?)
		elseif startswith(k, "on") then error("[Rui] Unsupported event: " .. tostring(k))

		elseif node.tag == "LuaBlock" and k == "key" then props.__luaBlockKey = v
		else props["__rawprop__" .. k] = is_luaexpr(v) and parse_expr(v) or parse_scalar(v) end
	end

	if next(layout)     ~= nil then props.__layout     = layout     end
	if next(tween)      ~= nil then props.__tween      = tween      end
	if next(transition) ~= nil then props.__transition = transition end

	return props
end

local function build(node)
	local obj = {
		type     = node.tag,
		props    = parse_props(node),
		children = {},
	}

	for index, child in ipairs(node._children) do
		local child_obj = build(child)
		if child_obj then
			child_obj.child_index = index
			append(obj.children, child_obj)
		end
	end

	return obj
end

-- ——— naming / allocation —————————————————————————————————

local idc            = 0
local idb            = {}
local used_names	 = {}
local block_counter  = 0
local block_sources  = {}
local action_names   = {}

local function alloc_obj(node, suffix)
	suffix       = suffix or ""
	local bucket = idb[node]

	if not bucket then
		bucket = {}
		idb[node] = bucket
	end

	if bucket[suffix] ~= nil then return bucket[suffix] end

	idc += 1
	bucket[suffix] = idc
	return idc
end

local function sanitize_name(value)
	local clean = string.gsub(value or "", "[^%w_]", "_")
	clean = string.gsub(clean, "_+", "_")
	clean = string.gsub(clean, "^_+", "")
	clean = string.gsub(clean, "_+$", "")

	if clean == "" then clean = "node" end
	if string.match(clean, "^%d") then clean = "n_" .. clean end

	return clean
end

local function alloc_name(node, suffix)
	suffix = suffix or "obj"
	local explicit = node.props.__name
	local base

	if explicit then base = sanitize_name(explicit)
	elseif suffix ~= "" then base = sanitize_name(suffix)
	else base = "node" end

	local candidate = base
	local serial    = 2
	while used_names[candidate] do
		candidate = base .. "_" .. tostring(serial)
		serial += 1
	end

	used_names[candidate] = true
	return candidate
end

local function alloc_helper(node, suffix, fallback_prefix)
	local serial = tostring(alloc_obj(node, suffix or fallback_prefix or "helper"))
	local explicit = node.props.__name

	if explicit then
		return alloc_name(node, sanitize_name(explicit) .. "_" .. sanitize_name(suffix or "helper") .. "_" .. serial)
	end

	local prefix = fallback_prefix or suffix or "obj"
	return sanitize_name(prefix) .. "_" .. serial
end

-- ——— lua string / bracket helpers ————————————————————————

local function read_longbrack(text, start_pos)
	if string.sub(text, start_pos, start_pos) ~= "[" then return nil end

	local i   = start_pos + 1
	local eqs = ""
	while string.sub(text, i, i) == "=" do eqs ..= "="; i += 1 end

	if string.sub(text, i, i) ~= "[" then return nil end

	local open_len      = i - start_pos + 1
	local close_token   = "]" .. eqs .. "]"
	
	local content_start = start_pos + open_len
	local content_end   = string.find(text, close_token, content_start, true)
	if not content_end then error("Unclosed Lua long bracket string") end

	return string.sub(text, content_start, content_end - 1), content_end + #close_token
end

-- ——— luax preprocessing helpers ——————————————————————————

local function count_newlines(text)
	local count = 0
	for _ in string.gmatch(text, "\n") do count += 1 end
	return count
end

local function skip_quoted(text, pos, quote)
	local i = pos + 1
	while i <= #text do
		local ch = string.sub(text, i, i)

		if ch == "\\" 	   then i += 2
		elseif ch == quote then return i + 1
		else i += 1 end

	end
	error("[Rui] Unterminated quoted string in loose Lua block")
end

local function find_blockclose(text, start_pos)
	local depth = 1
	local i = start_pos

	while i <= #text - 1 do
		local long_next

		local content, next_pos = read_longbrack(text, i)
		if content == nil then long_next = nil end
		long_next = next_pos

		if long_next ~= nil then
			i = long_next
			continue
		end

		local ch = string.sub(text, i, i)
		local pair = string.sub(text, i, i + 1)

		if ch == "\"" or ch == "'" then
			i = skip_quoted(text, i, ch)
		elseif pair == "{{" then
			depth += 1
			i += 2
		elseif pair == "}}" then
			depth -= 1
			if depth == 0 then
				return i
			end
			i += 2
		else
			i += 1
		end
	end

	error(string.format("[Rui] Line %d: Unclosed loose Lua block", count_newlines(string.sub(text, 1, math.max(start_pos - 1, 0))) + 1))
end

-- ——— luax preprocessing main —————————————————————————————

local function preprocess_luaxml(src)
	src = string.gsub(src, "<>", "<Fragment>")
	src = string.gsub(src, "</>", "</Fragment>")

	local out = {}
	local i = 1

	while i <= #src do
		local open_pos = string.find(src, "{{", i, true)
		if not open_pos then
			append(out, string.sub(src, i))
			break
		end

		append(out, string.sub(src, i, open_pos - 1))

		local line_start = open_pos
		while line_start > 1 and string.sub(src, line_start - 1, line_start - 1) ~= "\n" do
			line_start -= 1 end

		local indent = string.match(string.sub(src, line_start, open_pos - 1), "^(%s*)") or ""
		local close_pos = find_blockclose(src, open_pos + 2)

		local code = string.sub(src, open_pos + 2, close_pos - 1)
		code = string.match(code, "^%s*(.-)%s*$") or ""

		local key = "luablock_" .. tostring(block_counter)
		block_counter += 1
		block_sources[key] = code
		append(out, string.format('%s<LuaBlock key="%s" />', indent, key))

		local consumed = string.sub(src, open_pos, close_pos + 1)
		for _ = 1, count_newlines(consumed) do
			append(out, "\n") end -- line padding

		i = close_pos + 2
	end

	return table.concat(out)
end

-- ——— expression / fragment extraction —————————————————————

local function extract_vars(value)
	local vars = {}
	for name in string.gmatch(value, "{%s*([%a_][%w_]*)%s*}") do
		append(vars, name) end
	return vars
end

local function unquote_str(token)
	local long_content = read_longbrack(token, 1)
	if long_content ~= nil then
		return long_content end

	local first = string.sub(token, 1, 1)
	local last  = string.sub(token, -1, -1)

	if first == '"' and last == '"' then
		local inner = string.sub(token, 2, -2)
		inner = string.gsub(inner, "\\\\", "\\")
		inner = string.gsub(inner, "\\\"", '"')
		inner = string.gsub(inner, "\\n", "\n")
		inner = string.gsub(inner, "\\r", "\r")
		inner = string.gsub(inner, "\\t", "\t")
		return inner
	end

	if first == "'" and last == "'" then
		local inner = string.sub(token, 2, -2)
		inner = string.gsub(inner, "\\\\", "\\")
		inner = string.gsub(inner, "\\'", "'")
		inner = string.gsub(inner, "\\n", "\n")
		inner = string.gsub(inner, "\\r", "\r")
		inner = string.gsub(inner, "\\t", "\t")
		return inner
	end

	error("Unsupported Lua string literal: " .. token)
end

local function parse_scope(code)
	local captures = {}

	local directive = string.match(code, "^%s*%-%-%s*@scope%s+([^\n]+)")
	if not directive then return code, captures end

	local stripped = string.gsub(code, "^%s*%-%-%s*@scope%s+[^\n]*\n?", "", 1)
	for name in string.gmatch(directive, "([%a_][%w_]*)") do append(captures, name) end

	return stripped, captures
end

local function read_quotedstr(code, start_i)
	local quote   = charAt(code, start_i)
	local i       = start_i + 1
	local escaped = false

	while i <= #code do
		local c = charAt(code, i)

		if escaped then escaped = false
		elseif c == "\\" then escaped = true
		elseif c == quote then return i
		end

		i += 1
	end

	return nil
end

local function uses_identifier(code, name)
	local out = {}
	local i = 1

	while i <= #code do
		local c = charAt(code, i)
		local n = charAt(code, i + 1)

		if c == "'" or c == '"' then
			local close_i = read_quotedstr(code, i)
			if close_i == nil then break end
			append(out, " ")
			i = close_i + 1

		elseif c == "[" then
			local _, next_i = read_longbrack(code, i)
			if next_i ~= nil then append(out, " "); i = next_i
			else append(out, c); i += 1
			end

		elseif c == "-" and n == "-" then
			local _, next_i = read_longbrack(code, i + 2)
			if charAt(code, i + 2) == "[" and next_i ~= nil then append(out, " "); i = next_i
			else while i <= #code and charAt(code, i) ~= "\n" do i += 1 end
			end

		else
			append(out, c)
			i += 1
		end
	end

	local stripped = table.concat(out)
	return string.find(stripped, "%f[%w_]" .. name .. "%f[^%w_]") ~= nil
end

local function extract_fragmentcalls(code)
	local literals = {}
	local out      = {}
	local i        = 1

	while i <= #code do
		if string.sub(code, i, i + 7) == "Fragment" then
			local before = i > 1 and string.sub(code, i - 1, i - 1) or ""
			if before ~= "" and before:match("[%w_]") then
				append(out, string.sub(code, i, i))
				i += 1
				continue
			end

			local j = i + 8
			while charAt(code, j):match("%s") do j += 1 end
			if charAt(code, j) ~= "(" then
				append(out, string.sub(code, i, i))
				i += 1
				continue
			end

			j += 1
			while charAt(code, j):match("%s") do j += 1 end
			if j > #code then error("Unclosed Fragment(...) in LuaBlock") end

			local token
			local _, long_end = read_longbrack(code, j)

			if long_end ~= nil then
				token = string.sub(code, j, long_end - 1)
				j = long_end

			elseif charAt(code, j) == '"' or charAt(code, j) == "'" then
				local k = read_quotedstr(code, j)
				if not k then error("Unclosed Fragment string in LuaBlock") end
			
				token = string.sub(code, j, k)
				j = k + 1

			else error("Fragment(...) requires a Lua string literal") end

			while charAt(code, j):match("%s") do j += 1 end
			if charAt(code, j) ~= ")" then error("Fragment(...) must contain exactly one string literal") end

			local value = unquote_str(token)
			local key   = "frag_" .. tostring(#literals)

			append(literals, { key = key, value = value })
			append(out, "__fragment(" .. str(key) .. ")")

			i = j + 1
			continue
		end

		append(out, string.sub(code, i, i))
		i += 1
	end

	return table.concat(out), literals
end

local function extract_strliterals(code)
	local out = {}
	local i   = 1

	while i <= #code do
		local ch = string.sub(code, i, i)

		if ch == '"' or ch == "'" then
			local j = read_quotedstr(code, i)
			if not j then error("Unclosed Lua string literal in LuaBlock") end
		
			append(out, string.sub(code, i, j))
			i = j + 1
			continue
		end

		if string.sub(code, i, i + 1) == "[[" then
			local j = string.find(code, "]]", i + 2, true)
			if not j then error("Unclosed Lua long string literal in LuaBlock") end
			append(out, string.sub(code, i, j + 1))
			i = j + 2
			continue
		end

		append(out, ch)
		i += 1
	end

	return table.concat(out), {}
end

local function indent_codeblock(code, prefix)
	local lines = {}
	local normalized = string.gsub(code, "\r\n", "\n")

	for line in string.gmatch(normalized .. "\n", "(.-)\n") do
		append(lines, prefix .. line) end

	return table.concat(lines, "\n")
end

-- ——— compilation core ————————————————————————————————————

local function compile_func(code, indent, scope_var, statement, suffix, scope_locals, frag_scopecaptures)
	suffix       = suffix or "expr"
	local fn_var = suffix .. "_" .. tostring(idc + 1)
	idc += 1

	local lines = { indent .. "local " .. fn_var .. " = function(_scope, _event)" }
	if scope_var ~= nil then append(lines, indent .. "    local scope = _scope or " .. scope_var)
	else append(lines, indent .. "    local scope = _scope")
	end

	if scope_locals then
		for _, name in ipairs(scope_locals) do
			append(lines, indent .. "    local " .. name .. " = scope and scope[" .. str(name) .. "] or nil") end
	end

	for _, name in ipairs(action_names) do
		if uses_identifier(code, name) then
			append(lines, indent .. "    local " .. name .. " = function(_payload) return invokeAction(" .. str(name) .. ", scope, _payload, _event) end") end
	end
	
	if uses_identifier(code, "getById") then
		append(lines, indent .. "    local getById = getById") end

	if frag_scopecaptures ~= nil and uses_identifier(code, "__fragment") then
		append(lines, indent .. "    local function __fragment(key, capturedScope)")
		if #frag_scopecaptures > 0 then
			append(lines, indent .. "        return {")
			append(lines, indent .. "            key = key,")
			append(lines, indent .. "            scope = capturedScope,")
			append(lines, indent .. "        }")
		else
			append(lines, indent .. "        return key")
		end
		append(lines, indent .. "    end")
	end

	if statement then extend(lines, { indent_codeblock(code, indent .. "    ") })
	else append(lines, indent .. "    return " .. code)
	end

	append(lines, indent .. "end")
	return lines, fn_var
end

local function compile_computedprop(var, prop_name, code, indent, scope_var, scope_locals)
	local lines, fn_var = compile_func(code, indent, scope_var, false, "prop", scope_locals)
	append(lines, indent .. "bindComputed(" .. var .. ", " .. str(prop_name) .. ", " .. fn_var .. ", " .. (scope_var or "nil") .. ")")
	return lines
end

local function compile_prop(lines, var, prop, v, indent, scope, locals, fmt)
	if is_expr(v) then extend(lines, compile_computedprop(var, prop, v.code, indent, scope, locals))
	else append(lines, indent .. var .. "." .. prop .. " = " .. (fmt and fmt(v) or tostring(v))) end
end

-- ——— property compilers ——————————————————————————————————

local function compile_tween(node, var, indent)
	local tween = node.props.__tween
	if not tween then return {} end

	local time      = tween.time or 0.25
	local style     = tween.style or "Quad"
	local direction = tween.direction or "Out"

	return {
		indent .. "setTweenInfo(" .. var .. ", TweenInfo.new(" .. tostring(time) .. ", Enum.EasingStyle." .. style .. ", Enum.EasingDirection." .. direction .. "))"
	}
end

local function compile_transition(node, var, indent)
	local transition = node.props.__transition
	if not transition then return {} end

	local preset    = transition.preset or "fade"
	local time      = transition.time or 0.22
	local style     = transition.style or "Quad"
	local direction = transition.direction or "Out"

	return {
		indent .. "setTransitionInfo(" .. var .. ", " .. str(preset) .. ", TweenInfo.new(" .. tostring(time) .. ", Enum.EasingStyle." .. style .. ", Enum.EasingDirection." .. direction .. "))",
	}
end

local function compile_rawprop(var, attr_name, value, indent, scope_var, scope_locals)
	local lines     = {}
	local prop_name = string.sub(attr_name, #"__rawprop__" + 1)
	
	if not ALLOWED_RAWPROPS[prop_name] then
		append(lines, indent .. "warnUnknownAttribute(" .. str(attr_name) .. ", " .. str(prop_name) .. ")") end

	if is_expr(value) then
		extend(lines, compile_computedprop(var, prop_name, value.code, indent, scope_var, scope_locals))
		return lines
	end

	local val = type(value) == "string" and str(value) or tostring(value)
	append(lines, indent .. var .. "." .. prop_name .. " = " .. val)

	return lines
end

local function compile_visiblebind(node, var, indent, scope_var, scope_locals)
	local visible = node.props.Visible
	if visible == nil then return {} end
	return compile_computedprop(var, "Visible", visible.code, indent, scope_var, scope_locals)
end

-- ——— element compilers ———————————————————————————————————

-- / forward declr
local compile_block
local compile_fragchilds
local compile_node
local group_comment
-- / end forward declr

local function compile_child(parent_var, child, depth, scope_var, scope_locals)
	local indent = string.rep("    ", depth)

	if child.type == "Fragment" then
		local lines = {}
		for _, grandchild in ipairs(child.children) do
			extend(lines, compile_child(parent_var, grandchild, depth, scope_var, scope_locals))
		end
		return lines
	end

	if child.type == "LuaBlock" then return compile_block(child, parent_var, depth, scope_var, scope_locals) end

	local child_lines, child_var = compile_node(child, depth + 1, scope_var, scope_locals)
	append(child_lines, indent .. child_var .. ".Parent = " .. parent_var)
	return child_lines
end

local function compile_layout(node, var, indent)
	local lines  = {}
	local layout = node.props.__layout

	if not layout and node.type == "ScrollingFrame" then layout = { direction = "column" } end
	if not layout then return lines end

	local list_var = alloc_helper(node, "layout", "layout")
	append(lines, indent .. "local " .. list_var .. " = Instance.new(\"UIListLayout\")")

	local direction      = lower(layout.direction or "column")
	local fill_direction = direction == "row" and "Horizontal" or "Vertical"

	append(lines, indent .. list_var .. ".FillDirection = Enum.FillDirection." .. fill_direction)
	append(lines, indent .. list_var .. ".SortOrder = Enum.SortOrder.LayoutOrder")

	if node.type == "ScrollingFrame" then
		local scroll_direction = direction == "row" and "X" or "Y"

		append(lines, indent .. var .. ".AutomaticCanvasSize = Enum.AutomaticSize." .. scroll_direction)
		append(lines, indent .. var .. ".CanvasSize          = UDim2.new()")
		append(lines, indent .. var .. ".ScrollingDirection  = Enum.ScrollingDirection." .. scroll_direction)
	end

	if layout.gap ~= nil then append(lines, indent .. list_var .. ".Padding = UDim.new(0, " .. tostring(layout.gap) .. ")") end

	local align = lower(layout.align or "")

	if align == "center" then
		append(lines, indent .. list_var .. ".HorizontalAlignment = Enum.HorizontalAlignment.Center")
		append(lines, indent .. list_var .. ".VerticalAlignment   = Enum.VerticalAlignment.Center")

	elseif align == "end" then
		append(lines, indent .. list_var .. ".HorizontalAlignment = Enum.HorizontalAlignment.Right")
		append(lines, indent .. list_var .. ".VerticalAlignment   = Enum.VerticalAlignment.Bottom")

	elseif align == "start" then
		append(lines, indent .. list_var .. ".HorizontalAlignment = Enum.HorizontalAlignment.Left")
		append(lines, indent .. list_var .. ".VerticalAlignment   = Enum.VerticalAlignment.Top")
	end

	append(lines, indent .. list_var .. ".Parent = " .. var)

	if layout.padding ~= nil then
		local padding_var = alloc_helper(node, "padding", "padding")
		append(lines, indent .. "local " .. padding_var .. " = Instance.new(\"UIPadding\")")
		append(lines, indent .. padding_var .. ".PaddingTop    = UDim.new(0, " .. tostring(layout.padding) .. ")")
		append(lines, indent .. padding_var .. ".PaddingBottom = UDim.new(0, " .. tostring(layout.padding) .. ")")
		append(lines, indent .. padding_var .. ".PaddingLeft   = UDim.new(0, " .. tostring(layout.padding) .. ")")
		append(lines, indent .. padding_var .. ".PaddingRight  = UDim.new(0, " .. tostring(layout.padding) .. ")")
		append(lines, indent .. padding_var .. ".Parent        = " .. var)
	end

	return lines
end

local function compile_corner(node, var, indent, scope_var, scope_locals)
	local lines  = {}
	local radius = node.props.__cornerRadius
	if radius == nil then return lines end

	local corner_var = alloc_helper(node, "corner", "corner")
	append(lines, indent .. "local " .. corner_var .. " = Instance.new(\"UICorner\")")

	if is_expr(radius) then
		local fn_lines, fn_var = compile_func(radius.code, indent, scope_var, false, "corner", scope_locals)
		extend(lines, fn_lines)

		append(lines, indent .. "bindComputed(" .. corner_var .. ", \"CornerRadius\", " .. fn_var .. ", nil)")
		append(lines, indent .. corner_var .. ".Parent = " .. var)
		return lines
	end

	append(lines, indent .. corner_var .. ".CornerRadius = UDim.new(0, " .. tostring(radius) .. ")")
	append(lines, indent .. corner_var .. ".Parent       = " .. var)
	return lines
end

local function compile_events(node, var, indent, scope_var, scope_locals)
	local lines    = {}
	for prop_name, signal_name in pairs(EVENT_MAP) do
		local handler = node.props[prop_name]

		if handler == nil then continue end

		if is_expr(handler) then
			local fn_lines, fn_var = compile_func(handler.code, indent, scope_var, true, "event", scope_locals)
			extend(lines, fn_lines)
			append(lines, indent .. "bindEventExpr(" .. var .. ", " .. str(prop_name) .. ", " .. str(signal_name) .. ", " .. fn_var .. ", " .. (scope_var or "nil") .. ")")
		else
			append(lines, indent .. "bindEvent(" .. var .. ", " .. str(prop_name) .. ", " .. str(signal_name) .. ", " .. str(handler) .. ", " .. (scope_var or "nil") .. ")") end

	end
	return lines
end

local function compile_textbind(node, var, indent, scope_var, scope_locals)
	local text = node.props.Text
	if is_expr(text) then return compile_computedprop(var, "Text", text.code, indent, scope_var, scope_locals) end
	if type(text) ~= "string" then return {} end

	local vars_found = extract_vars(text)
	if #vars_found == 0 then return { indent .. var .. ".Text = " .. str(text) } end

	local unique_vars = {}
	local seen        = {}
	for _, name in ipairs(vars_found) do
		if not seen[name] then
			seen[name] = true
			append(unique_vars, name)
		end
	end

	local template_var = alloc_helper(node, "text_template", "tmpl")
	local deps         = {}
	for _, name in ipairs(unique_vars) do append(deps, str(name)) end

	local lines = { indent .. "local " .. template_var .. " = " .. str(text) }
	if scope_var ~= nil then append(lines, indent .. var .. ".Text = renderTemplate(" .. template_var .. ", " .. scope_var .. ")")
	else append(lines, indent .. "bindText(" .. var .. ", " .. template_var .. ", {" .. table.concat(deps, ", ") .. "})") end
	return lines
end

function compile_block(node, parent_var, depth, scope_var, scope_locals)
	local indent = string.rep("    ", depth)
	local key    = node.props.__luaBlockKey
	if not key then return {} end

	local source = block_sources[key] or ""
	local cleaned_source, frag_scopecaptures = parse_scope(source)
	local transformed_code, literals = extract_fragmentcalls(cleaned_source)
	local extra_code, extra_literals = extract_strliterals(transformed_code)

	transformed_code = extra_code
	extend(literals, extra_literals)

	if #frag_scopecaptures > 0 then
		local capture_parts = {}
		for _, name in ipairs(frag_scopecaptures) do append(capture_parts, name .. " = " .. name) end

		local capture_expr = "{ " .. table.concat(capture_parts, ", ") .. " }"
		transformed_code = string.gsub(transformed_code, "__fragment%(([^%(%)]+)%)", "__fragment(%1, " .. capture_expr .. ")")
	end

	local normalized_code

	local stripped = string.match(transformed_code, "^%s*(.-)%s*$") or ""
	if stripped == "" then normalized_code = "return nil"
	else normalized_code = stripped end

	local selector_lines, selector_var = compile_func(normalized_code, indent, scope_var, true, "lua_block", scope_locals, frag_scopecaptures)
	local factories_table = alloc_name(node, "fragmentFactories")
	local lines           = { group_comment(indent, "LuaBlock") }

	extend(lines, selector_lines)
	append(lines, indent .. "local " .. factories_table .. " = {}")

	for _, frag in ipairs(literals) do
		append(lines, indent .. factories_table .. "[" .. str(frag.key) .. "] = function(parent, fragmentScope)")

		local frag_scopelocals = frag_scopecaptures
		if frag_scopelocals == nil or #frag_scopelocals == 0 then frag_scopelocals = scope_locals end
		
		local frag_lines, frag_roots = compile_fragchilds(frag.value, depth + 1, "fragmentScope", frag_scopelocals)

		extend(lines, frag_lines)
		for _, root in ipairs(frag_roots) do append(lines, indent .. "    " .. root .. ".Parent = parent") end

		append(lines, indent .. "    return {" .. table.concat(frag_roots, ", ") .. "}")
		append(lines, indent .. "end")
	end

	append(lines, indent .. "bindLuaBlock(" .. parent_var .. ", " .. selector_var .. ", " .. factories_table .. ", " .. (scope_var or "nil") .. ")")
	return lines
end

function compile_fragchilds(fragment_src, depth, scope_var, scope_locals)
	fragment_src = string.match(fragment_src, "^%s*(.-)%s*$") or ""
	if fragment_src == "" then return {}, {} end

	local wrapped_src   = "<Fragment>\n" .. fragment_src .. "\n</Fragment>"
	local fragment_tree = build((M._xml_parser or error("xml parser not configured")).fromstring(preprocess_luaxml(wrapped_src)))

	local roots         = {}
	local lines         = {}

	if fragment_tree.type == "Fragment" then
		for _, child in ipairs(fragment_tree.children) do
			local child_lines, child_var = compile_node(child, depth, scope_var, scope_locals)
			extend(lines, child_lines)
			append(roots, child_var)
		end
	else
		local child_lines, child_var = compile_node(fragment_tree, depth, scope_var, scope_locals)
		extend(lines, child_lines)
		append(roots, child_var)
	end

	return lines, roots
end

-- ——— node compilation ————————————————————————————————————

function compile_node(node, depth, scope_var, scope_locals)
	depth        = depth or 0
	local indent = string.rep("    ", depth)
	local var    = alloc_name(node, node.type)

	local lines = {
		"",
		group_comment(indent, node.props.__name or node.type),
		indent .. "local " .. var .. " = Instance.new(" .. str(node.type) .. ")",
		indent .. var .. ".Name = " .. str(var)
	}

	if node.type == "ScreenGui" then
		append(lines, indent .. var .. ".ResetOnSpawn = false")
	end

	local fmt_rgb   = function(v) return "Color3.fromRGB(" .. v[1] .. ", " .. v[2] .. ", " .. v[3] .. ")" end
	local fmt_scale = function(v) return "UDim2.fromScale(" .. v[2] .. ", " .. v[3] .. ")" end

	for k, v in pairs(node.props) do
		if     k == "Size"                   then compile_prop(lines, var, "Size", v, indent, scope_var, scope_locals, fmt_scale)
		elseif k == "Position"               then compile_prop(lines, var, "Position", v, indent, scope_var, scope_locals, fmt_scale)
		elseif k == "BackgroundColor3"       then compile_prop(lines, var, "BackgroundColor3", v, indent, scope_var, scope_locals, fmt_rgb)
		elseif k == "TextColor3"             then compile_prop(lines, var, "TextColor3", v, indent, scope_var, scope_locals, fmt_rgb)
		elseif k == "BackgroundTransparency" then compile_prop(lines, var, "BackgroundTransparency", v, indent, scope_var, scope_locals)
		elseif k == "TextTransparency"       then compile_prop(lines, var, "TextTransparency", v, indent, scope_var, scope_locals)
		elseif k == "Text"                   then extend(lines, compile_textbind(node, var, indent, scope_var, scope_locals))
		elseif k == "Visible"                then extend(lines, compile_visiblebind(node, var, indent, scope_var, scope_locals))
		elseif k == "TextScaled"             then compile_prop(lines, var, "TextScaled", v, indent, scope_var, scope_locals)
		elseif startswith(k, "__rawprop__")  then extend(lines, compile_rawprop(var, k, v, indent, scope_var, scope_locals)) end
	end

	local child_index = node.child_index
	if child_index ~= nil and node.type ~= "ScreenGui" and node.type ~= "Fragment" then
		append(lines, indent .. var .. ".LayoutOrder = " .. tostring(child_index)) end

	extend(lines, compile_tween(node, var, indent))
	extend(lines, compile_transition(node, var, indent))
	extend(lines, compile_layout(node, var, indent))
	extend(lines, compile_corner(node, var, indent, scope_var, scope_locals))
	extend(lines, compile_events(node, var, indent, scope_var, scope_locals))

	if node.props.__id then
		append(lines, indent .. "registerElementId(" .. str(node.props.__id) .. ", " .. var .. ")") end

	for _, child in ipairs(node.children) do
		extend(lines, compile_child(var, child, depth + 1, scope_var, scope_locals)) end

	return lines, var
end

local isFirstRoot = true
local function compile_root(node)
	if node.type == "Fragment" then
		local root_vars = {}
		local lines     = { group_comment("", "Fragment Root") }

		if isFirstRoot then lines = {}; isFirstRoot = false; end

		for _, child in ipairs(node.children) do
			local child_lines, child_var = compile_node(child, 0)
			extend(lines, child_lines)
			append(root_vars, child_var)
		end

		return lines, root_vars
	end

	local lines, root_var = compile_node(node)
	return lines, { root_var }
end

function group_comment(indent, label)
	return indent .. "-- -------- " .. label .. " --------" end

-- ——— ui loading ——————————————————————————————————————————

local function resolve_includes(ui_text, fragments)
	local resolved = ui_text
	local pattern  = "@include%(([%a_][%w_]*)%)"

	while true do
		local changed = false

		local next_resolved = string.gsub(resolved, pattern, function(name)
			if fragments[name] == nil then error("Unknown backend UI fragment include: " .. name) end

			changed = true
			return fragments[name]
		end)

		resolved = next_resolved
		if not changed then return resolved end
	end
end

local function load_uiapp(app)
	if type(app) ~= "table" then
		error("app must be a table") end

	if type(app.ui) ~= "string" then
		error(string.format("app.ui must be a string, is a %s", type(app.ui))) end

	if type(app.fragments or {}) ~= "table" then
		error("app.fragments must be a table when provided") end

	return resolve_includes(app.ui, app.fragments or {})
end

-- ——— main entry ——————————————————————————————————————————

local function append_footer(lua, root_vars)
	lua = lua .. [[

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local previewName = "__RUI_PREVIEW"
local runtimeName = "__RUI_GUI"

if script and script.Name then
    previewName = "__RUI_PREVIEW_" .. script.Name
    runtimeName = "__RUI_GUI_" .. script.Name
end

if RunService:IsRunning() then
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local runtimeRoot = playerGui:FindFirstChild(runtimeName)

    if runtimeRoot then runtimeRoot:Destroy() end

    runtimeRoot = Instance.new("Folder")
    runtimeRoot.Name = runtimeName
    runtimeRoot.Parent = playerGui

__ROOT_PARENTS_PLAYERGUI__

else
    local starterGui = game:GetService("StarterGui")
    local previewRoot = starterGui:FindFirstChild(previewName)

    if previewRoot then previewRoot:Destroy() end

    previewRoot = Instance.new("Folder")
    previewRoot.Name = previewName
    previewRoot.Parent = starterGui

__ROOT_PARENTS_PREVIEW__

end

return {
__ROOT_RETURN_VALUES__
}
]]

	local lines_playergui = {}
	local lines_preview = {}
	for _, name in ipairs(root_vars) do
		append(lines_playergui, name .. ".Parent = runtimeRoot")
		append(lines_preview, name .. ".Parent = previewRoot")
	end

	lua = string.gsub(lua, "__ROOT_PARENTS_PLAYERGUI__", table.concat(lines_playergui, "\n"))
	lua = string.gsub(lua, "__ROOT_PARENTS_PREVIEW__", table.concat(lines_preview, "\n"))
	lua = string.gsub(lua, "__ROOT_RETURN_VALUES__", table.concat(root_vars, ",\n"))

	return lua
end

function M.generate_from_app(app, runtime_text, xml_parser)
	if type(runtime_text) == "function" then runtime_text = runtime_text() end

	if type(runtime_text) ~= "string" then
		error("runtime_text must be a string or a zero-argument function returning a string") end

	if type(xml_parser) ~= "table" then
		error("xml_parser must be the xml.lua module table") end

	action_names = {}
	if type(app.actions) == "table" then
		for name in pairs(app.actions) do
			append(action_names, name)
		end
		table.sort(action_names)
	end
	
	M._xml_parser = xml_parser

	local src = preprocess_luaxml(load_uiapp(app))
	local root = build(xml_parser.fromstring(src))
	local lines, root_vars = compile_root(root)
	local lua = table.concat(lines, "\n")

	lua = table.concat({
		"-- ==================================================", 
		"-- Runtime",
		"-- ==================================================",
		runtime_text:gsub("^%s+", ""):gsub("%s+$", ""),
		"",
		"-- ==================================================",
		"-- UI",
		"-- ==================================================",
		lua,
	}, "\n")

	lua = append_footer(lua, root_vars)
	return lua, root_vars
end

M.load_ui_from_app       = load_uiapp
M.preprocess_luax_blocks = preprocess_luaxml
M.parse_bool             = parse_bool
M.parse_scale_pair       = parse_scalepair 
M.parse_rgb              = parse_rgb

return M
