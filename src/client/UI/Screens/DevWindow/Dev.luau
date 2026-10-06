--!strict
-- Shared state and helpers of the dev panel (S23): running commands through AdminRun (busy lock, danger
-- confirmation, result in the status bar and the console log), layout helpers and the generic command rows
-- built from Data/AdminCommands (every command gets one, so later sessions need no UI work), favourites.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminCommands = require(ReplicatedStorage.Shared.Data.AdminCommands)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local NumberInput = require(script.Parent.Parent.Parent.Components.NumberInput)
local Select = require(script.Parent.Parent.Parent.Components.Select)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

export type Scope = Fusion.Scope<typeof(Fusion)>

local Dev = {}

local scope = Fusion.scoped(Fusion)

Dev.LOG_SIZE = 100
Dev.HISTORY_SIZE = 30

-- Persistent across openings of the window (session only).
Dev.Busy = scope:Value(false)
Dev.Status = scope:Value({ ok = true, text = "" })
Dev.Log = scope:Value({} :: { { text: string, ok: boolean? } })
Dev.History = {} :: { string }
Dev.Tab = scope:Value("character")
Dev.ConsoleLine = scope:Value("")

local showModal: ((spec: any) -> ())? = nil

function Dev.setModal(fn: (spec: any) -> ())
	showModal = fn
end

local function log(text: string, ok: boolean?)
	local list = table.clone(Fusion.peek(Dev.Log))
	table.insert(list, { text = text, ok = ok })
	while #list > Dev.LOG_SIZE do
		table.remove(list, 1)
	end
	Dev.Log:set(list)
end

function Dev.lineText(line: any): string
	if type(line) ~= "table" or type(line.key) ~= "string" then
		return tostring(line)
	end
	return Text.now(line.key, if type(line.args) == "table" then line.args else nil)
end

-- Runs a command now (no confirmation). `done(ok, err, lines)` gets the raw result.
local function invoke(name: string, args: { string }, done: ((boolean, string?, { any }?) -> ())?)
	Dev.Busy:set(true)
	local shown = `/{name} {table.concat(args, " ")}`
	table.insert(Dev.History, shown)
	while #Dev.History > Dev.HISTORY_SIZE do
		table.remove(Dev.History, 1)
	end
	log(`> {shown}`, nil)
	task.spawn(function()
		local ok, err, lines = Net.Invoke("AdminRun", name, args)
		Dev.Busy:set(false)
		local texts = {}
		for _, line in (if type(lines) == "table" then lines else {}) :: { any } do
			local text = Dev.lineText(line)
			table.insert(texts, text)
			log(text, ok == true)
		end
		if not ok then
			local errText = Text.now(err or "error.network")
			if not table.find(texts, errText) then
				log(errText, false)
				table.insert(texts, errText)
			end
			Sounds.play("error")
		end
		Dev.Status:set({
			ok = ok == true,
			text = `{shown} → {texts[#texts] or (if ok then "OK" else "?")}`,
		})
		if done then
			done(ok == true, err, if type(lines) == "table" then lines else nil)
		end
	end)
end

-- Runs a command from the panel; dangerous ones ask first.
function Dev.run(name: string, args: { string }?, done: ((boolean, string?, { any }?) -> ())?)
	local list = args or {}
	if Fusion.peek(Dev.Busy) then
		return
	end
	local def = AdminCommands.get(name)
	if def and AdminCommands.isDangerous(def, list) and showModal then
		showModal({
			Title = Text.now("dev.confirm.title"),
			Message = Text.now("dev.confirm.message", { command = `/{name} {table.concat(list, " ")}` }),
			ConfirmText = Text.now("dev.confirm.run"),
			CancelText = Text.now("common.cancel"),
			Variant = "danger",
			OnConfirm = function(): (boolean, string?)
				invoke(name, list, done)
				return true, nil
			end,
		})
		return
	end
	invoke(name, list, done)
end

-- Runs without asking (second step of a double confirmation).
function Dev.runConfirmed(name: string, args: { string }, done: ((boolean, string?, { any }?) -> ())?)
	invoke(name, args, done)
end

function Dev.confirm(titleKey: string, messageKey: string, onYes: () -> ())
	if not showModal then
		return
	end
	showModal({
		Title = Text.now(titleKey),
		Message = Text.now(messageKey),
		ConfirmText = Text.now("dev.confirm.run"),
		CancelText = Text.now("common.cancel"),
		Variant = "danger",
		OnConfirm = function(): (boolean, string?)
			onYes()
			return true, nil
		end,
	})
end

-- Layout ------------------------------------------------------------------------------------------------------

-- Scrolling column for a tab's content.
function Dev.column(s: Scope, children: { any }): Instance
	return s:New("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		[Children] = {
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			s:New("UIPadding")({ PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
			children :: any,
		},
	})
end

-- Section header.
function Dev.header(s: Scope, order: number, key: string): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = Text.T(s, key),
		FontFace = Theme.Fonts.Heading,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Colors.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- A wrapping row of controls with an optional label in front.
function Dev.row(s: Scope, order: number, label: Fusion.UsedAs<string>?, children: { any }): Instance
	local items: { any } = {
		s:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Wraps = true,
			Padding = UDim.new(0, 6),
		}),
	}
	if label then
		table.insert(
			items,
			s:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.fromOffset(150, Theme.Size.MinTouch),
				BackgroundTransparency = 1,
				Text = label,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			})
		)
	end
	for i, child in children do
		if typeof(child) == "Instance" and (child :: Instance):IsA("GuiObject") then
			(child :: GuiObject).LayoutOrder = i
		end
		table.insert(items, child)
	end
	return s:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = items,
	})
