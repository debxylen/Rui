return [=[

-- ——— bundle ————————————————————————————————————————————

local app = (__RUI_INLINE_APP_FACTORY__)()
if type(app) ~= "table" then error("[Rui] App module must return a table") end

local _cleanup_fn = nil

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
local exitingInstances  = setmetatable({}, { __mode = "k" })

-- ——— helpers ———————————————————————————————————————————

local function append(t, v) table.insert(t, v) end

local function warnUnknownAttribute(attrName, propName)
	if warnedUnknowns[attrName] then return end
	warnedUnknowns[attrName] = true
	warn("Rui passed through unknown attribute " .. tostring(propName))
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

function setTweenInfo(instance, info)
	tweenInfos[instance] = info end

function setTransitionInfo(instance, enterPreset, enterInfo, exitPreset, exitInfo)
	transitionInfos[instance] = { enterPreset = enterPreset, enterInfo = enterInfo, exitPreset = exitPreset, exitInfo = exitInfo } end

local function tweenProperties(instance, tweenInfo, goals)
	if not activeTweens[instance] then activeTweens[instance] = {} end
	local active = activeTweens[instance]

	for prop in pairs(goals) do
		if active[prop] then active[prop]:Cancel() end end

	local tween = TweenService:Create(instance, tweenInfo, goals)
	for prop in pairs(goals) do active[prop] = tween end

	tween.Completed:Connect(function()
		for prop in pairs(goals) do
			if active[prop] == tween then active[prop] = nil end end
	end)

	tween:Play()
	return tween
end

local function applyPropertyValue(instance, prop, value)
	if exitingInstances[instance] then return end

	local info = tweenInfos[instance]
	if not info or not canTweenValue(value) then instance[prop] = value; return end

	local ok, current = pcall(function() return instance[prop] end)
	if not ok or current == value then instance[prop] = value; return end

	tweenProperties(instance, info, { [prop] = value })
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

	if preset and (preset:match("^fade") or preset == "modal" or preset == "toast") then
		if okGrp 	  then setPair("GroupTransparency", grp, 1)
		else
			if okBg   then setPair("BackgroundTransparency", bg, 1) end
			if okText then setPair("TextTransparency", text, 1) end end end

	if preset == "slideUp" or preset == "fadeUp" or preset == "modal" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale + 0.04, pos.Y.Offset + 24)) end

	elseif preset == "slideDown" or preset == "fadeDown" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale - 0.04, pos.Y.Offset - 24)) end

	elseif preset == "slideLeft" or preset == "fadeLeft" or preset == "toast" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale + 0.04, pos.X.Offset + 24, pos.Y.Scale, pos.Y.Offset)) end

	elseif preset == "slideRight" or preset == "fadeRight" then
		if okPos then setPair("Position", pos, UDim2.new(pos.X.Scale - 0.04, pos.X.Offset - 24, pos.Y.Scale, pos.Y.Offset)) end end

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

-- ok so turns out all children dont get faded along even in canvasgroup, if ur not using ZIndexBehavior="Sibling"
-- but we still keep this anyway
local function tweenDescendants(root, tweenInfo, alpha, snapFrom)
	local function visit(ins)
		if not ins:IsA("GuiObject") then return end
		local goals = {}

		local okBg, _ = pcall(function() return ins.BackgroundTransparency end)
		if okBg and ins.BackgroundTransparency < 1 then
			local to = snapFrom and ins.BackgroundTransparency or alpha
			if snapFrom then ins.BackgroundTransparency = snapFrom end
			goals.BackgroundTransparency = to end

		local okTx, _ = pcall(function() return ins.TextTransparency end)
		if okTx and ins.TextTransparency < 1 then
			local to = snapFrom and ins.TextTransparency or alpha
			if snapFrom then ins.TextTransparency = snapFrom end
			goals.TextTransparency = to end

		local okImg, _ = pcall(function() return ins.ImageTransparency end)
		if okImg and ins.ImageTransparency < 1 then
			local to = snapFrom and ins.ImageTransparency or alpha
			if snapFrom then ins.ImageTransparency = snapFrom end
			goals.ImageTransparency = to end

		if next(goals) then tweenProperties(ins, tweenInfo, goals) end
		for _, c in ipairs(ins:GetChildren()) do visit(c) end
	end
	for _, c in ipairs(root:GetChildren()) do visit(c) end
end

