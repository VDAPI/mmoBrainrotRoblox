--!strict
-- Build set switch (S58, ROZWOJ 2.9, 4): "Set 1" / "Set 2" and, with ShowModal, "Copy" with a confirmation. The server
-- checks every rule (place, combat, death, dungeon run, cooldown) and sends the success toast and the path weapon
-- warning; here only an error toast. Used in the skills window header (S59 full window: Height 44 on a phone) and in
-- the character window. S135: the two sets are drawn as tab cards (the active one with an iron frame), "Copy" stays
-- a secondary button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Modal = require(script.Parent.Modal)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Toast)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	ShowModal: ((Modal.Spec) -> ())?, -- given: a "Copy" button with a confirmation
	Height: number?, -- default Theme.Size.ButtonHeightSmall; S59 phone header: 44
	ButtonWidth: number?, -- default 96
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	Size: UsedAs<UDim2>?, -- default automatic width
	LayoutOrder: UsedAs<number>?,
	Surface: Theme.SurfaceName?, -- S135 (default "paper")
}

local function BuildSetSwitch(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local height = props.Height or Theme.Size.ButtonHeightSmall
	local width = props.ButtonWidth or 96
	local roles = Theme.surface(props.Surface)
	local busy = scope:Value(false)
	local stored = State.Value({ "character", "buildSlot" })
	local slot = scope:Computed(function(use): number
		return if use(stored) == 2 then 2 else 1
	end)

	local function switchTo(n: number)
		if Fusion.peek(busy) or Fusion.peek(slot) == n then
			return
		end
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("SwitchBuildSet")
			busy:set(false)
			if not ok then
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local buttons: { Instance } = {}
	for n = 1, 2 do
		local active = scope:Computed(function(use): boolean
			return use(slot) == n
		end)
		table.insert(
			buttons,
			scope:New("TextButton")({
				Name = `Set{n}`,
				LayoutOrder = n,
				Size = UDim2.fromOffset(width, height),
				AutoButtonColor = false,
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(active) then roles.Surface else roles.Sunken
				end),
				Text = Text.T(scope, "buildset.set", { n = n }),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(active) then roles.Heading else roles.TextMuted
				end),
				[Fusion.OnEvent("Activated")] = function()
					if not Fusion.peek(busy) then
						Sounds.play("click")
						switchTo(n)
					end
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = scope:Computed(function(use): number
							return if use(active) then Theme.Stroke.Normal else Theme.Stroke.Thin
						end),
						Color = scope:Computed(function(use): Color3
							if use(active) then
								return if props.Surface == "iron" then Theme.Brass.Line else Theme.Brass.Frame
							end
							return roles.Border
						end),
					}),
				},
			})
		)
	end

	local showModal = props.ShowModal
	if showModal then
		table.insert(
			buttons,
			Button(scope, {
				Name = "Copy",
				Text = Text.T(scope, "buildset.copy"),
				Variant = "secondary",
				Surface = props.Surface,
				Disabled = busy,
				Size = UDim2.fromOffset(width, height),
				TextSize = Theme.TextSize.Small,
				LayoutOrder = 3,
				OnClick = function()
					local from = Fusion.peek(slot)
					showModal({
						Title = Text.now("buildset.copy.title"),
						Message = Text.now("buildset.copy.message", { from = from, to = 3 - from }),
						-- owner 2026-10-21: what is copied and that the free reset stays, under "More ▸"
						Details = Text.now("buildset.copy.message.info", { from = from, to = 3 - from }),
						ConfirmText = Text.now("buildset.copy"),
						CancelText = Text.now("common.cancel"),
						OnConfirm = function(): (boolean, string?)
							local ok, err = Net.Invoke("CopyBuildSet")
							if ok then
								return true, nil
							end
							return false, Text.now(err or "error.internal")
						end,
					})
				end,
			})
		)
	end

	return scope:New("Frame")({
		Name = "BuildSetSwitch",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.fromOffset(0, height),
		AutomaticSize = if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			buttons :: any,
		},
	})
end

return BuildSetSwitch
