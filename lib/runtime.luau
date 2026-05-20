return [=[

-- ——— bundle ————————————————————————————————————————————

local app = (__RUI_INLINE_APP_FACTORY__)()
if type(app) ~= "table" then error("[Rui] App module must return a table") end

-- ——— core state ————————————————————————————————————————

local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local state             = app.state or {}
local actions           = app.actions or {}

local bindingsByKey     = {}
local luaBlockBindings  = {}
local computedBindings  = {}
local warnedUnknowns    = {}
local elementsById      = {}

local tweenInfos        = setmetatable({}, { __mode = "k" })
local activeTweens      = setmetatable({}, { __mode = "k" })
local transitionInfos   = setmetatable({}, { __mode = "k" })

-- ——— helpers ———————————————————————————————————————————

local function append(t, v) table.insert(t, v) end

local function warnUnknownAttribute(attrName, propName)
	if warnedUnknowns[attrName] then return end
	warnedUnknowns[attrName] = true
	warn("Rui passed through unknown attribute " .. tostring(attrName) .. " as property " .. tostring(propName))
end

local function renderTemplate(template, scope)
	return (string.gsub(template, "{%s*([%a_][%w_]*)%s*}", function(key)
		local value = (scope and scope[key]) or state[key]
		return value ~= nil and tostring(value) or ""
	end))
end

local function registerBinding(key, binding)
	local bucket = bindingsByKey[key] or {}
	bindingsByKey[key] = bucket
	append(bucket, binding)
end

function registerElementId(id, instance)
	if not id or id == "" then return end
	elementsById[id] = instance
	CollectionService:AddTag(instance, id)
	instance:SetAttribute("RuiId", id)
end

function getById(id)
	local instance = elementsById[id]
	if instance and instance.Parent == nil then
		elementsById[id] = nil
		return nil
	end
	return instance
end

-- ——— tweening / transitions —————————————————————————————

local function canTweenValue(value)
	local t = typeof(value)
	return t == "number" or t == "UDim2" or t == "UDim" or t == "Color3" or t == "Vector2" or t == "Vector3" or t == "CFrame"
end

function setTweenInfo(instance, info)        tweenInfos[instance] = info end
function setTransitionInfo(instance, p, i)   transitionInfos[instance] = { preset = p, tweenInfo = i } end

local function applyPropertyValue(instance, prop, value)
	local info = tweenInfos[instance]
	if not info or not canTweenValue(value) then
		instance[prop] = value
		return
	end

	local ok, current = pcall(function() return instance[prop] end)
	if not ok or current == value then
		instance[prop] = value
		return
	end

	local active   = activeTweens[instance] or {}
	activeTweens[instance] = active

	if active[prop] then active[prop]:Cancel() end

	local tween    = TweenService:Create(instance, info, { [prop] = value })
	active[prop]   = tween
	tween.Completed:Connect(function() if active[prop] == tween then active[prop] = nil end end)
	tween:Play()
end

local function getTransitionGoals(instance, preset)
	if not instance:IsA("GuiObject") then return nil, nil end

	local enter, exit = {}, {}
	local hasAny      = false

	local function setPair(p, en, ex) enter[p], exit[p] = en, ex; hasAny = true end

	local okBg,   bg   = pcall(function() return instance.BackgroundTransparency end)
	local okText, text = pcall(function() return instance.TextTransparency end)
	local okPos,  pos  = pcall(function() return instance.Position end)
	local okGrp,  grp  = pcall(function() return instance.GroupTransparency end)

	if preset:match("^fade") or preset == "modal" or preset == "toast" then
		if okGrp then
			setPair("GroupTransparency", grp, 1)
		else
			if okBg then   setPair("BackgroundTransparency", bg, 1) end
			if okText then setPair("TextTransparency", text, 1) end
		end
	end

	if preset == "slideUp" or preset == "modal" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale + 0.04, pos.Y.Offset + 24)) end

	elseif preset == "slideDown" or preset == "fadeDown" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale - 0.04, pos.Y.Offset - 24)) end

	elseif preset == "slideLeft" or preset == "fadeLeft" or preset == "toast" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale + 0.04, pos.X.Offset + 24, pos.Y.Scale, pos.Y.Offset)) end

	elseif preset == "slideRight" or preset == "fadeRight" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale - 0.04, pos.X.Offset - 24, pos.Y.Scale, pos.Y.Offset)) end

	elseif preset == "fadeUp" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale + 0.04, pos.Y.Offset + 24)) end end

	return hasAny and enter or nil, exit
