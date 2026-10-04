--!strict
-- Toast notifications: a short stack at the top centre of the screen. Toast.push(text, kind) from
-- anywhere; at most MAX_VISIBLE are shown, the rest wait in a queue. Toast.mount(scope, root) once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

export type Kind = "info" | "success" | "warning" | "error"

type Entry = { id: number, text: string, kind: Kind, duration: number }

local Toast = {}

local MAX_VISIBLE = 4
local DEFAULT_DURATION = 3.5
local WIDTH = 520

local ACCENT: { [Kind]: Color3 } = {
	info = Theme.Colors.Gold,
	success = Theme.Colors.Success,
	warning = Theme.Colors.Warning,
	error = Theme.Colors.Danger,
}

local moduleScope = Fusion.scoped(Fusion)
local visible = moduleScope:Value({} :: { Entry })
local queue: { Entry } = {}
local nextId = 0

local function remove(id: number)
	local list = table.clone(Fusion.peek(visible))
	for i, entry in list do
		if entry.id == id then
			table.remove(list, i)
			break
		end
	end
	visible:set(list)
end

local function pump()
	local list = Fusion.peek(visible)
	if #list >= MAX_VISIBLE or #queue == 0 then
		return
	end
	local entry = table.remove(queue, 1) :: Entry
	local newList = table.clone(list)
	table.insert(newList, entry)
	visible:set(newList)
	task.delay(entry.duration, function()
		remove(entry.id)
		pump()
	end)
	pump()
end

function Toast.push(text: string, kind: Kind?, duration: number?)
	nextId += 1
	local entry: Entry = {
		id = nextId,
		text = text,
		kind = kind or "info",
		duration = duration or DEFAULT_DURATION,
	}
	if entry.kind == "error" then
		Sounds.play("error")
	end
	table.insert(queue, entry)
	pump()
end

function Toast.mount(scope: Fusion.Scope<typeof(Fusion)>, parent: Instance)
	scope:New("Frame")({
		Name = "Toasts",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			scope:ForValues(visible, function(_, innerScope: Fusion.Scope<typeof(Fusion)>, entry: Entry)
				local transparency = innerScope:Value(1)
				local animated = innerScope:Tween(transparency, Theme.Anim.Normal)
				task.defer(function()
					transparency:set(0)
				end)
				return innerScope:New("Frame")({
					Name = `Toast{entry.id}`,
					LayoutOrder = entry.id,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Theme.Colors.Panel,
					BackgroundTransparency = innerScope:Computed(function(use): number
						return 0.08 + use(animated) * 0.92
					end),
					[Children] = {
						innerScope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						innerScope:New("UIStroke")({
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Thickness = Theme.Stroke.Normal,
							Color = ACCENT[entry.kind],
							Transparency = animated,
						}),
						innerScope:New("UIPadding")({
							PaddingTop = UDim.new(0, 10),
							PaddingBottom = UDim.new(0, 10),
							PaddingLeft = UDim.new(0, Theme.Padding.Large),
							PaddingRight = UDim.new(0, Theme.Padding.Large),
						}),
						innerScope:New("TextLabel")({
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Text = entry.text,
							RichText = true,
							FontFace = Theme.Fonts.BodyMedium,
							TextSize = Theme.TextSize.Body,
							TextColor3 = Theme.Colors.Text,
							TextTransparency = animated,
							TextWrapped = true,
						}),
					},
				})
			end) :: any,
		},
	})
end

return Toast
