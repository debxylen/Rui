local function showToast(ctx, message)
	local nextNonce = (ctx.state.toastNonce or 0) + 1
	ctx.setState("toastNonce", nextNonce)
	ctx.setState("toast", message)
	ctx.setState("toastVisible", true)

	task.delay(2.2, function()
		if ctx.state.toastNonce == nextNonce then
			ctx.setState("toastVisible", false) end
	end)
end

local weaponNames = {
	["Iron Sword"] = true,
	["Hunter Bow"] = true,
	["Steel Dagger"] = true,
	["Warhammer"] = true,
	["Fire Wand"] = true,
	["Ice Staff"] = true,
	["Crossbow"] = true,
	["Battle Axe"] = true,
}

local rangedWeaponNames = {
	["Hunter Bow"] = true,
	["Fire Wand"] = true,
	["Ice Staff"] = true,
	["Crossbow"] = true,
	["Truck-kun"] = true,
}

local function setQuestText(state, setState, step)
	local quests = state.quests or {}
	local quest = quests[step]
	if quest then
		setState("questText", quest.text)
	else
		setState("questText", "All quests complete. Enjoy :D")
	end
end

local function completeQuest(ctx, step)
	local currentStep = ctx.state.questStep or 1
	local quests = ctx.state.quests or {}
	if currentStep ~= step or currentStep > #quests then
		return false end

	local quest = quests[currentStep]
	local nextStep = currentStep + 1

	ctx.setState("questStep", nextStep)
	setQuestText(ctx.state, ctx.setState, nextStep)

	if quest and quest.completeToast then
		showToast(ctx, quest.completeToast) end

	return true
end

return function(backend)
	backend.actions = {}

	backend.actions.earnCoins = function(ctx)
		ctx.setState("coins", (ctx.state.coins or 0) + 25)
		showToast(ctx, "You picked up 25 coins.")
	end

	backend.actions.dismissToast = function(ctx)
		ctx.setState("toastVisible", false) end

	backend.actions.buySelectedShopItem = function(ctx)
		local stock = ctx.state.shopItems or {}
		local scope = ctx.scope or {}
		local item = scope.item
		if not item then
			showToast(ctx, "The shop is sold out.")
			return
		end

		if (ctx.state.coins or 0) < item.price then
			showToast(ctx, "Not enough coins for " .. item.name .. ".")
			return
		end

		local nextItems = table.clone(ctx.state.items or {})
		table.insert(nextItems, item.name)

		ctx.setState("coins", ctx.state.coins - item.price)
		ctx.setState("items", nextItems)
		ctx.setState("itemsCount", #nextItems)

		local completedQuest = false

		if weaponNames[item.name] then completedQuest = completeQuest(ctx, 1) end
		if #nextItems >= 8 then completedQuest = completeQuest(ctx, 3) or completedQuest end

		if not completedQuest then
			showToast(ctx, item.name .. " purchased.") end

		local nextStock = {}
		local removed = false

		for _, stockItem in ipairs(stock) do
			if not removed and stockItem == item then removed = true
			else table.insert(nextStock, stockItem) end
		end
		ctx.setState("shopItems", nextStock)
	end

	backend.actions.equipItem = function(ctx)
		local scope = ctx.scope or {}
		local item = scope.item
		if not item then
			showToast(ctx, "Your backpack is empty.")
			return end

		ctx.setState("equippedItem", item)
		local completedQuest = false

		if rangedWeaponNames[item] then completedQuest = completeQuest(ctx, 2) end
		if not completedQuest then showToast(ctx, item .. " equipped.") end
	end 

	backend.actions.toggleMenu = function(ctx)
		if ctx.state.route == "shop" then
			ctx.setState("route", "hud")
			showToast(ctx, "Returned to the field HUD.")
			return
		end

		ctx.setState("route", "shop")
		showToast(ctx, "Village shop opened.")
	end

	backend.navigate = function(ctx)
		ctx.setState("route", ctx.route)

		if ctx.route == "shop" then showToast(ctx, "Browsing the village shop.")
		elseif ctx.route == "inventory" then showToast(ctx, "Backpack opened.")
		else showToast(ctx, "Field HUD active.") end
	end

	return backend
end
