local header = [[
    <Frame
      name="inventoryHeader"
      size="1,0.14"
      direction="row"
      gap="10"
      align="center"
      backgroundTransparency="1"
    >
      <Frame
        name="inventoryHeaderText"
        size="0.72,1"
        direction="column"
        gap="2"
        backgroundTransparency="1"
      >
        <TextLabel
          name="inventoryTitleLabel"
          text="Backpack"
          size="1,0.48"
          textColor="255,255,255"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="inventoryCountLabel"
          text="{ tostring(state.itemsCount) .. ' items collected' }"
          size="1,0.24"
          textColor="173,187,216"
          textScaled="true"
          backgroundTransparency="1"
        />
      </Frame>
      <TextButton
        text="↑"
        size="0.10,1"
        cornerRadius="12"
        backgroundColor="54,72,110"
        textColor="235,243,255"
        textScaled="true"
        name="inventoryScrollTopButton"
        onClick="{ local list = getById('inventoryList'); if list then list.CanvasPosition = Vector2.new(0, 0) end }"
      />
      <TextButton
        name="inventoryCloseButton"
        text="X"
        size="0.18,1"
        cornerRadius="12"
        backgroundColor="92,56,67"
        textColor="255,243,243"
        textScaled="true"
        onClick="{ navigate('hud') }"
      />
    </Frame>
]]

local itemList = [[
    <ScrollingFrame
      name="inventoryList"
      id="inventoryList"
      size="1,0.76"
      direction="column"
      gap="8"
      backgroundTransparency="1"
    >
		{{
		    -- @scope item
		    local out = {}

		    for _, item in ipairs(state.items) do
		        table.insert(out, Fragment([=[
		            <Frame
		              name="{ item .. 'InventoryRow' }"
		              size="1,0.18"
		              backgroundColor="31,37,57"
		              cornerRadius="14"
		              direction="row"
		              gap="10"
		              padding="10"
		              align="center"
		            >
		              <Frame
		                name="{ item .. 'IconSwatch' }"
		                size="0.14,1"
		                backgroundColor="74,98,173"
		                cornerRadius="12"
		              />
		              <TextLabel
		                name="{ item .. 'NameLabel' }"
		                text="{ item }"
		                size="0.52,1"
		                textColor="255,255,255"
		                textScaled="true"
		                backgroundTransparency="1"
		              />
		              <TextButton
		                name="{ item .. 'EquipButton' }"
		                text="{ state.equippedItem == item and 'Equipped' or 'Equip' }"
		                size="0.24,1"
		                cornerRadius="12"
		                backgroundColor="{ state.equippedItem == item and Color3.fromRGB(68,92,146) or Color3.fromRGB(58,95,70) }"
		                textColor="245,245,255"
		                textScaled="true"
		                onClick="{ equipItem({ item = item }) }"
		              />
		            </Frame>
		        ]=]))
		    end

		    return out
		}}
    </ScrollingFrame>
]]

local inventoryModal = [[
<Frame
  transition="fade"
  transitionTime="0.18"
  size="1,1"
  position="0,0"
  backgroundColor="0,0,0"
  backgroundTransparency="0.35"
  name="inventory"
>
  <Frame
    name="inventoryModalPanel"
    transition="modal"
    transitionTime="0.24"
    size="0.5,0.62"
    position="0.25,0.19"
    backgroundColor="17,21,33"
    cornerRadius="22"
    direction="column"
    gap="12"
    padding="16"
  >
@include(inventoryHeader)
@include(inventoryItemList)
  </Frame>
</Frame>
]]

return {
	root = inventoryModal,
	fragments = {
		inventoryHeader = header,
		inventoryItemList = itemList,
	},
}
