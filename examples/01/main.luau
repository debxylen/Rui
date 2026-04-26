local ui = [[
  <ScreenGui name="main">
    <Frame
      name="mainFrame"
      size="1,1"
      position="0,0"
      backgroundTransparency="1"
      direction="column"
      align="center"
      padding="20"
    >
      <Frame
        name="card"
        size="0.34,1"
        backgroundColor="32,38,50"
        cornerRadius="16"
        direction="column"
        gap="10"
        padding="14"
      >
        <TextLabel
          name="titleLabel"
          text="{ 'Hello, ' .. state.playerName }"
          size="1,0.2"
          textColor="255,255,255"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="countLabel"
          text="{ 'Count: ' .. tostring(state.count) }"
          size="1,0.18"
          textColor="132,255,174"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="statusLabel"
          text="{ state.status }"
          size="1,0.18"
          textColor="210,218,235"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextButton
          name="incrementButton"
          text="Increment"
          size="1,0.18"
          cornerRadius="12"
          backgroundColor="95,214,170"
          textColor="15,19,28"
          textScaled="true"
          onClick="incrementCount"
        />
        <TextButton
          name="resetButton"
          text="Reset"
          size="1,0.16"
          cornerRadius="12"
          backgroundColor="63,74,100"
          textColor="244,247,255"
          textScaled="true"
          onClick="resetCount"
        />
      </Frame>
    </Frame>
  </ScreenGui>
]]

local backend = {
	ui = ui,
	fragments = {},
	state = {
		playerName = "bob",
		count = 0,
		status = "Ready",
	},
	actions = {
		incrementCount = function(ctx)
			local nextCount = (ctx.state.count or 0) + 1
			ctx.setState("count", nextCount)
			ctx.setState("status", "Clicked " .. tostring(nextCount) .. " times")
		end,

		resetCount = function(ctx)
			ctx.setState("count", 0)
			ctx.setState("status", "Counter reset")
		end
	}
}

return backend