function playEnterTransitions(roots)
	for _, ins in ipairs(roots) do
		local cfg = transitionInfos[ins]
		if not cfg then continue end

		local enter, exit = getTransitionGoals(ins, cfg.enterPreset)
		if not enter then continue end

		for p, start in pairs(exit) do ins[p] = start end
		tweenProperties(ins, cfg.enterInfo, enter)

		local isFade = cfg.enterPreset and (cfg.enterPreset:match("^fade") or cfg.enterPreset == "modal" or cfg.enterPreset == "toast")
		if isFade then tweenDescendants(ins, cfg.enterInfo, 0, 1) end
	end
end

function playExitTransitions(roots, onDone)
	local targets = collectTransitionTargets(roots)
	local maxTime = 0
	local played  = false

	for _, ins in ipairs(targets) do
		exitingInstances[ins] = true
		for _, son in ipairs(ins:GetDescendants()) do
			exitingInstances[son] = true end

		local cfg     = transitionInfos[ins]
		local _, exit = getTransitionGoals(ins, cfg.exitPreset)

		if exit and next(exit) then
			played  = true
			maxTime = math.max(maxTime, cfg.exitInfo.Time)
			tweenProperties(ins, cfg.exitInfo, exit)
			local isFade = cfg.exitPreset and (cfg.exitPreset:match("^fade") or cfg.exitPreset == "modal" or cfg.exitPreset == "toast")
			if isFade then tweenDescendants(ins, cfg.exitInfo, 1) end
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
	binding.ready = true
end

function bindLuaBlock(parent, selector, factories, scope)
	local binding = { parent = parent, selector = selector, factories = factories, scope = scope, mounted = {}, revision = 0 }
	append(luaBlockBindings, binding)
	updateLuaBlock(binding)
end

function bindStyleState(instance, propName, config, scope)
	local isHovered = false
	local isActive  = false

	local defaultVal = nil
	local ok, current = pcall(function() return instance[propName] end)
	if ok then defaultVal = current end
	
	local function evaluate(val)
		if type(val) == "function" then return val(scope)
		else return val end
	end

	local function update()
		if not instance or not instance.Parent then return end
		local targetVal = nil

		if isActive and config.active ~= nil then
			targetVal = evaluate(config.active)

		elseif isHovered and config.hover ~= nil then
			targetVal = evaluate(config.hover)

		elseif config.states then
			for _, st in ipairs(config.states) do
				local stateVal  = state[st.key]
				local appliesRn = false

				if st.val ~= nil then appliesRn = (tostring(stateVal) == tostring(st.val))
				else appliesRn = not not stateVal end

				if appliesRn then
					targetVal = evaluate(st.propVal)
					break
		end end end

		if targetVal == nil then
			if config.base ~= nil then targetVal = evaluate(config.base)
			else targetVal = defaultVal end
		end

		if targetVal ~= nil then applyPropertyValue(instance, propName, targetVal) end
	end

	if config.hover ~= nil then
		instance.MouseEnter:Connect(function() isHovered = true; update() end)
		instance.MouseLeave:Connect(function() isHovered = false; update() end)
	end

	if config.active ~= nil then
		instance.InputBegan:Connect(function(input)
			if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
			isActive = true; update()
		end)
		instance.InputEnded:Connect(function(input)
			if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
			isActive = false; update()
		end)
	end

	if config.states then
		for _, st in ipairs(config.states) do
			registerBinding(st.key, { update = update, instance = instance }) end end

	update()
end

-- ——— state updates ——————————————————————————————————————

function gcBindings()
	local live = {}
	for _, b in ipairs(computedBindings) do
		if b.instance and b.instance.Parent then live[#live+1] = b end end
	computedBindings = live
end

function setState(key, value)
	state[key] = value
	app.state  = state

	if type(app.onStateChanged) == "function" then app.onStateChanged(state, key, value) end

	local bindings = bindingsByKey[key]
	if bindings then
		for _, b in ipairs(bindings) do
			if b.update then b.update()
			elseif b.instance and b.instance.Parent then b.instance.Text = renderTemplate(b.template) end
		end
	end

	for _, b in ipairs(luaBlockBindings) do updateLuaBlock(b) end
	for _, b in ipairs(computedBindings) do updateComputed(b) end

	if #computedBindings > 64 then gcBindings() end
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
		state     = state,
		setState  = setState,
		dispatch  = dispatch,
		navigate  = navigate,
		getById   = getById,
		onCleanup = function(cb) _cleanup_fn = cb end,
	})
end

function updateComputed(binding)
	if not binding.instance then return end
	if exitingInstances[binding.instance] then return end
	if binding.ready and not binding.instance.Parent then return end

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
	task.defer(function()
		if binding.revision == rev then playEnterTransitions(binding.mounted) end
	end)
end
]=]
