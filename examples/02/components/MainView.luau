local header = [[
      <Frame
        name="heroPanel"
        size="1,0.22"
        backgroundColor="17,22,32"
        backgroundTransparency="0.04"
        cornerRadius="20"
        direction="column"
        gap="6"
        padding="14"
      >
        <TextLabel
          name="heroEyebrow"
          text="Rui"
          size="1,0.18"
          textColor="{ state.accentColor }"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="heroTitle"
          text="{ 'Hi, ' .. state.playerName }"
          size="1,0.34"
          textColor="255,255,255"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="heroBody"
          text="A rather useless example-cum-guide that aims to showcase more of Rui's support in its implementation."
          size="1,0.26"
          textColor="188,200,226"
          textScaled="true"
          backgroundTransparency="1"
        />
      </Frame>
]]

local controls = [[
      <Frame
        name="controlsPanel"
        size="1,0.18"
        backgroundColor="17,22,32"
        cornerRadius="18"
        backgroundTransparency="0.04"
        direction="row"
        gap="10"
        padding="12"
        align="center"
      >
        <TextButton
          name="countButton"
          text="{ 'Count +' .. tostring(state.clicks) }"
          size="0.31,1"
          cornerRadius="14"
          backgroundColor="{ state.accentColor }"
          textColor="13,18,28"
          textScaled="true"
          onClick="incrementClicks"
        />
        <TextButton
          name="accentButton"
          text="{ state.accentName .. ' Accent' }"
          size="0.31,1"
          cornerRadius="14"
          backgroundColor="40,52,78"
          textColor="235,242,255"
          textScaled="true"
          onClick="rotateAccent"
        />
        <TextButton
          name="guideButton"
          text="Guide"
          size="0.31,1"
          cornerRadius="14"
          backgroundColor="40,52,78"
          textColor="235,242,255"
          textScaled="true"
          onClick="{ navigate('guide') }"
        />
      </Frame>
]]

local featureList = [[
      <Frame
        name="featureListPanel"
        size="0.52,0.42"
        backgroundColor="17,22,32"
        cornerRadius="18"
        backgroundTransparency="0.04"
        direction="column"
        gap="8"
        padding="12"
      >
		{{
		    -- @scope feature
		    local out = {}

		    for _, feature in ipairs(state.features) do
		        table.insert(out, Fragment([=[
		            <Frame
		              name="{ feature.id .. 'FeatureRow' }"
		              size="1,1"
		              backgroundColor="{ state.selectedFeatureId == feature.id and state.accentColor or Color3.fromRGB(32,40,58) }"
		              backgroundTransparency="{ state.selectedFeatureId == feature.id and 0.1 or 0 }"
		              cornerRadius="14"
		              direction="row"
		              gap="8"
		              padding="10"
		              align="center"
		            >
		              <Frame
		                name="{ feature.id .. 'Swatch' }"
		                size="0.08,1"
		                backgroundColor="{ state.selectedFeatureId == feature.id and Color3.fromRGB(255,255,255) or state.accentColor }"
		                cornerRadius="10"
		              />
		              <Frame
		                name="{ feature.id .. 'TextWrap' }"
		                size="0.62,1"
		                direction="column"
		                gap="2"
		                backgroundTransparency="1"
		              >
		                <TextLabel
		                  name="{ feature.id .. 'TitleLabel' }"
		                  text="{ feature.title }"
		                  size="1,0.42"
		                  textColor="255,255,255"
		                  textScaled="true"
		                  backgroundTransparency="1"
		                />
		                <TextLabel
		                  name="{ feature.id .. 'BodyLabel' }"
		                  text="{ feature.body }"
		                  size="1,0.58"
		                  textColor="194,204,228"
		                  textScaled="true"
		                  backgroundTransparency="1"
		                />
		              </Frame>
		              <TextButton
		                name="{ feature.id .. 'SelectButton' }"
		                text="{ state.selectedFeatureId == feature.id and 'Selected' or 'Show' }"
		                size="0.22,1"
		                cornerRadius="12"
		                backgroundColor="24,30,44"
		                textColor="245,248,255"
		                textScaled="true"
		                onClick="{ selectFeature({ feature = feature }) }"
		              />
		            </Frame>
		        ]=]))
		    end

		    return out
		}}
      </Frame>
]]

local detailCard = [[
      <Frame
        name="featureDetailPanel"
        size="0.44,1"
        backgroundColor="17,22,32"
        cornerRadius="18"
        backgroundTransparency="0.04"
        direction="column"
        gap="8"
        padding="12"
      >
        <TextLabel
          name="featureDetailEyebrow"
          text="{ 'Selected: ' .. state.selectedFeatureTitle }"
          size="1,0.14"
          textColor="{ state.accentColor }"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="featureDetailBody"
          text="{ state.selectedFeatureBody }"
          size="1,0.36"
          textColor="240,244,255"
          textScaled="true"
          backgroundTransparency="1"
        />
        {{
          if state.toastVisible and state.toast ~= "" then
            return Fragment([=[
              <Frame
                name="liveToastPanel"
                transition="toast"
                transitionTime="0.22"
                size="1,0.24"
                backgroundColor="28,36,52"
                cornerRadius="14"
                direction="row"
                gap="8"
                padding="10"
                align="center"
              >
                <TextLabel
                  name="liveToastLabel"
                  size="0.78,1"
                  backgroundTransparency="1"
                  text="{ state.toast }"
                  textColor="235,242,255"
                  textScaled="true"
                />
                <TextButton
                  name="liveToastDismissButton"
                  text="X"
                  size="0.18,1"
                  backgroundColor="73,52,60"
                  textColor="255,241,244"
                  textScaled="true"
                  cornerRadius="10"
                  onClick="dismissToast"
                />
              </Frame>
            ]=])

          else

            return Fragment([=[
              <TextLabel
                name="hintLabel"
                text="Click around and watch bindings update immediately."
                size="1,0.24"
                textColor="186,197,220"
                textScaled="true"
                backgroundTransparency="1"
                transition="fade"
                transitionTime="0.22"
              />
            ]=])

          end
        }}
      </Frame>
]]

local mainView = [[
  <ScreenGui IgnoreGuiInset="true" name="main">
    <Frame
      name="mainFrame"
      size="1,1"
      position="0,0"
      backgroundColor="9,12,20"
      direction="column"
      gap="12"
      padding="18"
    >
@include(mainHeader)
@include(mainControls)
      <Frame
        name="contentRow"
        size="1,0.42"
        backgroundTransparency="1"
        direction="row"
        gap="12"
      >
@include(mainFeatureList)
@include(mainDetailCard)
      </Frame>
    </Frame>
  </ScreenGui>
]]

return {
	root = mainView,
	fragments = {
		mainHeader = header,
		mainControls = controls,
		mainFeatureList = featureList,
		mainDetailCard = detailCard,
	},
}
