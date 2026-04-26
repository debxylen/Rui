local header = [[
    <Frame
      name="guideHeader"
      size="1,0.16"
      direction="row"
      gap="10"
      align="center"
      backgroundTransparency="1"
    >
      <Frame
        name="guideHeaderText"
        size="0.68,1"
        direction="column"
        gap="2"
        backgroundTransparency="1"
      >
        <TextLabel
          name="guideTitleLabel"
          text="Rui Quick Guide"
          size="1,0.5"
          textColor="255,255,255"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="guideSubtitleLabel"
          text="Basic normie stuff"
          size="1,0.4"
          textColor="182,194,220"
          textScaled="true"
          backgroundTransparency="1"
        />
      </Frame>
      <TextButton
        name="guideCloseButton"
        text="X"
        size="0.16,1"
        cornerRadius="12"
        backgroundColor="92,56,67"
        textColor="255,243,243"
        textScaled="true"
        onClick="{ navigate('home') }"
      />
    </Frame>
]]

local stepList = [[
    <ScrollingFrame
      name="guideList"
      size="1,0.72"
      direction="column"
      gap="10"
      backgroundTransparency="1"
    >
		{{
		    -- @scope index step
		    local out = {}

		    for index, step in ipairs(state.guideSteps) do
		        table.insert(out, Fragment([=[
		            <Frame
		              name="GuideStep"
		              size="1,0.18"
		              backgroundColor="31,37,57"
		              cornerRadius="14"
		              direction="row"
		              gap="10"
		              padding="10"
		              align="left"
		            >
		              <Frame
		                name="GuideStepSwatch"
		                size="0.10,1"
		                backgroundColor="{ state.accentColor }"
		                cornerRadius="10"
		              />
		              <TextLabel
		                name="GuideStepLabel"
		                text="{ tostring(index) .. '. ' .. step }"
		                size="0.86,1"
		                textColor="244,247,255"
		                textScaled="true"
		                backgroundTransparency="1"
		              />
		            </Frame>
		        ]=]))
		    end

		    return out
		}}
    </ScrollingFrame>
]]

local guideModal = [[
<Frame
  name="guideOverlay"
  Active="true"
  transition="fade"
  transitionTime="0.18"
  size="1,1"
  position="0,0"
  backgroundColor="0,0,0"
  backgroundTransparency="0.35"
>
  <Frame
    name="guideModalPanel"
    transition="modal"
    transitionTime="0.24"
    size="0.58,0.7"
    position="0.21,0.15"
    backgroundColor="17,21,33"
    cornerRadius="22"
    direction="column"
    gap="12"
    padding="16"
  >
@include(guideModalHeader)
@include(guideModalStepList)
  </Frame>
</Frame>
]]

return {
	root = guideModal,
	fragments = {
		guideModalHeader = header,
		guideModalStepList = stepList,
	},
}
