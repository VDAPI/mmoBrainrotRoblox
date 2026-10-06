--!strict
-- Ground menu of the world map (S25): opened by a double click / long press on the map. "Walk here" (only on
-- the player's map), "Guide here" and "Place a mark ▸" with the six icons of Data/MapMarks. It lives in the
-- canvas at the clicked point and is counter-scaled, so it keeps its size at every zoom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MapMarks = require(ReplicatedStorage.Shared.Data.MapMarks)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Point = { map: string, x: number, z: number }

export type Props = {
	Touch: Fusion.UsedAs<boolean>,
	Scale: Fusion.UsedAs<number>, -- 1 / zoom
	OnHere: Fusion.UsedAs<boolean>, -- the shown map is the player's map
	OnWalk: (point: Point) -> (),
	OnGuide: (point: Point) -> (),
	OnMark: (point: Point, icon: string) -> (),
	Consume: () -> (), -- tells the window a button took this press
}

export type Api = {
	frame: Frame,
	open: (pixel: Vector2, point: Point, zoom: number) -> (),
	hide: () -> (),
}

local GroundMenu = {}

function GroundMenu.new(scope: Scope, props: Props): Api
	local point: Point? = nil
	local icons = scope:Value(false)
	local frame = scope:New("Frame")({
		Name = "GroundMenu",
		Size = UDim2.fromOffset(200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.03,
		ZIndex = 45,
		Visible = false,
		[Children] = {
			scope:New("UIScale")({ Scale = props.Scale }),
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
		},
	}) :: Frame

	local function hide()
		frame.Visible = false
		point = nil
		icons:set(false)
	end

	-- Runs `action` with the menu's point after closing the menu.
	local function take(action: (p: Point) -> ()): () -> ()
		return function()
			props.Consume()
			local p = point
			hide()
			if p then
				action(p)
			end
		end
	end

	local function button(order: number, key: string, onClick: () -> (), visible: Fusion.UsedAs<boolean>?): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = scope:Computed(function(use): UDim2
				return UDim2.new(1, 0, 0, if use(props.Touch) then 46 else 34)
			end),
			BackgroundColor3 = Theme.Colors.PanelRaised,
			Visible = visible,
			Text = Text.T(scope, key),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 15,
			TextColor3 = Theme.Colors.Parchment,
			ZIndex = 46,
			[OnEvent("Activated")] = onClick,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end

	button(1, "worldmap.menu.walk", take(props.OnWalk), props.OnHere).Parent = frame
	button(2, "worldmap.menu.guide", take(props.OnGuide)).Parent = frame
	button(3, "worldmap.menu.mark", function()
		props.Consume()
		icons:set(not Fusion.peek(icons))
	end).Parent =
		frame

	local iconButtons: { Instance } = {}
	for i, icon in MapMarks.list do
		table.insert(
			iconButtons,
			scope:New("TextButton")({
				LayoutOrder = i,
				Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				Text = icon.glyph,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 22,
				TextColor3 = Color3.fromHex(icon.color),
				ZIndex = 47,
				[OnEvent("Activated")] = take(function(p: Point)
					props.OnMark(p, icon.id)
				end),
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			})
		)
	end
	scope:New("Frame")({
		Parent = frame,
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = icons,
		[Children] = {
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(40, 40),
				CellPadding = UDim2.fromOffset(4, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			iconButtons :: any,
		},
	})

	local function open(pixel: Vector2, at: Point, zoom: number)
		point = at
		icons:set(false)
		frame.Position = UDim2.fromOffset(pixel.X + 6 / zoom, pixel.Y + 6 / zoom)
		frame.Visible = true
	end

	return { frame = frame, open = open, hide = hide }
end

return GroundMenu
