local DEBUG = false

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local CS = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local APPS_FOLDER_NAME = "RuiApp"
local OUTPUT_FOLDER_NAME = "__RUI_COMPILED"
local BOOTSTRAP_NAME = "__RUI_BOOTSTRAP"
local SERVER_CLEANUP_NAME = "__RUI_PREVIEW_CLEANUP"
local RUI_MODULE_FILENAMES = { "core.luau", "rui.luau", "runtime.luau", "xml.luau", "std.luau", "inliner.luau" }
local RUI_RAW_BASE_URL = "https://raw.githubusercontent.com/debxylen/Rui/refs/heads/main/lib/"

local RUI_MODULE = RS:WaitForChild("Rui"):WaitForChild("rui")

local TEMP_FOLDER = RS:FindFirstChild("__RUI_TEMP") or Instance.new("Folder")
TEMP_FOLDER.Name = "__RUI_TEMP"

local _print = print
local function print(...) if DEBUG then _print(...) end end

-- ——— reloads ————————————————————————————————————————————

local reloading = false
local previewHandles = {}
local autoCompileEnabled = true

local function safeRequire(module)
	local appRoot = module.Parent
	local package = Instance.new("Folder")

	package.Name = "__APP_" .. module.Name
	package.Parent = TEMP_FOLDER

	for _, child in ipairs(appRoot:GetChildren()) do
		child:Clone().Parent = package end

	local clone = package:FindFirstChild(module.Name)
	if not clone or not clone:IsA("ModuleScript") then
		package:Destroy()
		error("Failed to clone Rui app module")
	end

	local ok, result = pcall(require, clone)
	package:Destroy()

	if not ok then
		error(result) end

	return result
end

local function freshRequireRui(ruiModule)
	TEMP_FOLDER:ClearAllChildren()

	local ruiFolder = ruiModule.Parent

	for _, child in ipairs(ruiFolder:GetChildren()) do
		if child:IsA("ModuleScript") then
			child:Clone().Parent = TEMP_FOLDER
		end
	end

	local clonedRui = TEMP_FOLDER:FindFirstChild(ruiModule.Name)
	if not clonedRui then
		error("Failed to clone Rui module") end

	return require(clonedRui)
end

local function reloadRui(async)
	if reloading then return end
	reloading = true

	local function doReload()
		print("[Rui] Reloading Rui as async="..tostring(async))
		freshRequireRui(RUI_MODULE)
		print("[Rui] Reloaded Rui")
		reloading = false
	end

	if async then
		task.delay(0.2, doReload)
	else
		doReload() end
end

local function mountPreview(compiledModule, ruiInstance)
	if RunService:IsRunning() then
		return end

	local existing = previewHandles[compiledModule.Name]
	if existing then
		pcall(function()
			existing:unmount()
		end)
		previewHandles[compiledModule.Name] = nil
	end

	local ok, handle = pcall(function()
		return ruiInstance.mount(compiledModule)
	end)

	if not ok then
		warn("[Rui] Preview mount failed:", handle)
		return
	end

	previewHandles[compiledModule.Name] = handle
	print("[Rui] Preview mounted:", compiledModule.Name)
end

reloadRui(false)

-- ——— folders ————————————————————————————————————————————

