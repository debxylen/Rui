local header = [[
    <Frame
      name="shopHeader"
      size="1,0.14"
      direction="row"
      gap="10"
      align="center"
      backgroundTransparency="1"
    >
      <Frame
        name="shopHeaderText"
        size="0.72,1"
        direction="column"
        gap="2"
        backgroundTransparency="1"
      >
        <TextLabel
          name="shopTitleLabel"
          text="Village Shop"
          size="1,0.48"
          textColor="255,255,255"
          textScaled="true"
          backgroundTransparency="1"
        />
        <TextLabel
          name="shopCoinsLabel"
          text="{ 'Spend coins to unlock stronger gear. You have ' .. tostring(state.coins) .. '.' }"
          size="1,0.24"
          textColor="173,187,216"
          textScaled="true"
          backgroundTransparency="1"
        />
      </Frame>
      <TextButton
        name="shopScrollTopButton"
        text="↑"
        size="0.10,1"
        cornerRadius="12"
        backgroundColor="54,72,110"
        textColor="235,243,255"
        textScaled="true"
        onClick="{ local list = getById('shopList'); if list then list.CanvasPosition = Vector2.new(0, 0) end }"
      />
      <TextButton
        name="shopCloseButton"
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
      name="shopList"
      id="shopList" 
      size="1,0.76"
      direction="column"
      gap="10"
      backgroundTransparency="1"
    >
		{{
		    -- @scope item
		    local out = {}

		    for _, item in ipairs(state.shopItems) do
		        table.insert(out, Fragment([=[
		            <Frame
		              name="{ item.name .. 'ShopRow' }"
		              size="1,0.22"
		              backgroundColor="31,37,57"
		              cornerRadius="14"
		              direction="row"
		              gap="10"
		              padding="10"
		              align="center"
		            >
		              <Frame
		                name="{ item.name .. 'ColorSwatch' }"
		                size="0.14,1"
		                backgroundColor="{ item.color }"
		                cornerRadius="12"
		              />
		              <Frame
		                name="{ item.name .. 'Details' }"
		                size="0.48,1"
		                direction="column"
		                gap="2"
		                backgroundTransparency="1"
		              >
		                <TextLabel
		                  name="{ item.name .. 'NameLabel' }"
		                  text="{ item.name }"
		                  size="1,0.42"
		                  textColor="255,255,255"
		                  textScaled="true"
		                  backgroundTransparency="1"
		                />
		                <TextLabel
		                  name="{ item.name .. 'DescriptionLabel' }"
		                  text="{ item.description }"
		                  size="1,0.22"
		                  textColor="166,181,214"
		                  textScaled="true"
		                  backgroundTransparency="1"
		                />
		              </Frame>
		              <TextLabel
		                name="{ item.name .. 'PriceLabel' }"
		                text="{ tostring(item.price) .. 'c' }"
		                size="0.14,1"
		                textColor="255,233,154"
		                textScaled="true"
		                backgroundTransparency="1"
		              />
		              <TextButton
		                name="{ item.name .. 'BuyButton' }"
		                text="{ state.coins >= item.price and 'Buy' or 'Need More' }"
		                size="0.24,1"
		                cornerRadius="12"
		                backgroundColor="{ state.coins >= item.price and Color3.fromRGB(58,95,70) or Color3.fromRGB(72,54,54) }"
		                textColor="245,245,255"
		                textScaled="true"
		                onClick="{ buySelectedShopItem({ id = item.id }) }"
		              />
		            </Frame>
		        ]=]))
		    end

		    return out
		}}
    </ScrollingFrame>
]]

local shopModal = [[
<Frame
  transition="fade"
  transitionTime="0.18"
  size="1,1"
  position="0,0"
  backgroundColor="0,0,0"
  backgroundTransparency="0.35"
  name="shop"
>
  <Frame
    name="shopModalPanel"
    transition="modal"
    transitionTime="0.24"
    size="0.56,0.68"
    position="0.22,0.16"
    backgroundColor="17,21,33"
    cornerRadius="22"
    direction="column"
    gap="12"
    padding="16"
  >
@include(shopHeader)
@include(shopItemList)
  </Frame>
</Frame>
]]

return {
	root = shopModal,
	fragments = {
		shopHeader = header,
		shopItemList = itemList,
	},
}
