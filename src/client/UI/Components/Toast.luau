--!strict
-- Toast notifications: a short stack at the top centre of the screen. Toast.push(text, kind) from
-- anywhere; at most MAX_VISIBLE are shown, the rest wait in a queue. Toast.mount(scope, root) once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local RequestGuard = require(ReplicatedStorage.Shared.Logic.RequestGuard)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

export type Kind = "info" | "success" | "warning" | "error"

-- W28: `leave` is set by the toast's own view: it starts the fade-out before the entry leaves the list
type Entry = { id: number, text: string, kind: Kind, duration: number, leave: (() -> ())? }

local Toast = {}

local MAX_VISIBLE = 4
local DEFAULT_DURATION = 3.5
local WIDTH = 520

-- S135: an iron toast with a brass edge; the kind colours the edge (roles of the iron surface).
local ACCENT: { [Kind]: Color3 } = {
	info = Theme.Brass.Line,
	success = Theme.Iron.Success,
	warning = Theme.Iron.Warning,
	error = Theme.Iron.Danger,
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
		-- W28: fade and shrink out first, then free the place in the stack
		local leave = entry.leave
		if leave then
			leave()
		end
		task.delay(if leave then Theme.Anim.ToastOutTime else 0, function()
			remove(entry.id)
			pump()
		end)
	end)
	pump()
end

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

function Toast.push(text: string, kind: Kind?, duration: number?)
	if silent(text) then
		return
	end
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
				-- W28: in: fade and grow from ToastFrom on the window spring; out: fade and shrink back on a short tween
				local transparency = innerScope:Value(1)
				local info = innerScope:Value(Theme.Anim.Normal)
				local animated = innerScope:Tween(transparency, info)
				local grow = innerScope:Value(Theme.Anim.ToastFrom)
				local size = innerScope:Spring(grow, Theme.Anim.WindowSpeed, Theme.Anim.WindowDamping)
				task.defer(function()
					transparency:set(0)
					grow:set(1)
				end)
				entry.leave = function()
					info:set(Theme.Anim.ToastOut)
					transparency:set(1)
					grow:set(Theme.Anim.ToastFrom)
				end
				return innerScope:New("Frame")({
					Name = `Toast{entry.id}`,
					LayoutOrder = entry.id,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Theme.Iron.Surface,
					BackgroundTransparency = innerScope:Computed(function(use): number
						return 0.08 + use(animated) * 0.92
					end),
					[Children] = {
						innerScope:New("UIScale")({ Scale = size }),
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
							TextColor3 = Theme.Iron.Text,
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