end

local function collectTransitionTargets(roots)
	local targets = {}
	local function visit(ins)
		if transitionInfos[ins] then append(targets, ins) end
		for _, c in ipairs(ins:GetChildren()) do visit(c) end
	end
	for _, r in ipairs(roots) do if r then visit(r) end end
	return targets
end

-- fade all painted children alongside the root, cuz idk why it wont do that itself even in canvasgroup
local function tweenDescendants(root, tweenInfo, alpha)
	local function visit(ins)
		if not ins:IsA("GuiObject") then return end
		local goals = {}

		local okBg, _ = pcall(function() return ins.BackgroundTransparency end)
		if okBg and ins.BackgroundTransparency < 1 then goals.BackgroundTransparency = alpha end

		local okTx, _ = pcall(function() return ins.TextTransparency end)
		if okTx then goals.TextTransparency = alpha end

		if next(goals) then TweenService:Create(ins, tweenInfo, goals):Play() end
		for _, c in ipairs(ins:GetChildren()) do visit(c) end
	end
	for _, c in ipairs(root:GetChildren()) do visit(c) end
end

function playEnterTransitions(roots)
	for _, ins in ipairs(collectTransitionTargets(roots)) do
		local cfg         = transitionInfos[ins]
		local enter, exit = getTransitionGoals(ins, cfg.preset)
		if enter then
			for p, start in pairs(exit) do ins[p] = start end
			TweenService:Create(ins, cfg.tweenInfo, enter):Play()
		end
	end
end

function playExitTransitions(roots, onDone)
	local targets = collectTransitionTargets(roots)
	local maxTime = 0
	local played  = false

	for _, ins in ipairs(targets) do
		local cfg         = transitionInfos[ins]
		local _, exit     = getTransitionGoals(ins, cfg.preset)
		if next(exit) then
			played  = true
			maxTime = math.max(maxTime, cfg.tweenInfo.Time)
			TweenService:Create(ins, cfg.tweenInfo, exit):Play()
			local isFade = cfg.preset:match("^fade") or cfg.preset == "modal" or cfg.preset == "toast"
			if isFade then tweenDescendants(ins, cfg.tweenInfo, 1) end
		end
	end

	if not played then onDone() else task.delay(maxTime, onDone) end
end

-- ——— bindings ——————————————————————————————————————————

function bindText(instance, template, deps)
	for _, key in ipairs(deps) do registerBinding(key, { instance = instance, template = template }) end
	instance.Text = renderTemplate(template)
end

function bindComputed(instance, prop, computer, scope)
	local binding = { instance = instance, propName = prop, computer = computer, scope = scope }
	append(computedBindings, binding)
	updateComputed(binding)
end

function bindLuaBlock(parent, selector, factories, scope)
	local binding = { parent = parent, selector = selector, factories = factories, scope = scope, mounted = {}, revision = 0 }
	append(luaBlockBindings, binding)
	updateLuaBlock(binding)
end

-- ——— state updates ——————————————————————————————————————

function setState(key, value)
	state[key] = value
	app.state  = state

	if type(app.onStateChanged) == "function" then app.onStateChanged(state, key, value) end

	local bindings = bindingsByKey[key]
	if bindings then
		for _, b in ipairs(bindings) do
			if b.instance and b.instance.Parent then b.instance.Text = renderTemplate(b.template) end
		end
	end

	for _, b in ipairs(luaBlockBindings) do updateLuaBlock(b) end
	for _, b in ipairs(computedBindings) do updateComputed(b) end
end

-- ——— structure helpers ——————————————————————————————————

local function normalizeLuaBlockSelection(selected)
	if selected == nil then return nil, nil end

	if type(selected) == "table" and selected.key ~= nil then
		return tostring(selected.key), { { key = tostring(selected.key), scope = selected.scope } }
	end

	if type(selected) == "table" then
		local entries = {}
		local parts   = {}
		for _, v in ipairs(selected) do
			if v ~= nil then
				local k = tostring(type(v) == "table" and v.key or v)
				append(entries, { key = k, scope = type(v) == "table" and v.scope or nil })
				append(parts, k)
			end
		end
		return #parts > 0 and table.concat(parts, "\0") or "", entries
	end

	return tostring(selected), { { key = tostring(selected), scope = nil } }