local function getAppsFolder()
	local folder = RS:FindFirstChild(APPS_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = APPS_FOLDER_NAME
		folder.Parent = RS
	end
	return folder
end

local function getOutputFolder()
	local folder = RS:FindFirstChild(OUTPUT_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = OUTPUT_FOLDER_NAME
		folder.Parent = RS
	end
	return folder
end

-- ——— bootstrap ——————————————————————————————————————————

local function ensureBootstrap()
	local starterPlayer = game:GetService("StarterPlayer")
	local sps = starterPlayer:WaitForChild("StarterPlayerScripts")

	local existing = sps:FindFirstChild(BOOTSTRAP_NAME)

	local source = [[
local RS = game:GetService("ReplicatedStorage")

local compiledFolder = RS:WaitForChild("__RUI_COMPILED")
local rui = require(RS:WaitForChild("Rui"):WaitForChild("rui"))

for _, mod in ipairs(compiledFolder:GetChildren()) do
	if mod:IsA("ModuleScript") then
		rui.mount(mod)
	end
end
]]

	if existing then
		if existing:IsA("LocalScript") and existing.Source ~= source then
			existing.Source = source
			print("[Rui] Updated bootstrap")
		end
		return
	end

	local script = Instance.new("LocalScript")
	script.Name = BOOTSTRAP_NAME
	script.Source = source
	script.Parent = sps

	print("[Rui] Created bootstrap")
end

local function ensureServerCleanup()
	local serverScriptService = game:GetService("ServerScriptService")
	local existing = serverScriptService:FindFirstChild(SERVER_CLEANUP_NAME)

	local source = [[
local starterGui = game:GetService("StarterGui")

local function cleanup(child)
	if string.match(child.Name, "^__RUI_PREVIEW_") then
		child:Destroy()
	end
end

for _, child in ipairs(starterGui:GetChildren()) do
	cleanup(child)
end

starterGui.ChildAdded:Connect(cleanup)
]]

	if existing then
		if existing:IsA("Script") and existing.Source ~= source then
			existing.Source = source
			print("[Rui] Updated preview cleanup")
		end
		return
	end

	local scriptInstance = Instance.new("Script")
	scriptInstance.Name = SERVER_CLEANUP_NAME
	scriptInstance.Source = source
	scriptInstance.Parent = serverScriptService

	print("[Rui] Created preview cleanup")
end

-- ——— compiles ———————————————————————————————————————————

local function compileApp(appModule)
	local ruiFolder = RS:FindFirstChild("Rui", true)
	if not ruiFolder then error("Could not find Rui folder") end

	local successfulRui = freshRequireRui(ruiFolder:FindFirstChild("rui"))

	local ok, result = pcall(function()
		local appTable = safeRequire(appModule)
		return successfulRui.compile(appTable, appModule)
	end)

	if not ok then
		warn("[Rui] Compile error in", appModule.Name, result)
		return
	end

	local outFolder = getOutputFolder()

	CS:SetWaypoint("Before app update")

	local mod = outFolder:FindFirstChild(appModule.Name)
	if mod then mod:Destroy() end

	mod = Instance.new("ModuleScript")
	mod.Name = appModule.Name
	mod.Parent = outFolder
	mod.Source = result

	CS:SetWaypoint("After app update")

	print("[Rui] Compiled:", appModule.Name)
	mountPreview(mod, successfulRui)
end

local function compileAll()
	for _, child in ipairs(getAppsFolder():GetChildren()) do
		if child:IsA("ModuleScript") then
			compileApp(child)
		end
	end
end

local compiling = false
local function scheduleCompile()
	if not autoCompileEnabled then return end
	if compiling then return end
	compiling = true

	task.delay(0.25, function()
		compiling = false
		compileAll()
	end)
end

-- ——— rui setups —————————————————————————————————————————

local function install()
	local ruiFolder = RS:FindFirstChild("Rui")
	if not ruiFolder then
		ruiFolder = Instance.new("Folder")
		ruiFolder.Name = "Rui"
		ruiFolder.Parent = RS
	end

	for _, filename in ipairs(RUI_MODULE_FILENAMES) do
		local moduleName = string.gsub(filename, "%.luau$", "")
		local url = RUI_RAW_BASE_URL .. filename .. "?t=" .. HttpService:GenerateGUID(false)

		local ok, source = pcall(function()
			return HttpService:GetAsync(url)
		end)

		if not ok then
			error("[Rui] Failed to fetch " .. filename .. ": " .. tostring(source)) end

		local mod = ruiFolder:FindFirstChild(moduleName)
		if mod and not mod:IsA("ModuleScript") then
			mod:Destroy()
			mod = nil
		end

		if not mod then
			mod = Instance.new("ModuleScript")
			mod.Name = moduleName
			mod.Parent = ruiFolder
		end

		if mod.Source ~= source then
			mod.Source = source end
	end

	getAppsFolder()
	getOutputFolder()
	ensureBootstrap()
	ensureServerCleanup()
end

-- ——— plugin ui ——————————————————————————————————————————

local toolbar = plugin:CreateToolbar("Rui")
local openButton = toolbar:CreateButton("Rui", "Open Rui controls", "rbxassetid://78911013759754")
openButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	true,
	360,
	360,
	320,
	300
)

local widget = plugin:CreateDockWidgetPluginGuiAsync("RuiControlPanel", widgetInfo)
widget.Title = "Rui"

local root = Instance.new("ScrollingFrame")
root.Name = "Root"
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
root.BorderSizePixel = 0
root.CanvasSize = UDim2.new()
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.ScrollBarThickness = 6
root.Parent = widget

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Top
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = root

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 14)
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.PaddingBottom = UDim.new(0, 14)
padding.Parent = root

