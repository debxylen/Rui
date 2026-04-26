local statsPanel = [[
      <Frame
        name="hudStatsPanel"
        size="0.22,0.34"
        position="0.03,0.05"
        backgroundColor="15,19,29"
        cornerRadius="20"
        backgroundTransparency="0.08"
        direction="column"
        gap="8"
        padding="14"
      >
        <TextLabel
          name="playerNameLabel"
          text="{ state.playerName }"
          size="1,0.18"
          textColor="255,255,255"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="playerLevelLabel"
          text="{ 'Level ' .. tostring(state.level) .. ' Explorer' }"
          size="1,0.12"
          textColor="173,187,216"
          textScaled="true"
          backgroundTransparency="1"
        />

      <Frame
        name="coinsPanel"
        size="1,0.3"
        backgroundColor="28,35,54"
        cornerRadius="14"
        direction="column"
        padding="8"
        gap="2"
      > 
        <TextLabel
          name="coinsLabel"
          text="{ 'Coins: ' .. tostring(state.coins) }"
          size="1,1"
          textColor="{ state.coins >= 100 and Color3.fromRGB(132,255,174) or Color3.fromRGB(255,240,156) }"
          textScaled="true"
          backgroundTransparency="1"
        />
      </Frame>

      <Frame
        name="equippedPanel"
        size="1,0.3"
        backgroundColor="28,35,54"
        cornerRadius="14"
        direction="column"
        padding="8"
        gap="2"
      >
        <TextLabel
          name="equippedItemLabel"
          text="{ 'Equipped: ' .. tostring(state.equippedItem) }"
          size="1,1"
          textColor="242,246,255"
          textScaled="true"
          backgroundTransparency="1"
        />
      </Frame>
      </Frame>
]]

local questPanel = [[
      <Frame
        name="questPanel"
        size="0.24,0.18"
        position="0.73,0.05"
        backgroundColor="15,19,29"
        cornerRadius="20"
        backgroundTransparency="0.08"
        direction="column"
        gap="6"
        padding="12"
      >
        <TextLabel
          name="questTitleLabel"
          text="Quest"
          size="1,0.24"
          textColor="255,255,255"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="questTextLabel"
          text="{ state.questText .. ' (' .. tostring(math.min(state.questStep, #state.quests)) .. '/' .. tostring(#state.quests) .. ')' }"
          size="1,0.42"
          textColor="182,196,226"
          textScaled="true"
          backgroundTransparency="1"
        />
      </Frame>
]]

local toast = [[
      {{
        if state.toastVisible and state.toast ~= "" then
          return Fragment([=[
            <Frame
              name="toastPanel"
              transition="toast"
              transitionTime="0.26"
              size="0.26,0.09"
              position="0.72,0.87"
              backgroundColor="16,20,31"
              backgroundTransparency="0.08"
              cornerRadius="18"
              direction="row"
              gap="8"
              padding="10"
              align="center"
            >
              <TextLabel
                name="toastMessageLabel"
                size="0.82,1"
                backgroundTransparency="1"
                text="{ state.toast }"
                textColor="236,242,255"
                textScaled="true"
              />
              <TextButton
                name="toastDismissButton"
                text="X"
                size="0.18,1"
                backgroundColor="72,54,54"
                textColor="255,240,240"
                textScaled="true"
                cornerRadius="10"
                onClick="dismissToast"
              />
            </Frame>
          ]=])
        end

        return nil
      }}
]]

local actionBar = [[
      <Frame
        name="hudActionBar"
        size="0.34,0.12"
        position="0.33,0.83"
        backgroundColor="15,19,29"
        cornerRadius="22"
        backgroundTransparency="0.08"
        direction="row"
        gap="10"
        padding="10"
        align="center"
      >
        <TextButton
          name="earnCoinsButton"
          text="Earn 25"
          size="0.32,1"
          cornerRadius="14"
          backgroundColor="52,86,61"
          textColor="244,255,240"
          textScaled="true"
          onClick="earnCoins"
        />
        <TextButton
          name="shopButton"
          text="Shop"
          size="0.32,1"
          cornerRadius="14"
          tweenTime="0.3"
          tweenStyle="Quad"
          tweenDirection="Out"
          backgroundColor="{ state.route == 'shop' and Color3.fromRGB(118,96,196) or Color3.fromRGB(76,65,128) }"
          textColor="{ state.route == 'shop' and Color3.fromRGB(255,255,255) or Color3.fromRGB(225,215,245) }"
          textScaled="true"
          onClick="{ navigate('shop') }"
        />
        <TextButton
          name="backpackButton"
          text="Backpack"
          size="0.32,1"
          cornerRadius="14"
          tweenTime="0.3"
          tweenStyle="Quad"
          tweenDirection="Out"
          backgroundColor="{ state.route == 'inventory' and Color3.fromRGB(76,108,176) or Color3.fromRGB(47,67,110) }"
          textColor="{ state.route == 'inventory' and Color3.fromRGB(255,255,255) or Color3.fromRGB(219,231,245) }"
          textScaled="true"
          onClick="{ navigate('inventory') }"
        />
      </Frame>
]]

local fieldHud = [[
  <ScreenGui name="main">
    <Frame
      size="1,1"
      position="0,0"
      backgroundTransparency="1"
      name="mainFrame"
    >
@include(fieldHudStatsPanel)
@include(fieldHudQuestPanel)
@include(fieldHudToast)
@include(fieldHudActionBar)
    </Frame>
  </ScreenGui>
]]

return {
	root = fieldHud,
	fragments = {
		fieldHudStatsPanel = statsPanel,
		fieldHudQuestPanel = questPanel,
		fieldHudToast = toast,
		fieldHudActionBar = actionBar,
	},
}
