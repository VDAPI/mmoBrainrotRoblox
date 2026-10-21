--!strict
-- Shared collapsible section (2026-10-21, owner: too many detailed descriptions make the game hard to read). A window
-- keeps its short text visible and puts the rest under a "More ▸" header; a click / tap shows it and the header turns
-- into "Less ▾". Closed by default. With `Key` the open state is remembered for the session (Details.isOpen(key)), so a
-- window that is rebuilt (language, tab, reopening) keeps it. Full width, grows with its content (AutomaticSize Y).
--
--   Details.new(scope, { Key = "craft.rules", Children = { ...labels... }, LayoutOrder = 5 })
--   Details.new(scope, { Build = function(s) return { ...built only while open... } end })
--
-- Recipe "short line + (i)": docs/JAK-DODAC.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>
type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Key: string?, -- remembers the open state for the session under this key (nil: closed whenever built)
	Open: Fusion.Value<boolean>?, -- the caller's own state (wins over Key)
	Children: { Instance }?, -- the hidden content (built at once, shown while open)
	Build: ((Scope) -> any)?, -- or the content built on opening and destroyed on closing (long texts, many rows)
	MoreText: UsedAs<string>?, -- header while closed (default "More ▸", ui.details.more)
	LessText: UsedAs<string>?, -- header while open (default "Less ▾", ui.details.less)
	Surface: Theme.SurfaceName?, -- "paper" (default) or "iron"
	Padding: number?, -- space between the content rows (default 4)
	LayoutOrder: UsedAs<number>?,
	Position: UsedAs<UDim2>?,
	Size: UsedAs<UDim2>?, -- default full width, height from the content
	Visible: UsedAs<boolean>?,
	Name: string?,
}

local HEADER_PC = 26

local Details = {}

-- Open states of the keyed sections for this session.
local remembered: { [string]: boolean } = {}

function Details.isOpen(key: string): boolean
	return remembered[key] == true
end

function Details.setOpen(key: string, open: boolean)
	if open then
		remembered[key] = true
	else
		remembered[key] = nil
	end
end

function Details.new(scope: Scope, props: Props): Instance
	local key = props.Key
	local open: Fusion.Value<boolean> = props.Open
		or scope:Value(if key then Details.isOpen(key) else false) :: Fusion.Value<boolean>
	if key then
		scope:Observer(open):onChange(function()
			Details.setOpen(key, Fusion.peek(open))
		end)
	end
	local roles = Theme.surface(props.Surface)
	local hovered = scope:Value(false)

	local body: any
	if props.Build then
		local build = props.Build
		body = scope:Computed(function(use, s: Scope): any
			return if use(open) then build(s) else {}
		end)
	else
		body = props.Children or {}
	end

	return scope:New("Frame")({
		Name = props.Name or "Details",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Visible = props.Visible,
		Size = props.Size or UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
			scope:New("TextButton")({
				Name = "Header",
				LayoutOrder = 1,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				-- touch: a full row of at least Theme.Size.MinTouch; PC: a slim line
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, if use(Device.Touch) then Theme.Size.MinTouch else HEADER_PC)
				end),
				Text = scope:Computed(function(use): string
					if use(open) then
						return if props.LessText then use(props.LessText) else Text.get(use, "ui.details.less")
					end
					return if props.MoreText then use(props.MoreText) else Text.get(use, "ui.details.more")
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(hovered) then Theme.mix(roles.Link, roles.Text, 0.35) else roles.Link
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				[OnEvent("MouseEnter")] = function()
					hovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					hovered:set(false)
				end,
				[OnEvent("Activated")] = function()
					Sounds.play("click")
					open:set(not Fusion.peek(open))
				end,
			}),
			scope:New("Frame")({
				Name = "Body",
				LayoutOrder = 2,
				Visible = open,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, props.Padding or 4),
					}),
					body,
				},
			}),
		},
	})
end

return Details
