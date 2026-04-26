--!rui compile-only

local components = script.Parent.Parent.components

local fieldHudComponent = require(components.FieldHud)
local shopModalComponent = require(components.ShopModal)
local inventoryModalComponent = require(components.InventoryModal)
local overlayRoot = require(components.OverlayRoot)

local fragments = {
	fieldHud = fieldHudComponent.root,
	shopModal = shopModalComponent.root,
	inventoryModal = inventoryModalComponent.root,
	overlayRoot = overlayRoot,
}

for name, fragment in pairs(fieldHudComponent.fragments) do fragments[name] = fragment end
for name, fragment in pairs(shopModalComponent.fragments) do fragments[name] = fragment end
for name, fragment in pairs(inventoryModalComponent.fragments) do fragments[name] = fragment end

return {
	ui = [=[
<>
@include(fieldHud)
@include(overlayRoot)
</>
]=],
	fragments = fragments,
}