end

-- ——— actions ———————————————————————————————————————————

local function coerceActionValue(raw)
	if raw == "true"  then return true end
	if raw == "false" then return false end
	if raw == "nil"   then return nil end
	return tonumber(raw) or raw
end

function navigate(routeName)
	if type(app.navigate) == "function" then
		app.navigate({ route = routeName, state = state, setState = setState, dispatch = dispatch, navigate = navigate })
		return
	end
	setState("route", routeName)
end

local function buildHandlerContext(instance, payload, scope, event)
	return {
		instance = instance, payload = payload, scope = scope, event = event,
		state = state, setState = setState, dispatch = dispatch,
		navigate = navigate, getById = getById
	}
end

function dispatch(name, payload, instance, scope, event)
	local handler = actions[name]
	if handler then handler(buildHandlerContext(instance, payload, scope, event))
	else warn("Missing action: " .. tostring(name)) end
end

function invokeAction(name, scope, payload, event)
	local handler = actions[name]
	if handler then return handler(buildHandlerContext(nil, payload, scope, event))
	else warn("Missing action: " .. tostring(name)) end
end

function runAction(spec, instance, scope, event)
	local colon = string.find(spec, ":", 1, true)
	if not colon then dispatch(spec, nil, instance, scope, event); return end

	local name = string.sub(spec, 1, colon - 1)
	local rest = string.sub(spec, colon + 1)
	local s2   = string.find(rest, ":", 1, true)

	local a, b = rest, ""
	if s2 then a, b = string.sub(rest, 1, s2 - 1), string.sub(rest, s2 + 1) end

	if     name == "navigate" then navigate(a)
	elseif name == "dispatch" then dispatch(a, nil, instance, scope, event)
	elseif name == "toggle"   then setState(a, not state[a])
	elseif name == "set"      then setState(a, coerceActionValue(b))
	else dispatch(spec, nil, instance, scope, event) end
end

function bindEvent(instance, prop, signalName, handlerName, scope)
	local ok, signal = pcall(function() return instance[signalName] end)
	if ok and signal then signal:Connect(function(...) runAction(handlerName, instance, scope, ...) end)
	else warn(prop .. " requires signal " .. signalName .. " on " .. instance.ClassName) end
end

function bindEventExpr(instance, prop, signalName, fn, scope)
	local ok, signal = pcall(function() return instance[signalName] end)
	if ok and signal then signal:Connect(function(...) fn(scope, ...) end)
	else warn(prop .. " requires signal " .. signalName .. " on " .. instance.ClassName) end
end

-- ——— render lifecycle ——————————————————————————————————

if type(app.init) == "function" then
	app.init({
		state    = state,
		setState = setState,
		dispatch = dispatch,
		navigate = navigate,
		getById  = getById,
	})
end

function updateComputed(binding)
	if not binding.instance then return end
	local ok, val = pcall(binding.computer, binding.scope)
	if ok then applyPropertyValue(binding.instance, binding.propName, val)
	else warn("Computed failed for " .. tostring(binding.propName) .. ": " .. tostring(val)) end
end

function updateLuaBlock(binding)
	local ok, selection = pcall(binding.selector, binding.scope)
	if not ok then warn("LuaBlock failed: " .. tostring(selection)); return end

	local signature, keys = normalizeLuaBlockSelection(selection)
	if signature == binding.currentKey then return end

	binding.revision   = (binding.revision or 0) + 1
	local rev          = binding.revision
	local prev         = binding.mounted
	binding.mounted    = {}
	binding.currentKey = signature

	if prev and #prev > 0 then
		playExitTransitions(prev, function()
			if binding.revision ~= rev then return end
			for _, ins in ipairs(prev) do if ins then ins:Destroy() end end
		end)
	end

	if not keys then return end

	local created = {}
	for _, entry in ipairs(keys) do
		local factory = binding.factories[entry.key]
		if factory then
			local roots = factory(binding.parent, entry.scope)
			for _, r in ipairs(roots) do append(created, r) end
		else
			warn("LuaBlock missing factory for key " .. tostring(entry.key))
		end
	end

	if binding.revision ~= rev then
		for _, ins in ipairs(created) do if ins then ins:Destroy() end end
		return
	end

	binding.mounted = created
	playEnterTransitions(binding.mounted)
end
]=]
