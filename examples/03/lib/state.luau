local function getPlayerName()
	local player = game:GetService("Players").LocalPlayer
	if player then return player.Name
	else return "[server]" end
end

return {
	playerName = getPlayerName(),
	level = 8,
	coins = 120,
	route = "hud",
	equippedItem = "Wooden Sword",
	questStep = 1,
	quests = {
		{
			text = "Earn enough coins to buy a better weapon from the village shop.",
			completeToast = "Quest complete: better weapon acquired.",
		},
		{
			text = "Equip a ranged weapon from your backpack.",
			completeToast = "Quest complete: ranged option ready.",
		},
		{
			text = "Collect 8 items for the trail ahead.",
			completeToast = "Quest complete: backpack stocked.",
		},
	},
	questText = "Earn enough coins and buy a better weapon from the shop.",
	toast = "",
	toastVisible = false,
	toastNonce = 0,
	items = {
		"Wooden Sword",
		"Torch",
		"Apple",
	},
	itemsCount = 3,
	shopItems = {
		{
			name = "Iron Sword",
			description = "Reliable melee damage for early fights.",
			price = 60,
			color = Color3.fromRGB(96, 116, 172),
		},
		{
			name = "Hunter Bow",
			description = "A ranged option for safer clearing.",
			price = 90,
			color = Color3.fromRGB(87, 126, 94),
		},
		{
			name = "Traveler Cloak",
			description = "Adds style and a little survivability.",
			price = 140,
			color = Color3.fromRGB(132, 94, 151),
		},

		{
			name = "Steel Dagger",
			description = "Fast attacks with lower damage.",
			price = 45,
			color = Color3.fromRGB(140, 140, 140),
		},
		{
			name = "Warhammer",
			description = "Slow but hits like a truck.",
			price = 180,
			color = Color3.fromRGB(110, 110, 120),
		},
		{
			name = "Fire Wand",
			description = "Shoots small bursts of flame.",
			price = 160,
			color = Color3.fromRGB(200, 90, 60),
		},
		{
			name = "Ice Staff",
			description = "Slows enemies on hit.",
			price = 170,
			color = Color3.fromRGB(120, 180, 220),
		},
		{
			name = "Leather Armor",
			description = "Basic protection for beginners.",
			price = 80,
			color = Color3.fromRGB(150, 100, 70),
		},
		{
			name = "Chainmail Vest",
			description = "Balanced defense and mobility.",
			price = 130,
			color = Color3.fromRGB(160, 160, 170),
		},
		{
			name = "Knight Armor",
			description = "Heavy protection, less speed.",
			price = 250,
			color = Color3.fromRGB(100, 110, 130),
		},
		{
			name = "Swift Boots",
			description = "Increases movement speed.",
			price = 110,
			color = Color3.fromRGB(180, 150, 90),
		},
		{
			name = "Health Potion",
			description = "Restores a small amount of HP.",
			price = 25,
			color = Color3.fromRGB(200, 50, 50),
		},
		{
			name = "Mega Potion",
			description = "Restores a large amount of HP.",
			price = 75,
			color = Color3.fromRGB(180, 40, 40),
		},
		{
			name = "Mana Potion",
			description = "Restores magic energy.",
			price = 50,
			color = Color3.fromRGB(60, 90, 200),
		},
		{
			name = "Bomb",
			description = "Deals AoE damage on impact.",
			price = 120,
			color = Color3.fromRGB(80, 80, 80),
		},
		{
			name = "Shadow Cloak",
			description = "Grants slight invisibility effect.",
			price = 220,
			color = Color3.fromRGB(60, 60, 90),
		},
		{
			name = "Golden Ring",
			description = "Boosts overall stats slightly.",
			price = 200,
			color = Color3.fromRGB(220, 190, 60),
		},
		{
			name = "Lucky Charm",
			description = "Increases drop chances.",
			price = 175,
			color = Color3.fromRGB(100, 200, 120),
		},
		{
			name = "Magic Scroll",
			description = "One-time powerful spell cast.",
			price = 95,
			color = Color3.fromRGB(200, 200, 150),
		},
		{
			name = "Battle Axe",
			description = "Wide swings hit multiple enemies.",
			price = 190,
			color = Color3.fromRGB(130, 130, 130),
		},
		{
			name = "Energy Shield",
			description = "Absorbs incoming damage.",
			price = 210,
			color = Color3.fromRGB(90, 160, 200),
		},
		{
			name = "Truck-kun",
			description = "...",
			price = 420,
			color = Color3.fromRGB(255, 0, 251),
		},
	}
}
