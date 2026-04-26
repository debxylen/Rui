return [=[
  <ScreenGui IgnoreGuiInset="true" name="overlay">
    <Frame
      name="overlayRoot"
      size="1,1"
      position="0,0"
      backgroundTransparency="1"
    >
		{{
		  if state.route == "guide" then return Fragment([==[@include(guideModal)]==]) end
		  return nil
		}}
    </Frame>
  </ScreenGui>
]=]
