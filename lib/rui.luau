local Compiler      = require(script.Parent.core)
local Xml           = require(script.Parent.xml)
local RuntimeSource = require(script.Parent.runtime)

local CollectionService = game:GetService("CollectionService")

local Rui = {}

-- ——— helpers ———————————————————————————————————————————

local function resolveAppTable(app)
	if typeof(app) == "Instance" and app:IsA("ModuleScript") then return require(app :: Instance) end
	if type(app) == "table" then return app end

	error("Rui expected an app ModuleScript or app table")
end

local function readLongBracket(text, startPos)
	if string.sub(text, startPos, startPos) ~= "[" then return nil end

	local i   = startPos + 1
	local eqs = ""
	while string.sub(text, i, i) == "=" do eqs ..= "="; i += 1 end

	if string.sub(text, i, i) ~= "[" then return nil end

	local closeToken = "]" .. eqs .. "]"
	local closePos   = string.find(text, closeToken, i + 1, true)
	if not closePos then return nil end

	return closePos + #closeToken - 1
end

local function stripLongBracketAssignment(source, pattern)
	local searchStart = 1

	while true do
		local startPos, endPos = string.find(source, pattern, searchStart)
		if not startPos then return source, false end

		local bracketPos = nil
		for i = endPos + 1, #source do
			local ch = string.sub(source, i, i)
			if not ch:match("%s") then bracketPos = i; break end
		end

		if bracketPos == nil then return source, false end

		local longEnd = readLongBracket(source, bracketPos)
		if longEnd == nil then searchStart = endPos + 1
		else
			local lineEnd = string.find(source, "\n", longEnd + 1, true) or (#source + 1)
			source = string.sub(source, 1, startPos - 1) .. string.sub(source, lineEnd)
			return source, true
		end
	end
end

-- ——— source processing ——————————————————————————————————

local function findFragmentsAssignment(source)
	return string.find(source, "([%a_][%w_]*)%.fragments%s*=%s*{")
end

local function stripFragmentsAssignment(source)
	local startPos, endPos = findFragmentsAssignment(source)
	if not startPos then return source end

	local braceStart = string.find(source, "{", endPos, true)
	if not braceStart then return source end

	local depth = 1
	local i     = braceStart + 1

	while i <= #source do
		local longEnd = readLongBracket(source, i)
		if longEnd ~= nil then i = longEnd + 1
		else
			local ch = string.sub(source, i, i)
			if     ch == "{" then depth += 1
			elseif ch == "}" then
				depth -= 1
				if depth == 0 then
					local lineEnd = string.find(source, "\n", i + 1, true) or (#source + 1)
					return string.sub(source, 1, startPos - 1) .. string.sub(source, lineEnd)
				end
			end
			i += 1
		end
	end

	return source
end

local function extractFragmentLocalNames(source)
	local startPos, endPos = findFragmentsAssignment(source)
	if not startPos then return {} end

	local braceStart = string.find(source, "{", endPos, true)
	if not braceStart then return {} end

	local depth = 1
	local i     = braceStart + 1

	while i <= #source do
		local longEnd = readLongBracket(source, i)
		if longEnd ~= nil then i = longEnd + 1
		else
			local ch = string.sub(source, i, i)
			if     ch == "{" then depth += 1
			elseif ch == "}" then
				depth -= 1
				if depth == 0 then
					local body  = string.sub(source, braceStart + 1, i - 1)
					local names = {}
					for valueName in string.gmatch(body, "[%a_][%w_]*%s*=%s*([%a_][%w_]*)") do names[valueName] = true end
					return names
				end
			end
			i += 1
		end
	end

	return {}
end

local function stripCompileOnlyUiSource(source)
	local fragmentLocals = extractFragmentLocalNames(source)

	source = select(1, stripLongBracketAssignment(source, "[%a_][%w_]*%.ui%s*=%s*"))
	source = stripFragmentsAssignment(source)

	for localName in pairs(fragmentLocals) do
		source = select(1, stripLongBracketAssignment(source, "local%s+" .. localName .. "%s*=%s*"))
	end

	source = string.gsub(source, "\n[ \t]*\n[ \t]*\n+", "\n\n")

	return source
end

-- ——— compiler api ———————————————————————————————————————

local function buildInlineAppFactory(appModule)
	if typeof(appModule) ~= "Instance" or not appModule:IsA("ModuleScript") then
		error("Rui standalone compile requires an app ModuleScript")
	end

	local source = appModule.Source
	if type(source) ~= "string" or source == "" then error("Rui could not read app module source") end

	source = stripCompileOnlyUiSource(source)

	return table.concat({
		"(function()",
		"    local __rui_app_module = function()",
		source,
		"    end",
		"    return __rui_app_module()",
		"end)",
	}, "\n")
end

function Rui.compile(app, appModule)
	local appMod        = appModule or app
	local runtimeSource = string.gsub(RuntimeSource, "__RUI_INLINE_APP_FACTORY__", buildInlineAppFactory(appMod))
	return Compiler.generate_from_app(resolveAppTable(app), runtimeSource, Xml)
end

-- ——— mount / lifecycle ——————————————————————————————————

local function createMountHandle(roots)
	local handle = { roots = roots or {} }

	function handle:unmount()
		if not self.roots then return end

		for _, root in ipairs(self.roots) do
			if root and root.Parent then root:Destroy() end
		end

		self.roots = nil
	end

	return handle
end

function Rui.mount(compiledModule)
	if typeof(compiledModule) ~= "Instance" or not compiledModule:IsA("ModuleScript") then
		error("Rui.mount expected a ModuleScript")
	end

	local ok, result = pcall(require, compiledModule)
	if not ok then error("Rui.mount failed: " .. tostring(result)) end

	return createMountHandle(type(result) == "table" and result or {})
end

function Rui.unmount(handle)
	if type(handle) == "table" and type(handle.unmount) == "function" then handle:unmount()
	else error("Rui.unmount expected a mount handle") end
end

-- ——— interaction ————————————————————————————————————————

function Rui.getById(id)
	for _, instance in ipairs(CollectionService:GetTagged(id)) do
		if instance and instance.Parent ~= nil then return instance end
	end
	return nil
end

function Rui.getAllById(id)
	local out = {}
	for _, instance in ipairs(CollectionService:GetTagged(id)) do
		if instance and instance.Parent ~= nil then table.insert(out, instance) end
	end
	return out
end

return Rui
