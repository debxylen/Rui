local Compiler      = require(script.Parent.core)
local RuntimeSource = require(script.Parent.runtime)
local Factory       = require(script.Parent.factory)

local CollectionService = game:GetService("CollectionService")

local Rui = {}
local Handles = {}

-- ——— helpers ———————————————————————————————————————————

local function try(fn, ...)
	local args = table.pack(...)

	return xpcall(
		function() return fn(table.unpack(args, 1, args.n)) end,
		function(err) return debug.traceback(tostring(err), 2) end
	)
end

local function createMountHandle(roots, module)
	if Handles[module] then error("Handle for module " .. module.Name .. " already exists") end
	local handle = { roots = roots or {} }

	function handle:unmount()
		if not self.roots then return end

		for _, root in ipairs(self.roots) do
			if root and root.Parent then root:Destroy() end
		end

		if type(self.roots.cleanup) == "function" then
			local ok, result = try(self.roots.cleanup)
			if not ok then warn("[Rui] Cleanup error: " .. tostring(result)) end
		end

		self.roots = nil
		Handles[module] = nil
	end

	Handles[module] = handle
	return handle
end

-- ——— api ————————————————————————————————————————————————

function Rui.compile(app, autoMount)
	if typeof(app) == "Instance" and app:IsA("ModuleScript") then return Rui.compileModule(app, autoMount)
	elseif type(app) == "table" then return Rui.compileTable(app, autoMount)
	else error("Rui.compile expected a table or ModuleScript") end
end

function Rui.compileModule(appMod, autoMount)
	if not (typeof(appMod) == "Instance" and appMod:IsA("ModuleScript")) then error("Rui.compileModule expected a ModuleScript") end

	local appFactorySource = Factory.buildAppFactory(appMod):gsub("%%", "%%%%")
	local runtimeSource = string.gsub(RuntimeSource, "__RUI_INLINE_APP_FACTORY__", appFactorySource):gsub("^%s+", ""):gsub("%s+$", "")
	return Compiler.generate_from_app(require(appMod :: Instance), appMod, runtimeSource, autoMount ~= false)
end

function Rui.compileResolved(app, appMod, autoMount)
	if type(app) ~= "table" then error("Rui.compileResolved expected an app table for argument 'app'") end
	if not (typeof(appMod) == "Instance" and appMod:IsA("ModuleScript")) then error("Rui.compileResolved expected an app ModuleScript for argument 'appMod'") end

	local appFactorySource = Factory.buildAppFactory(appMod):gsub("%%", "%%%%")
	local runtimeSource = string.gsub(RuntimeSource, "__RUI_INLINE_APP_FACTORY__", appFactorySource):gsub("^%s+", ""):gsub("%s+$", "")
	return Compiler.generate_from_app(app, appMod, runtimeSource, autoMount ~= false)
end

function Rui.compileTable(app, autoMount)
	if type(app) ~= "table" then error("Rui.compileTable expected an app table") end

	local appFactorySource = Factory.buildAppFactory(app):gsub("%%", "%%%%")
	local runtimeSource = string.gsub(RuntimeSource, "__RUI_INLINE_APP_FACTORY__", appFactorySource):gsub("^%s+", ""):gsub("%s+$", "")
	return Compiler.generate_from_app(app, nil, runtimeSource, autoMount ~= false)
end

function Rui.mount(compiledModule)
	if typeof(compiledModule) ~= "Instance" or not compiledModule:IsA("ModuleScript") then
		error("Rui.mount expected a ModuleScript; use loadstring() for in-memory compiled source.") end

	local result = require(compiledModule)()
	return createMountHandle(result, compiledModule)
end

function Rui.unmount(handle)
	if type(handle) == "table" and type(handle.unmount) == "function" then handle:unmount()
	else error("Rui.unmount expected a mount handle") end
end

function Rui.getHandle(module)
	if typeof(module) ~= "Instance" or not module:IsA("ModuleScript") then
		error("Rui.getHandle expected a ModuleScript") end

	return Handles[module]
end

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
