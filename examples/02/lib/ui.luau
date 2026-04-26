--!rui compile-only

local components = script.Parent.Parent.components

local mainViewComponent = require(components.MainView)
local guideModalComponent = require(components.GuideModal)
local overlayRoot = require(components.OverlayRoot)

local fragments = {
	mainView = mainViewComponent.root,
	guideModal = guideModalComponent.root,
	overlayRoot = overlayRoot,
}

for name, fragment in pairs(mainViewComponent.fragments) do fragments[name] = fragment end
for name, fragment in pairs(guideModalComponent.fragments) do fragments[name] = fragment end

return {
	ui = [=[
<>
@include(mainView)
@include(overlayRoot)
</>
]=],
	fragments = fragments,
}
