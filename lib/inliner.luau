local std = require(script.Parent.std)
local str = std.str

local Inliner = {}

-- ——— helpers ————————————————————————————————————————————

local function splitPath(path)
	local out = {}
	for part in string.gmatch(path, "[^%.]+") do table.insert(out, part) end
	return out
end

local function getRelModId(root, module)
	local parts   = {}
	local current = module

	while current and current ~= root do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end

	if current ~= root then return nil end
	return table.concat(parts, "/")
end

local function resolveScript(currentModule, expr)
	if not string.match(expr, "^script%.") then return nil end

	local current      = currentModule
	local scriptPrefix = "script."

	for _, part in ipairs(splitPath(string.sub(expr, #scriptPrefix + 1))) do
		if part == "Parent" then current = current and current.Parent
		else current = current and current:FindFirstChild(part) end

		if not current then return nil end
	end

	return current
end

local function resolveAlias(aliases, expr)
	local parts   = splitPath(expr)
	local current = aliases[parts[1]]
	if not current then return nil end

	for i = 2, #parts do
		current = current and current:FindFirstChild(parts[i])
		if not current then return nil end
	end

	return current
end

local function findAliases(source, currentModule)
	local aliases = {}

	for alias, expr in string.gmatch(source, "local%s+([%a_][%w_]*)%s*=%s*(script%.Parent[%w_%.]*)") do
		local target = resolveScript(currentModule, expr)
		if target then aliases[alias] = target end
	end

	return aliases
end

local function isCompileOnly(source)
	return string.match(source, "^%s*%-%-!rui%s+compile%-only") ~= nil
end

-- ——— api ————————————————————————————————————————————————

function Inliner.buildInlineAppFactory(appModule)
	if typeof(appModule) ~= "Instance" or not appModule:IsA("ModuleScript") then
		error("Rui standalone compile requires an app ModuleScript")
	end

	local appRoot = appModule.Parent
	if not appRoot then error("Rui app ModuleScript must have a parent") end

	local modules    = {}
	local orderedIds = {}

	local processModule

	local function registerModule(module)
		local id = getRelModId(appRoot, module)
		if not id then error("[Rui] Refusing to inline module outside app root: " .. module:GetFullName()) end

		if not modules[id] then
			table.insert(orderedIds, id)
			modules[id] = { module = module, source = nil }
		end

		return id
	end

	local function rewriteRequire(target)
		if not target then return nil end

		if typeof(target) ~= "Instance" or not target:IsA("ModuleScript") then
			error("[Rui] Inlined require target must be a ModuleScript: " .. target:GetFullName()) end

		local source = target.Source
		if type(source) == "string" and isCompileOnly(source) then return "({})" end

		local id = registerModule(target)
		processModule(target)
		return "__rui_require(" .. str(id) .. ")"
	end

	local function rewriteSource(module, source)
		local aliases = findAliases(source, module)

		source = string.gsub(source, "require%s*%(%s*(script%.Parent[%w_%.]*)%s*%)", function(expr)
			local replacement = rewriteRequire(resolveScript(module, expr))
			return replacement or ("require(" .. expr .. ")")
		end)

		source = string.gsub(source, "require%s*%(%s*([%a_][%w_]*[%w_%.]*)%s*%)", function(expr)
			local replacement = rewriteRequire(resolveAlias(aliases, expr))
			return replacement or ("require(" .. expr .. ")")
		end)

		for alias in pairs(aliases) do
			source = string.gsub(source, "(local%s+" .. alias .. "%s*=%s*)script%.Parent[%w_%.]*", "%1nil")
		end

		return source
	end

	function processModule(module)
		local id     = registerModule(module)
		local record = modules[id]
		if record.source ~= nil then return end

		local source = module.Source
		if type(source) ~= "string" or source == "" then
			error("[Rui] Could not read source for " .. module:GetFullName())
		end

		record.source = rewriteSource(module, source)
	end

	local entrySource = appModule.Source
	if type(entrySource) ~= "string" or entrySource == "" then error("Rui could not read app module source") end

	entrySource = rewriteSource(appModule, entrySource)

	local lines = {
		"(function()",
		"	local __rui_cache   = {}",
		"	local __rui_modules = {}",
		"	local __rui_require",
		"",
	}

	for _, id in ipairs(orderedIds) do
		table.insert(lines, "	__rui_modules[" .. str(id) .. "] = function()")
		table.insert(lines, modules[id].source)
		table.insert(lines, "	end")
		table.insert(lines, "")
	end

	table.insert(lines, "	function __rui_require(id)")
	table.insert(lines, "		if __rui_cache[id] ~= nil then return __rui_cache[id] end")
	table.insert(lines, "		local loader = __rui_modules[id]")
	table.insert(lines, "		if not loader then error(\"[Rui] Missing inlined module: \" .. tostring(id)) end")
	table.insert(lines, "		local result = loader()")
	table.insert(lines, "		__rui_cache[id] = result")
	table.insert(lines, "		return result")
	table.insert(lines, "	end")
	table.insert(lines, "")
	table.insert(lines, "	local __rui_app_module = function()")
	table.insert(lines, entrySource)
	table.insert(lines, "	end")
	table.insert(lines, "	return __rui_app_module()")
	table.insert(lines, "end)")

	return table.concat(lines, "\n")
end

return Inliner