local nextLayoutOrder = 0
local function allocLayoutOrder()
	nextLayoutOrder += 1
	return nextLayoutOrder
end

local function makeLabel(text, height, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, height or 22)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(230, 230, 235)
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = allocLayoutOrder()
	label.Parent = root
	return label
end

local function makeButton(name, text, bgColor, onClick)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 34)
	button.BackgroundColor3 = bgColor
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = text
	button.AutoButtonColor = true
	button.LayoutOrder = allocLayoutOrder()
	button.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	button.Activated:Connect(onClick)
	return button
end

local title = makeLabel("Rui Controls", 22, Color3.fromRGB(255, 255, 255))
title.Font = Enum.Font.GothamBold
title.TextSize = 16

local statusLabel = makeLabel("", 36, Color3.fromRGB(180, 190, 205))
local autoCompileButton

local function refreshUi()
	local apps = {}
	for _, child in ipairs(getAppsFolder():GetChildren()) do
		if child:IsA("ModuleScript") then
			table.insert(apps, child.Name)
		end
	end

	if autoCompileButton then
		autoCompileButton.Text = autoCompileEnabled and "Auto-Compile: ON" or "Auto-Compile: OFF"
		autoCompileButton.BackgroundColor3 = autoCompileEnabled and Color3.fromRGB(56, 92, 63) or Color3.fromRGB(92, 62, 56)
	end

	statusLabel.Text = "Apps (" .. #apps .. "): " .. table.concat(apps, ", ")
end

makeButton("Install", "Install Rui", Color3.fromRGB(53, 78, 118), function()
	install()
	refreshUi()
end)

autoCompileButton = makeButton("AutoCompile", "", Color3.fromRGB(56, 92, 63), function()
	autoCompileEnabled = not autoCompileEnabled
	refreshUi()
end)

makeButton("CompileAll", "Compile All Apps", Color3.fromRGB(78, 62, 118), function()
	compileAll()
	refreshUi()
end)

refreshUi()

openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- ——— hooks ——————————————————————————————————————————————

local hookedAppModules = {}

local function hookAppModule(mod)
	if hookedAppModules[mod] then return end
	hookedAppModules[mod] = true

	mod.Changed:Connect(function(prop)
		if prop == "Source" then
			print("[Rui] App changed:", mod.Name)
			scheduleCompile()
		end
	end)
end

local function hookRuiModule(mod)
	mod.Changed:Connect(function(prop)
		if prop == "Source" then
			print("[Rui] Rui changed:", mod.Name)
			reloadRui(true)
			scheduleCompile()
		end
	end)
end

-- ——— init ———————————————————————————————————————————————

local appsFolder = getAppsFolder()
local ruiFolder = RUI_MODULE.Parent

for _, child in ipairs(appsFolder:GetChildren()) do
	if child:IsA("ModuleScript") then
		hookAppModule(child)
	end
end

for _, child in ipairs(appsFolder:GetDescendants()) do
	if child:IsA("ModuleScript") then
		hookAppModule(child)
	end
end

appsFolder.ChildAdded:Connect(function(child)
	if child:IsA("ModuleScript") then
		hookAppModule(child)
		scheduleCompile()
	end
end)

appsFolder.DescendantAdded:Connect(function(child)
	if child:IsA("ModuleScript") then
		hookAppModule(child)
		scheduleCompile()
	end
end)

for _, child in ipairs(ruiFolder:GetChildren()) do
	if child:IsA("ModuleScript") then
		hookRuiModule(child)
	end
end

ruiFolder.ChildAdded:Connect(function(child)
	if child:IsA("ModuleScript") then
		hookRuiModule(child)
	end
end)

ensureBootstrap()
ensureServerCleanup()
compileAll()

print("[Rui] Compiler running")
