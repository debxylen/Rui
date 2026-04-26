local ui = require(script.Parent.lib.ui)
local state = require(script.Parent.lib.state)
local registerActions = require(script.Parent.lib.actions)

local backend = {
	ui = ui.ui,
	fragments = ui.fragments,
	state = state,
}

registerActions(backend)

return backend
