local Compiler      = require(script.Parent.core)
local Xml           = require(script.Parent.xml)
local RuntimeSource = require(script.Parent.runtime)
local Inliner       = require(script.Parent.inliner)

local CollectionService = game:GetService("CollectionService")

local Rui = {}

-- ——— helpers ———————————————————————————————————————————

local function resolveAppTable(app)
	if typeof(app) == "Instance" and app:IsA("ModuleScript") then return require(app :: Instance) end
	if type(app) == "table" then return app end

	error("Rui expected an app ModuleScript or app table")
end

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

-- ——— api ————————————————————————————————————————————————

function Rui.compile(app, appModule)
	local appMod = appModule or app
	local appFactorySource = Inliner.buildInlineAppFactory(appMod)
	local runtimeSource = string.gsub(RuntimeSource, "__RUI_INLINE_APP_FACTORY__", function() return appFactorySource end)
	return Compiler.generate_from_app(resolveAppTable(app), runtimeSource, Xml)
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
