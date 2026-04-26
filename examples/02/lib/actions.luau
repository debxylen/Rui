local accents = {
	{ name = "Mint", color = Color3.fromRGB(95, 214, 170) },
	{ name = "Sun", color = Color3.fromRGB(255, 196, 92) },
	{ name = "Sky", color = Color3.fromRGB(114, 168, 255) },
}

local function showToast(ctx, message)
	local nextNonce = (ctx.state.toastNonce or 0) + 1
	ctx.setState("toastNonce", nextNonce)
	ctx.setState("toast", message)
	ctx.setState("toastVisible", true)

	task.delay(2.2, function()
		if ctx.state.toastNonce == nextNonce then
			ctx.setState("toastVisible", false)
		end
	end)
end

return function(backend)
	backend.actions = {}

	backend.actions.incrementClicks = function(ctx)
		local nextClicks = (ctx.state.clicks or 0) + 1
		ctx.setState("clicks", nextClicks)
		showToast(ctx, "Counter is now " .. tostring(nextClicks) .. ".")
	end

	backend.actions.rotateAccent = function(ctx)
		local currentName = ctx.state.accentName
		local index = 1

		for i, accent in ipairs(accents) do
			if accent.name == currentName then
				index = i
				break
			end
		end

		local nextAccent = accents[(index % #accents) + 1]
		ctx.setState("accentName", nextAccent.name)
		ctx.setState("accentColor", nextAccent.color)
		showToast(ctx, nextAccent.name .. " accent applied.")
	end

	backend.actions.dismissToast = function(ctx)
		ctx.setState("toastVisible", false)
	end

	backend.actions.selectFeature = function(ctx)
		local feature = (ctx.scope or {}).feature
		if not feature then
			showToast(ctx, "No feature selected.")
			return
		end

		ctx.setState("selectedFeatureId", feature.id)
		ctx.setState("selectedFeatureTitle", feature.title)
		ctx.setState("selectedFeatureBody", feature.body)
		showToast(ctx, feature.title .. " highlighted.")
	end

	backend.navigate = function(ctx)
		ctx.setState("route", ctx.route)

		if ctx.route == "guide" then
			showToast(ctx, "Guide opened.")
		else
			showToast(ctx, "Back on the main screen.")
		end
	end

	return backend
end