end

-- Small action button.
function Dev.button(
	s: Scope,
	text: Fusion.UsedAs<string>,
	onClick: () -> (),
	width: number?,
	danger: boolean?
): Instance
	return s:New("TextButton")({
		Size = UDim2.fromOffset(width or 120, Theme.Size.MinTouch),
		AutoButtonColor = true,
		BackgroundColor3 = if danger then Theme.Colors.Danger else Theme.Colors.PanelRaised,
		Text = text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.Parchment,
		TextWrapped = true,
		[OnEvent("Activated")] = function()
			if not Fusion.peek(Dev.Busy) then
				Sounds.play("click")
				onClick()
			end
		end,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIStroke")({ Color = Theme.Colors.Border, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		},
	})
end

-- Plain text box bound to a Value.
function Dev.textBox(s: Scope, value: Fusion.Value<string>, placeholder: string, width: number?): Instance
	return s:New("TextBox")({
		Size = UDim2.fromOffset(width or 160, Theme.Size.MinTouch),
		BackgroundColor3 = Theme.Colors.Background,
		ClearTextOnFocus = false,
		PlaceholderText = placeholder,
		Text = value,
		[Out("Text")] = value,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.Text,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIStroke")({ Color = Theme.Colors.Border, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		},
	})
end

-- Favourites --------------------------------------------------------------------------------------------------

function Dev.pins(): { string }
	local pins = State.Get({ "account", "settings", "devPins" })
	return if type(pins) == "table" then pins else {}
end

function Dev.togglePin(name: string)
	local pins = table.clone(Dev.pins())
	local index = table.find(pins, name)
	if index then
		table.remove(pins, index)
	elseif #pins < 12 then
		table.insert(pins, name)
	end
	Net.Send("SetSetting", "devPins", pins)
end

-- Opens the console with a command typed in (pinned commands that need arguments).
function Dev.prefill(line: string)
	Dev.ConsoleLine:set(line)
	Dev.Tab:set("console")
end

-- Generic rows ------------------------------------------------------------------------------------------------

-- One row per command of the categories: "/name", a control per argument (number field, choice or text) and
-- run / pin buttons.
function Dev.commandRows(s: Scope, startOrder: number, categories: { string }): { Instance }
	local out = {}
	local pinsValue = State.Value({ "account", "settings", "devPins" })
	for _, category in categories do
		for _, def in AdminCommands.inCategory(category :: any) do
			local getters: { () -> string } = {}
			local controls: { any } = {}
			for _, arg in def.args do
				if arg.kind == "enum" then
					local options = {}
					if arg.optional and not arg.default then
						table.insert(options, { value = "", label = `{arg.name}: —` })
					end
					for _, option in (arg.options or {}) :: { string } do
						table.insert(options, { value = option, label = `{arg.name}: {option}` })
					end
					local selected =
						s:Value((arg.default or (if arg.optional then "" else (arg.options or {})[1])) :: string?)
					table.insert(
						controls,
						Select(s, { Options = options, Selected = selected, Width = 150, ListHeight = 160 })
					)
					table.insert(getters, function()
						return Fusion.peek(selected) or ""
					end)
				elseif (arg.kind == "integer" or arg.kind == "number") and not arg.optional and arg.default == nil then
					local value = s:Value(math.clamp(0, arg.min or 0, arg.max or 0))
					if arg.min and arg.min > 0 then
						value:set(arg.min)
					end
					table.insert(
						controls,
						NumberInput(s, {
							Value = value,
							Min = arg.min,
							Max = arg.max,
							Integer = arg.kind == "integer",
							Size = UDim2.fromOffset(150, Theme.Size.MinTouch),
						})
					)
					table.insert(getters, function()
						return tostring(Fusion.peek(value))
					end)
				else
					local value = s:Value(arg.default or "")
					local hint = if arg.optional then `[{arg.name}]` else arg.name
					table.insert(controls, Dev.textBox(s, value, hint, 130))
					table.insert(getters, function()
						return Fusion.peek(value)
					end)
				end
			end
			local function collect(): { string }
				local args = {}
				for i, get in getters do
					args[i] = get()
				end
				while #args > 0 and args[#args] == "" do
					table.remove(args)
				end
				return args
			end
			local children: { any } = {}
			for _, control in controls do
				table.insert(children, control)
			end
			table.insert(
				children,
				Dev.button(s, "▶", function()
					Dev.run(def.name, collect())
				end, 50, def.danger)
			)
			table.insert(
				children,
				s:New("TextButton")({
					Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
					BackgroundTransparency = 1,
					Text = s:Computed(function(use): string
						local pins = use(pinsValue)
						return if type(pins) == "table" and table.find(pins, def.name) then "★" else "☆"
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 22,
					TextColor3 = Theme.Colors.GoldBright,
					[OnEvent("Activated")] = function()
						Dev.togglePin(def.name)
					end,
				})
			)
			local row = Dev.row(s, startOrder + #out, `/{def.name}`, children)
			-- Usage text under the row.
			table.insert(out, row)
			table.insert(
				out,
				s:New("TextLabel")({
					LayoutOrder = startOrder + #out,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = Text.T(s, def.usageKey),
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = 13,
					TextColor3 = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
	end
	return out
end

return Dev
