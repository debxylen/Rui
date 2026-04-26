local function getPlayerName()
	local player = game:GetService("Players").LocalPlayer
	if player then return player.Name end
	return "[server]"
end

return {
	playerName = getPlayerName(),
	route = "home",
	clicks = 1,
	accentName = "Mint",
	accentColor = Color3.fromRGB(95, 214, 170),
	selectedFeatureId = "state",
	selectedFeatureTitle = "Reactive State",
	selectedFeatureBody = "Use state values directly in bindings and update them with ctx.setState.",
	toast = "",
	toastVisible = false,
	toastNonce = 0,
	features = {
		{
			id = "state",
			title = "Reactive State",
			body = "Use state values directly in bindings and update them with ctx.setState.",
		},
		{
			id = "fragments",
			title = "Fragments",
			body = "Split large UI into @include fragments and smaller component modules.",
		},
		{
			id = "loops",
			title = "Scoped Loops",
			body = "Render repeated rows with Fragment blocks and -- @scope locals in {{ LuaXML blocks }}.",
		},
	},
	guideSteps = {
		"Put LuaXML UI code in lib/ui.luau with the `--!rui compile-only` comment directive at top.",
		"Put components in components/*.luau.",
		"Keep initial values and state in lib/state.luau.",
		"Register actions in lib/actions.luau.",
		"Import those files and return them as a table in /main.luau.",
	},
}
