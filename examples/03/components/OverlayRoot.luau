return [=[
  <ScreenGui IgnoreGuiInset="true" name="overlay">
    <Frame
      name="overlayRoot"
      size="1,1"
      position="0,0"
      backgroundTransparency="1" 
    >
		{{
		  if state.route == "shop" then return Fragment([==[@include(shopModal)]==])
		  elseif state.route == "inventory" then return Fragment([==[@include(inventoryModal)]==]) end

		  return nil
		}}
    </Frame>
  </ScreenGui>
]=]
