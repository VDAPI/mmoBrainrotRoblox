--!strict
-- Auto Hunt on the HUD (S134d): right of the Cloak of Luring. Shown while the account has Auto Hunt time in the bank
-- or a hunt runs (never a dead button); under the icon the time possible now (the bank cut by today's cap,
-- Logic/AutoGrind.left). States: hunting (gold frame), off (grey). Click / tap starts or stops it (AutoGrind remote;
-- the server answers with a toast: started on <ground>, or why not).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AutoGrind = require(ReplicatedStorage.Shared.Logic.AutoGrind)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Motion = require(script.Parent.Parent.Parent.Motion)
local Lure = require(ReplicatedStorage.Shared.Logic.Lure)
local Net = require(ReplicatedStorage.Shared.Net)
local RequestGuard = require(ReplicatedStorage.Shared.Logic.RequestGuard)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 48
local GLYPH = "⚔"
local HUNT = Theme.Glyph.Hunt

local function AutoGrindButton(scope: Scope, position: Fusion.UsedAs<UDim2>): Instance
	local bank = State.Value({ "account", "autoGrind" })
	local runtime = State.Value({ "autoGrind" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	-- the clock ticks every few seconds (the UTC day may reset today's cap); the runtime branch updates while hunting
	task.spawn(function()
		while alive do
			task.wait(5)
			if alive then
				now:set(Workspace:GetServerTimeNow())
			end
		end
	end)

	local hunting = scope:Computed(function(use): boolean
		local rt = use(runtime)
		return type(rt) == "table" and rt.active == true
	end)
	local state = scope:Computed(function(use): AutoGrind.State?
		local s = use(bank)
		return if type(s) == "table" then s else nil
	end)
	local left = scope:Computed(function(use): number
		local rt = use(runtime)
		if type(rt) == "table" and type(rt.left) == "number" then
			return rt.left
		end
		return AutoGrind.left(use(state), use(now))
	end)
	local function timeText(use: Fusion.Use, seconds: number): string
		local key, args = Lure.timeKey(seconds)
		return Text.get(use, key, args)
	end

	local button = scope:New("TextButton")({
		Name = "AutoGrindButton",
		Size = UDim2.fromOffset(SIZE, SIZE),
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Text = GLYPH,
		TextScaled = true,
		FontFace = Theme.Fonts.BodyBold,
		TextColor3 = scope:Computed(function(use): Color3
			return if use(hunting) then HUNT else Theme.Iron.TextMuted
		end),
		[OnEvent("Activated")] = function()
			local wanted = not Fusion.peek(hunting)
			task.spawn(function()
				local ok, err = Net.Invoke("AutoGrind", wanted)
				if ok then
					Sounds.play(if wanted then "levelUp" else "click")
				elseif not RequestGuard.isSilent(err) then
					Sounds.play("error")
					Toast.push(Text.now(err or "error.internal"), "error")
				end
			end)
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = scope:Computed(function(use): Color3
					return if use(hunting) then Theme.Brass.Bright else Theme.Iron.TextMuted
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		},
	})
	Motion.feedback(scope, button :: GuiButton, Theme.Corner.Small) -- W28: hover sheen and a sink while held
	Tooltip.attach(
		scope,
		button :: GuiObject,
		scope:Computed(function(use): string
			local s = use(state)
			local t = use(now)
			return Text.get(use, "hud.autoGrind", {
				state = Text.get(use, if use(hunting) then "hud.autoGrind.on" else "hud.autoGrind.off"),
				bank = timeText(use, AutoGrind.rollDay(s, t).bank),
				today = timeText(use, AutoGrind.todayLeft(s, t)),
			})
		end)
	)

	return scope:New("Frame")({
		Name = "AutoGrind",
		Position = position,
		Size = UDim2.fromOffset(SIZE, SIZE + 20),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			local s = use(state)
			return use(hunting) or (s ~= nil and (s.bank or 0) > 0)
		end),
		[Children] = {
			button,
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(-12, SIZE),
				Size = UDim2.fromOffset(SIZE + 24, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return timeText(use, use(left))
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextStrokeTransparency = 0.3,
			}),
		},
	})
end

return AutoGrindButton
