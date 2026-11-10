--!strict
-- Toast notifications: Toast.push(text, kind, duration) from anywhere; Toast.mount(scope, root) once (UIController).
-- UI plan phase 2 (one band of messages at the top, Logic/TopBand): two at once instead of four, under the banner.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): a toast goes
-- through UI/Notify, the one queue of the client's messages (Logic/NoticeQueue): at most 2 on PC in the band under the
-- target, one line in a phone's M zone, the same text within 10 s once with ×N, the same error at most once per 10 s,
-- and in combat an info or success toast waits up to 10 s (then drops). This file keeps the toast's look and its
-- callers' signature; mount builds the whole message host.

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
	} :: any,
	"UI/Notify"
)

local Children = Fusion.Children

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

-- The toast's look in the place UI/Notify gives it: the text, "×N" when it came again.
local function view(text: string, kind: Kind): (Scope, Live) -> Instance
	return function(s: Scope, live: Live): Instance
		local padX = if live.phone then Theme.Padding.Small else Theme.Padding.Large
		return s:New("Frame")({
			Name = "Toast",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = 0.08,
			[Children] = {
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
					Size = UDim2.fromScale(1, 1),
					Text = s:Computed(function(use): string
						local n = use(live.count)
						return if n > 1 then `{text}  ×{n}` else text
					end),
					RichText = true,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = if live.phone then Theme.TextSize.Small else Theme.TextSize.Body,
					TextColor3 = Theme.Iron.Text,
					TextWrapped = true,
				}),
			},
		})
	end
end

function Toast.push(text: string, kind: Kind?, duration: number?)
	if silent(text) then
		return
	end
	local tone: Kind = kind or "info"
	local handle = Notify.push({
		class = "toast",
		text = text,
		tone = tone,
		seconds = duration,
		build = view(text, tone),
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
