--!strict
-- Shared collapsible section (owner 2026-11-10: "a lot of text, some things cover others, too detailed descriptions,
-- nothing can be collapsed"). A window part under one header: "▾ Title" while open, "▸ Title" and under it one short
-- line (the `Summary`, e.g. the free stat points) while folded. The whole header is the button (a full row of at least
-- Theme.Size.MinTouch on touch), the folded line too; the "i" next to the title (`Info`, InfoTip) opens its own
-- popover, it does not fold. The line stands under the title, so a narrow column (the backpack window's 260) keeps it.
-- The open state is the account's (Logic/SectionFold: account.settings.sections, SetSetting "sections"), so it stays
-- after reopening the window, a relog and on another device; every id needs its default in Data/Folds. UI plan
-- 2026-11-10: a default may differ on a phone ({ pc, phone }: UI/PhoneLayout.Compact picks it), and a header that is
-- not a Section (a HUD panel's line, a settings group) shares the same state through Section.state.
-- Full width, grows with its content (AutomaticSize Y). Details (More ▸ / Less ▾) stays for a longer text under a
-- short one; a Section is a whole part of a window with its own title.
-- UI plan 2026-11-10 (package C): the header line looks like the HUD panels' (Hud/PanelHeader): ▾ / ▸, the title on
-- one line, the "i"; Theme.Size.SectionHeader (32) on PC, at least Theme.Size.MinTouch on touch.
--
--   Section.new(scope, { Id = "charStats", Title = Text.T(scope, "character.section.stats"), Children = { ... } })
--   Section.new(scope, { Id = ..., Title = ..., Summary = points, Accent = true, Build = function(s) ... end })
--   local open, setOpen = Section.state(scope, "charStats")
--
-- Recipe: docs/JAK-DODAC.md ("Zwijana sekcja").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.InfoTip)
local Net = require(ReplicatedStorage.Shared.Net)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local SectionFold = require(ReplicatedStorage.Shared.Logic.SectionFold)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>
type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Id: string, -- Data/Folds id (Logic/SectionFold): where the open state is kept and its default per device
	Title: UsedAs<string>,
	Summary: UsedAs<string?>?, -- the one short line under the folded header (nil or "": the bare title)
	Accent: UsedAs<boolean>?, -- the summary as a badge: something waits there (free stat points)
	Info: UsedAs<string>?, -- the details behind an "i" next to the title (InfoTip; rich text allowed)
	Children: { Instance }?, -- the content (built at once, shown while open)
	Build: ((Scope) -> any)?, -- or the content built on opening and destroyed on folding
	Surface: Theme.SurfaceName?, -- "paper" (default) or "iron"
	Padding: number?, -- room between the content rows (default Theme.Padding.Small)
	LayoutOrder: UsedAs<number>?,
	Position: UsedAs<UDim2>?,
	Size: UsedAs<UDim2>?, -- default full width, height from the content
	Visible: UsedAs<boolean>?,
	Name: string?,
}

local HEADER_PC = Theme.Size.SectionHeader
local ARROW_WIDTH = 18
local ROW_GAP = 6
local SUMMARY_PC = 26
local SEND_DELAY = 0.4 -- s: the clicks of a moment go to the server as one SetSetting (rate limit 2/s)

local Section = {}

-- One state for every section: the saved setting, and the player's clicks until the save comes back.
local moduleScope = Fusion.scoped(Fusion)
local saved = State.Value({ "account", "settings", "sections" })
local live = moduleScope:Value(nil :: { [string]: boolean }?)
moduleScope:Observer(saved):onChange(function()
	local now = Fusion.peek(live)
	if now and SectionFold.same(now, Fusion.peek(saved)) then
		live:set(nil)
	end
end)
local current = moduleScope:Computed(function(use): any
	local now = use(live)
	return if now then now else use(saved)
end)
local openStates: { [string]: Fusion.Computed<boolean> } = {}
local sendQueued = false

local function queueSend()
	if sendQueued then
		return
	end
	sendQueued = true
	task.delay(SEND_DELAY, function()
		sendQueued = false
		local now = Fusion.peek(live)
		if now and not SectionFold.same(now, Fusion.peek(saved)) then
			Net.Send("SetSetting", "sections", now)
		end
	end)
end

-- Whether section `id` stands open (a state, for a layout that follows it): the player's choice, else the default of
-- this device (the phone layout may fold what a PC opens).
function Section.Open(id: string): Fusion.Computed<boolean>
	assert(SectionFold.known(id), `no section {id} in Data/Folds`)
	local state = openStates[id]
	if not state then
		state = moduleScope:Computed(function(use): boolean
			return SectionFold.isOpen(use(current), id, use(PhoneLayout.Compact))
		end)
		openStates[id] = state
	end
	return state :: Fusion.Computed<boolean>
end

-- Opens or folds section `id` at once and saves it on the account (the choice then holds on every device).
function Section.set(id: string, open: boolean)
	local now = Fusion.peek(current)
	local compact = Fusion.peek(PhoneLayout.Compact)
	if SectionFold.isOpen(now, id, compact) == open then
		return
	end
	live:set(SectionFold.with(now, id, open, compact))
	queueSend()
end

function Section.toggle(id: string)
	Section.set(id, not SectionFold.isOpen(Fusion.peek(current), id, Fusion.peek(PhoneLayout.Compact)))
end

-- The open state of section `id` and its setter, for a header that is not a Section.new (a HUD panel's line, a settings
-- group): the same account setting, device default and SetSetting "sections" save as Section.new, so a Section and
-- such a header with one id always agree. The state belongs to `scope`.
function Section.state(scope: Scope, id: string): (Fusion.Computed<boolean>, (open: boolean) -> ())
	local shared = Section.Open(id)
	local open = scope:Computed(function(use): boolean
		return use(shared)
	end)
	local function setOpen(value: boolean)
		Section.set(id, value)
	end
	return open, setOpen
end

function Section.new(scope: Scope, props: Props): Instance
	local id = props.Id
	local open = Section.Open(id)
	local roles = Theme.surface(props.Surface)
	local hovered = scope:Value(false)
	local summaryProp, accentProp, infoProp = props.Summary, props.Accent, props.Info
	local summary = scope:Computed(function(use): string
		local text = if summaryProp then use(summaryProp) else nil
		return if use(open) or text == nil then "" else text
	end)
	local accent = scope:Computed(function(use): boolean
		return accentProp ~= nil and use(accentProp) == true
	end)
	-- the "i" next to the title (nothing without `Info`)
	local info: any = if infoProp
		then InfoTip.new(scope, { LayoutOrder = 3, Title = props.Title, Text = infoProp, Surface = props.Surface })
		else {}

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
		Name = props.Name or `Section_{id}`,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Visible = props.Visible,
		Size = props.Size or UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			scope:New("Frame")({
				Name = "Header",
				LayoutOrder = 1,
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, if use(Device.Touch) then Theme.Size.MinTouch else HEADER_PC)
				end),
				BackgroundTransparency = 1,
				[Children] = {
					-- the whole header folds and opens (the labels over it let the click through; the "i" does not)
					scope:New("TextButton")({
						Name = "Toggle",
						Size = UDim2.fromScale(1, 1),
						AutoButtonColor = false,
						BackgroundColor3 = roles.Hover,
						BackgroundTransparency = scope:Computed(function(use): number
							return if use(hovered) then 0 else 1
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
							Section.toggle(id)
						end,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						},
					}),
					scope:New("Frame")({
						Name = "Row",
						Size = UDim2.new(1, 0, 1, -Theme.Stroke.Thin),
						BackgroundTransparency = 1,
						ZIndex = 2,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, ROW_GAP),
							}),
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, Theme.Padding.Tiny),
								PaddingRight = UDim.new(0, Theme.Padding.Tiny),
							}),
							scope:New("TextLabel")({
								Name = "Arrow",
								LayoutOrder = 1,
								Size = UDim2.new(0, ARROW_WIDTH, 1, 0),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use): string
									return if use(open) then "▾" else "▸"
								end),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = roles.Label,
							}),
							scope:New("TextLabel")({
								Name = "Title",
								LayoutOrder = 2,
								Size = UDim2.fromScale(0, 1),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								Text = props.Title,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = roles.Heading,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextWrapped = false,
								TextTruncate = Enum.TextTruncate.AtEnd,
								[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
							}),
							info,
						},
					}),
					scope:New("Frame")({
						Name = "Rule",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, Theme.Stroke.Thin),
						BackgroundColor3 = roles.Rule,
						BorderSizePixel = 0,
						ZIndex = 2,
					}),
				},
			}),
			-- folded: one short line under the title (a badge when something waits there); a click opens the section too
			scope:New("TextButton")({
				Name = "Summary",
				LayoutOrder = 2,
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, if use(Device.Touch) then Theme.Size.MinTouch else SUMMARY_PC)
				end),
				Visible = scope:Computed(function(use): boolean
					return use(summary) ~= ""
				end),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Text = "",
				[OnEvent("Activated")] = function()
					Sounds.play("click")
					Section.toggle(id)
				end,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					-- under the title, past the arrow
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Padding.Tiny + ARROW_WIDTH + ROW_GAP),
						PaddingRight = UDim.new(0, Theme.Padding.Tiny),
					}),
					scope:New("TextLabel")({
						Name = "Text",
						Size = UDim2.fromOffset(0, Theme.TextSize.Small + 8),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundColor3 = roles.Accent,
						BackgroundTransparency = scope:Computed(function(use): number
							return if use(accent) then 0 else 1
						end),
						Text = summary,
						FontFace = scope:Computed(function(use): Font
							return if use(accent) then Theme.Fonts.BodyBold else Theme.Fonts.Body
						end),
						TextSize = Theme.TextSize.Small,
						TextColor3 = scope:Computed(function(use): Color3
							return if use(accent) then roles.AccentText else roles.TextMuted
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						[Children] = {
							scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							scope:New("UIPadding")({
								-- a plain line starts under the title, a badge's text 8 into its pill
								PaddingLeft = scope:Computed(function(use): UDim
									return UDim.new(0, if use(accent) then 8 else 0)
								end),
								PaddingRight = UDim.new(0, 8),
							}),
						},
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Body",
				LayoutOrder = 3,
				Visible = open,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, props.Padding or Theme.Padding.Small),
					}),
					body,
				},
			}),
		},
	})
end

return Section
