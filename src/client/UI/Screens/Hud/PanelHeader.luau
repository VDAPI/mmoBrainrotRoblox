--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan package A): the one header
-- line of every HUD event panel (world boss, world event, Blood Moon, tourney, arena) and of every group of the quest
-- tracker. "▾" open / "▸" folded, the name (at most 20 characters: Logic/TextCaps panelTitle), one key value at the
-- right (the boss's HP, the time left, the score) and, where the panel has details, an "i" (InfoTip) that opens them
-- without folding. The whole line is one button: a click or a tap folds or opens the panel (the "i" keeps its own
-- click). HEIGHT_PC tall on PC, Theme.Size.MinTouch on a tablet and HEIGHT_PHONE on a phone, where it is one line of
-- the stack (Logic/PhoneHud.LINE), so a folded panel is exactly its header (Logic/HudStack folds a panel to that line
-- when the column has no room). The panels keep their open state on the account through Section.state (ids in
-- Data/Folds/Hud.luau); the tracker's groups keep theirs in Logic/TrackerFold.
--
--   PanelHeader.new(scope, { Title = name, Value = hp, Open = open, OnClick = toggle, Info = Text.T(scope, "...") })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Parent.Components.InfoTip)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Title: UsedAs<string>, -- the panel's name (at most 20 characters)
	Value: UsedAs<string>?, -- its one key value ("" or nil: none)
	Open: UsedAs<boolean>, -- the arrow: "▾" open, "▸" folded
	OnClick: () -> (), -- folds or opens (or brings a panel the column folded)
	Info: UsedAs<string>?, -- the details behind an "i" (InfoTip)
	Color: UsedAs<Color3>?, -- the name's colour (default Theme.Brass.Bright)
	Height: number?, -- a header of its own height (the quest tracker's top line); default PanelHeader.height
	Name: string?,
	LayoutOrder: UsedAs<number>?,
	Visible: UsedAs<boolean>?,
}

local PanelHeader = {}

PanelHeader.HEIGHT_PC = 32
PanelHeader.HEIGHT_PHONE = 52
local ARROW = 16
local VALUE = 76
local INFO = 28
local ROW_GAP = 4

-- The header's height: a phone's stack line, a tablet's touch minimum, PC's line.
function PanelHeader.height(touch: boolean, compact: boolean): number
	if compact then
		return PanelHeader.HEIGHT_PHONE
	end
	return if touch then Theme.Size.MinTouch else PanelHeader.HEIGHT_PC
end

-- The header's height now (it follows the device and the phone layout).
function PanelHeader.Height(scope: Scope): Fusion.Computed<number>
	return scope:Computed(function(use): number
		return PanelHeader.height(use(Device.Touch) == true, use(PhoneLayout.Compact))
	end)
end

function PanelHeader.new(scope: Scope, props: Props): Instance
	local hovered = scope:Value(false)
	local fixed = props.Height
	local height = if fixed
		then scope:Computed(function(): number
			return fixed
		end)
		else PanelHeader.Height(scope)
	local openProp, valueProp, infoProp = props.Open, props.Value, props.Info
	local hasValue = scope:Computed(function(use): boolean
		local text = if valueProp then use(valueProp) else nil
		return text ~= nil and text ~= ""
	end)
	-- the "i" next to the value (nothing without `Info`, hidden while its text is empty)
	local hasInfo = scope:Computed(function(use): boolean
		local text = if infoProp then use(infoProp) else nil
		return text ~= nil and text ~= ""
	end)
	local info: any = if infoProp
		then InfoTip.new(
			scope,
			{ LayoutOrder = 4, Title = props.Title, Text = infoProp, Surface = "iron", Visible = hasInfo }
		)
		else {}
	return scope:New("Frame")({
		Name = props.Name or "Header",
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, 0, 0, use(height))
		end),
		BackgroundTransparency = 1,
		[Children] = {
			-- the whole line folds and opens (the labels over it let the click through; the "i" does not)
			scope:New("TextButton")({
				Name = "Toggle",
				Size = UDim2.fromScale(1, 1),
				AutoButtonColor = false,
				BackgroundColor3 = Theme.Iron.Hover,
				BackgroundTransparency = scope:Computed(function(use): number
					return if use(hovered) then 0.4 else 1
				end),
				Text = "",
				[OnEvent("MouseEnter")] = function()
					hovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					hovered:set(false)
				end,
				[OnEvent("Activated")] = function()
					Sounds.play("click")
					props.OnClick()
				end,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			}),
			scope:New("Frame")({
				Name = "Row",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, ROW_GAP),
					}),
					scope:New("TextLabel")({
						Name = "Arrow",
						LayoutOrder = 1,
						Size = UDim2.new(0, ARROW, 1, 0),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return if use(openProp) then "▾" else "▸"
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Iron.Label,
					}),
					scope:New("TextLabel")({
						Name = "Title",
						LayoutOrder = 2,
						-- the name takes what the arrow, the value and the "i" leave
						Size = scope:Computed(function(use): UDim2
							local taken = ARROW + ROW_GAP
							if use(hasValue) then
								taken += VALUE + ROW_GAP
							end
							if use(hasInfo) then
								taken += INFO + ROW_GAP
							end
							return UDim2.new(1, -taken, 1, 0)
						end),
						BackgroundTransparency = 1,
						Text = props.Title,
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Small,
						TextColor3 = props.Color or Theme.Brass.Bright,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextLabel")({
						Name = "Value",
						LayoutOrder = 3,
						Size = UDim2.new(0, VALUE, 1, 0),
						Visible = hasValue,
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return if valueProp then use(valueProp) or "" else ""
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.Text,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					info,
				},
			}),
		},
	})
end

return PanelHeader
