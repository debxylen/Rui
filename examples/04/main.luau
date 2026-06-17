local ui = [[
<ScreenGui name="StyleTest">
  <Frame
    name="root"
    size="1,1"
    position="0,0"
    backgroundTransparency="1"
    direction="column"
    align="center"
    gap="14"
    padding="30"
  >

    <TextLabel name="title" text="Stylesheet Test" size="0.4,0.06" textScaled="true" backgroundTransparency="1" />

    <TextButton name="hoverBtn"  text="Hover me"  size="0.3,0.07" cornerRadius="10" onClick="noop" />
    <TextButton name="activeBtn" text="Click me"  size="0.3,0.07" cornerRadius="10" onClick="noop" />

    <TextButton name="toggleBtn" text="Toggle state" size="0.3,0.07" cornerRadius="10" onClick="toggle" />
    <TextLabel  name="stateLabel" text="{ state.mode }" size="0.3,0.05" textScaled="true" backgroundTransparency="1" />

  </Frame>
</ScreenGui>
]]

local stylesheet = [[
    --bg:     30, 36, 48;
    --accent: 95, 214, 170;
    --red:    255, 0, 0;
    --blue:   0, 0, 255;
    --text:   255, 255, 255;
    --on-bg:  60, 100, 220;

    TextButton {
        backgroundColor: var(--accent);
        textColor: var(--text);
        backgroundTransparency: 0;
    }
    TextButton:hover {
        backgroundColor: var(--blue);
    }
    TextButton:active {
        backgroundColor: var(--red);
    }
    TextButton:state(mode=on) {
        backgroundColor: var(--on-bg);
    }
    TextLabel {
        textColor: var(--text);
    }
]]

return {
	ui         = ui,
	state      = { mode = "off" },
	stylesheet = stylesheet,

	actions    = {
		noop   = function() end,
		toggle = function(ctx) ctx.setState("mode", ctx.state.mode == "on" and "off" or "on") end,
	}
}
