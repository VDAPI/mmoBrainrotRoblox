--!strict
-- Toast notifications: Toast.push(text, kind, duration, info) from anywhere; Toast.mount(scope, root) once (UIController).
-- UI plan phase 2 (one band of messages at the top, Logic/TopBand): two at once instead of four, under the banner.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): a toast goes
-- through UI/Notify, the one queue of the client's messages (Logic/NoticeQueue): at most 2 on PC in the band under the
-- target, one line in a phone's M zone, the same text within 10 s once with ×N, the same error at most once per 10 s,
-- and in combat an info or success toast waits up to 10 s (then drops). This file keeps the toast's look and its
-- callers' signature; mount builds the whole message host.
-- UI plan package B, texts: a toast is one short line (at most 60 characters, Logic/TextCaps). When there is more to
-- say (`info`, NotificationController: the key's ".info" text) the toast ends with a drawn "i" (a circle with the
-- letter, owner S68: not the sign) and a click or tap on it opens the whole text (UI/Notify.details) and closes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local RequestGuard = require(ReplicatedStorage.Shared.Logic.RequestGuard)
local SoftRequire = require(script.Parent.Parent.SoftRequire)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
-- Studio check 2026-10-31 (UI/SoftRequire): about 25 controllers require the toasts, so the new message door is soft
-- here; without it (not synced yet) the toasts show nothing instead of taking those controllers down.
local Notify = SoftRequire(
	function()
		return require(script.Parent.Parent.Notify)
	end,
	{
		push = function(_spec: any): any
			return nil
		end,
		mount = function(_scope: any, _parent: any) end,
		details = function(_build: any, _seconds: any) end,
	} :: any,
	"UI/Notify"
)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

export type Kind = "info" | "success" | "warning" | "error"

type Scope = Fusion.Scope<typeof(Fusion)>
-- UI/Notify.Live (a soft require carries no types)
type Live = { id: number, count: Fusion.Value<number>, phone: boolean, close: () -> (), relayout: () -> () }

local Toast = {}

-- S135: an iron toast with a brass edge; the kind colours the edge (roles of the iron surface).
local ACCENT: { [Kind]: Color3 } = {
	info = Theme.Brass.Line,
	success = Theme.Iron.Success,
	warning = Theme.Iron.Warning,
	error = Theme.Iron.Danger,
}

-- A toast with more to say (`info`): the drawn "i", its gap to the text, a little longer on the screen (to be
-- clicked) and the width of the whole text's panel on PC (a phone's sheet fills the screen's width).
local ICON = 18
local ICON_GAP = 6
local INFO_SECONDS = 6
local INFO_WIDTH = 460

-- W28: callers toast a failed request as Text.now(err); "too fast" / "already done" answers
-- (RequestGuard.SILENT: a merged double click, a rate limit, a slot the click before already emptied) show nothing.
local function silent(text: string): boolean
	for key in RequestGuard.SILENT do
		if text == key or text == Text.now(key) then
			return true
		end
	end
	return false
end

-- The whole text behind a toast's "i" (UI/Notify.details): the toast's line, then the text; centred on PC, a phone's
-- sheet fills its width from the top. A tap beside it closes it.
local function infoView(text: string, info: string): (Scope, () -> (), boolean) -> Instance
	return function(s: Scope, _close: () -> (), sheet: boolean): Instance
		local function line(order: number, value: string, color: Color3, font: Font): Instance
			return s:New("TextLabel")({
				LayoutOrder = order,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = value,
				RichText = true,
				TextWrapped = true,
				FontFace = font,
				TextSize = Theme.TextSize.Body,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end
		return s:New("Frame")({
			Name = "ToastInfo",
			AnchorPoint = if sheet then Vector2.zero else Vector2.new(0.5, 0.5),
			Position = if sheet then UDim2.new() else UDim2.fromScale(0.5, 0.5),
			Size = if sheet then UDim2.fromScale(1, 0) else UDim2.fromOffset(INFO_WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Iron.Surface,
			Active = true, -- a tap inside never reaches the dimmed backdrop
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
				s:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = Theme.Stroke.Thick,
					Color = Theme.Iron.Rule,
				}),
				s:New("UIPadding")({
					PaddingTop = UDim.new(0, Theme.Padding.Medium),
					PaddingBottom = UDim.new(0, Theme.Padding.Medium),
					PaddingLeft = UDim.new(0, Theme.Padding.Medium),
					PaddingRight = UDim.new(0, Theme.Padding.Medium),
				}),
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				line(1, text, Theme.Brass.Bright, Theme.Fonts.BodyBold),
				line(2, info, Theme.Iron.Text, Theme.Fonts.Body),
			},
		})
	end
end

-- The drawn "i" at a toast's right end (owner S68: a circle with the letter, not the sign).
local function infoIcon(s: Scope): Instance
	return s:New("Frame")({
		Name = "Info",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundColor3 = Theme.Brass.Line,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			s:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "i",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = ICON - 4,
				TextColor3 = Theme.Iron.Surface,
			}),
		},
	})
end

-- The toast's look in the place UI/Notify gives it: the text, "×N" when it came again, the "i" when it has `info`.
local function view(text: string, kind: Kind, info: string?): (Scope, Live) -> Instance
	return function(s: Scope, live: Live): Instance
		local padX = if live.phone then Theme.Padding.Small else Theme.Padding.Large
		local inset = if info then ICON + ICON_GAP else 0
		local children: { Instance } = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = ACCENT[kind],
			}),
			s:New("UIPadding")({
				PaddingLeft = UDim.new(0, padX),
				PaddingRight = UDim.new(0, padX),
			}),
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -inset, 1, 0),
				Text = s:Computed(function(use): string
					local n = use(live.count)
					return if n > 1 then `{text}  ×{n}` else text
				end),
				RichText = true,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = if live.phone then Theme.TextSize.Small else Theme.TextSize.Body,
				TextColor3 = Theme.Iron.Text,
				TextWrapped = true,
				-- review 2026-11-10: a phone's toast is at most M tall (Logic/TopBand.slots): its end shows cut
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}
		if info then
			table.insert(children, infoIcon(s))
		end
		local props: { [any]: any } = {
			Name = "Toast",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = 0.08,
			[Children] = children,
		}
		if info == nil then
			return s:New("Frame")(props)
		end
		props.Text = ""
		props.AutoButtonColor = false
		props[OnEvent("Activated")] = function()
			live.close()
			Notify.details(infoView(text, info))
		end
		return s:New("TextButton")(props)
	end
end

-- `info`: the whole text behind the toast's "i" (rich text allowed), nil for a plain toast.
function Toast.push(text: string, kind: Kind?, duration: number?, info: string?)
	if silent(text) then
		return
	end
	local tone: Kind = kind or "info"
	local handle = Notify.push({
		class = "toast",
		text = text,
		tone = tone,
		seconds = duration or (if info then INFO_SECONDS else nil),
		inset = if info then ICON + ICON_GAP else nil,
		build = view(text, tone, info),
	})
	if handle and tone == "error" then
		Sounds.play("error")
	end
end

-- Builds the message host of the Toasts layer (UI/Notify): the band, the cards, the barks and the cards' full views.
function Toast.mount(scope: Fusion.Scope<typeof(Fusion)>, parent: Instance)
	Notify.mount(scope, parent)
end

return Toast
