--!strict
-- The hands-on tutorial, client side (S155, docs/DESIGN.md §20 "Samouczek"; rules in Logic/Tutorial). It replaced the
-- S14 HUD guide (GuideController and its nine bubbles): one hint of the current step at a time (UI/Screens/Hud/
-- TutorialHint on the HUD layer, iron with a brass edge), placed next to the real HUD element of the step
-- (UI/HudAnchors; the thumbstick zone on a phone) with a pulsing outline over it, re-placed every TICK so a resize or a
-- rotation moves it with the HUD. Texts name the player's own keys on PC (Tutorial.keyArgs) and buttons on a phone.
-- It reports only the client steps (Tutorial.clientAllowed): "move" once the player walked Data/Tutorial.MOVE_STUDS
-- steering (Tutorial.walk: the spawn pivot and teleports never count), "backpack" when the backpack window opens; the
-- server counts the rest itself. The hint hides while a modal, a cutscene (the HUD layer is hidden), death or a dialog
-- window (NPC, quest, login reward, "What has changed") is up or the login reward / the letter still waits to open on
-- its own (their Pending), so on the first entry the login reward and the letter come first. The "quest" step guides the path
-- to the captain once (NavController.GuideToNpc) while no story quest is taken. W28: while the hint shows, every step
-- with a world target (Logic/Tutorial.guide) drives the golden world guide (GuidePointerController: an arrow over the
-- head, chevrons on the ground, a diamond over the target, an arrow at the screen's edge): the captain, in the city the
-- story quest's way to the Meadows, there the player's target or the nearest monster. The texts saying "follow the
-- golden arrow" mean that guide (the owner saw no arrow before: the only one was the tracker's small glyph). When the
-- server finishes the tutorial the closing hint stays Data/Tutorial.DONE_SECONDS (a touch closes it), and when the
-- level reward arrives a toast lists it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Device = require(script.Parent.Parent.UI.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudAnchors = require(script.Parent.Parent.UI.HudAnchors)
local GuidePointer = require(script.Parent.GuidePointerController)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestTrack = require(script.Parent.Parent.UI.QuestTrack)
local Scale = require(script.Parent.Parent.UI.Scale)
local ServerModeView = require(script.Parent.Parent.UI.ServerModeView)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Tutorial = require(ReplicatedStorage.Shared.Logic.Tutorial)
local TutorialData = require(ReplicatedStorage.Shared.Data.Tutorial)
local TutorialHint = require(script.Parent.Parent.UI.Screens.Hud.TutorialHint)

local TutorialController = {
	Name = "TutorialController",
	Deps = {
		"UIController",
		"WindowManager",
		"NavController",
		"CutsceneController",
		"LoginRewardController",
		"ReturningController",
		"GuidePointerController",
		"TargetController",
	},
}

local UIController: any
local WindowManager: any
local NavController: any
local CutsceneController: any
local LoginRewardController: any
local ReturningController: any
local GuidePointerController: any
local TargetController: any

local TICK = 0.2 -- seconds between two placements of the hint
local RESEND = 3 -- seconds before a client step is reported again (the state did not count it yet)
local MARGIN = 16 -- virtual px from the layer's edge
local GAP = 10 -- virtual px between the element and the arrow
local ARROW = 24 -- virtual px the arrow takes between the tile and the element
local WIDTH_PC = 440
local WIDTH_TOUCH = 360
local TOUCH_CLUSTER = 150 -- virtual px kept free left of the phone's attack and skill buttons
-- Windows that are a conversation or a letter: the hint waits until they close.
local BLOCKING = { "npc", "questnpc", "login", "whatsnew" }

local scope = Fusion.scoped(Fusion)
local phase = State.Value({ "session", "phase" })
local zoneMap = State.Value({ "zone", "map" })

local view = scope:Value(nil :: TutorialHint.View?)
local visible = scope:Value(false)
local position = scope:Value(UDim2.new())
local arrow = scope:Value(nil :: TutorialHint.Arrow?)
local outline = scope:Value(nil :: HudAnchors.Rect?)
local width = scope:Computed(function(use): number
	return if use(Device.Touch) then WIDTH_TOUCH else WIDTH_PC
end)

local root: Frame
local hint: TutorialHint.Api

local current: Tutorial.State? = nil -- the state of the character in the world now
local currentId: string? = nil -- its character id (a character switch is no transition)
local finaleUntil = 0 -- os.clock() until which the closing hint shows
local skipSent = false -- hides the hint between TutorialSkip and the server's answer
local sentAt: { [string]: number } = {} -- client step -> os.clock() of the last report
local lastAt: Vector3? = nil -- the root's position at the last sample
local lastModel: Model? = nil
local walked = 0 -- studs the player walked steering (Tutorial.walk)
local guided = false -- the path went to the captain once this session
local hunted: Model? = nil -- the monster the world guide points at in the "attack" step (kept while alive and near)
local HUNT_RANGE = 220 -- studs within which the "attack" step points at a monster

local function counted(state: Tutorial.State, id: string): boolean
	local index = Tutorial.indexOf[id]
	return state.done or state.step > index or (state.pending ~= nil and state.pending[id] == true)
end

local function report(id: string)
	local last = sentAt[id]
	if last and os.clock() - last < RESEND then
		return
	end
	sentAt[id] = os.clock()
	Net.Send("TutorialEvent", id)
end

local function rewardToast()
	local parts: { string } = {}
	local title = Cosmetics.get(TutorialData.REWARD.title)
	if title then
		table.insert(parts, Text.now(title.nameKey))
	end
	for _, entry in TutorialData.REWARD.items do
		table.insert(parts, `{entry.n}× {ItemText.name(entry.id)}`)
	end
	Toast.push(Text.now("tutorial.reward", { items = table.concat(parts, ", ") }), "success", 8)
end

local function onState()
	local raw = State.Get({ "character", "tutorial" })
	local id = State.Get({ "character", "id" })
	if raw == nil then
		current, currentId = nil, nil
		return
	end
	local state = Tutorial.sanitize(raw)
	local before = if id == currentId then current else nil
	current, currentId = state, id
	skipSent = false
	if before and Fusion.peek(phase) == "playing" then
		if not before.done and Tutorial.finale(state) then
			finaleUntil = os.clock() + TutorialData.DONE_SECONDS
		end
		if not before.reward and state.reward then
			rewardToast()
		end
	end
end

-- Whether something the hint must not cover is up now.
local function blocked(): boolean
	if WindowManager.HasModal() or CutsceneController.IsPlaying() or State.Get({ "death" }) ~= nil then
		return true
	end
	if LoginRewardController.Pending() or ReturningController.Pending() then
		return true -- the login reward or the letter opens on its own soon: they come first
	end
	for _, id in BLOCKING do
		if Fusion.peek(WindowManager.IsOpen(id)) then
			return true
		end
	end
	return false
end

-- The client steps: walking (only while the player steers, never the spawn pivot), the backpack window.
local function watchClientSteps(state: Tutorial.State)
	if not counted(state, "move") then
		local model = Players.LocalPlayer.Character
		local part = model and model:FindFirstChild("HumanoidRootPart")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if model and part and part:IsA("BasePart") and humanoid then
			local at = part.Position
			if lastModel ~= model or not lastAt or part.Anchored then
				lastModel = model -- a new model or a root held by the placement: start from here
			else
				local from = lastAt :: Vector3
				local steering = humanoid.MoveDirection.Magnitude > 0
				walked = Tutorial.walk(walked, at.X - from.X, at.Z - from.Z, steering)
				if Tutorial.moved(walked) then
					report("move")
				end
			end
			lastAt = at
		end
	end
	if
		not counted(state, "backpack")
		and (Fusion.peek(WindowManager.IsOpen("inventory")) or Fusion.peek(WindowManager.IsOpen("character")))
	then
		report("backpack")
	end
end

-- The first key label of a step on PC (the plaque), nil without keys.
local function plaque(args: { [string]: string }): string?
	local names: { string } = {}
	for name in args do
		table.insert(names, name)
	end
	table.sort(names)
	return if #names > 0 then args[names[1]] else nil
end

-- Top left corner of the tile and its arrow for an element at `rect` (nil: the default place).
local function place(
	rect: HudAnchors.Rect?,
	w: number,
	h: number,
	bw: number,
	bh: number,
	touch: boolean
): (number, number, TutorialHint.Arrow?)
	local function clampX(x: number): number
		return math.clamp(x, MARGIN, math.max(MARGIN, w - bw - MARGIN))
	end
	local function clampY(y: number): number
		return math.clamp(y, MARGIN, math.max(MARGIN, h - bh - MARGIN))
	end
	if not rect then
		-- PC: over the action bar; phone: in the upper middle, clear of the thumbstick and the attack button
		return clampX((w - bw) / 2), clampY(if touch then h * 0.16 else h - 230 - bh), nil
	end
	local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
	local function left(extra: number): (number?, number?, TutorialHint.Arrow?)
		local x = rect.x - GAP - ARROW - bw - extra
		if x < MARGIN then
			return nil, nil, nil
		end
		local y = clampY(cy - bh / 2)
		local ay = math.clamp(cy, y + 16, y + bh - 16)
		return x, y, { glyph = "▶", position = UDim2.fromOffset(x + bw + ARROW / 2 + 2, ay) }
	end
	if touch and cx > w * 0.6 and cy > h * 0.55 then
		-- the attack and skill buttons of a phone: left of their arc, never over them
		local x, y, a = left(TOUCH_CLUSTER)
		if x and y then
			return x, y, a
		end
	end
	if cy > h * 0.55 then
		local x = clampX(cx - bw / 2)
		local y = clampY(rect.y - GAP - ARROW - bh)
		local ax = math.clamp(cx, x + 16, x + bw - 16)
		return x, y, { glyph = "▼", position = UDim2.fromOffset(ax, y + bh + ARROW / 2 + 2) }
	end
	if cx > w * 0.6 then
		local x, y, a = left(0)
		if x and y then
			return x, y, a
		end
	end
	local x = clampX(cx - bw / 2)
	local y = clampY(rect.y + rect.h + GAP + ARROW)
	local ax = math.clamp(cx, x + 16, x + bw - 16)
	return x, y, { glyph = "▲", position = UDim2.fromOffset(ax, y - ARROW / 2 - 2) }
end

local function sameView(a: TutorialHint.View?, b: TutorialHint.View?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return a.caption == b.caption and a.text == b.text and a.key == b.key and a.finale == b.finale
end

local function sameRect(a: HudAnchors.Rect?, b: HudAnchors.Rect?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
end

local function sameArrow(a: TutorialHint.Arrow?, b: TutorialHint.Arrow?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return a.glyph == b.glyph and a.position == b.position
end

local function hide()
	GuidePointerController.Set("tutorial", nil)
	visible:set(false)
	if Fusion.peek(outline) ~= nil then
		outline:set(nil)
	end
end

local function alive(model: Model?): boolean
	return model ~= nil and model.Parent ~= nil and model:GetAttribute("Dead") ~= true
end

-- The monster the "attack" step points at: the player's own target, else the one already shown while alive and
-- near, else the nearest living monster within HUNT_RANGE.
local function huntTarget(): Model?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local picked = Fusion.peek(TargetController.Target)
	if typeof(picked) == "Instance" and picked:IsA("Model") and picked:GetAttribute("MonsterId") ~= nil then
		if alive(picked) then
			return picked
		end
	end
	local function near(model: Model): number
		return (model:GetPivot().Position - root.Position).Magnitude
	end
	local kept = hunted
	if kept and alive(kept) and near(kept) <= HUNT_RANGE then
		return kept
	end
	local best: Model? = nil
	local bestDistance = HUNT_RANGE
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		for _, child in monsters:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("MonsterId") ~= nil and alive(child) then
				local d = near(child)
				if d < bestDistance then
					best, bestDistance = child, d
				end
			end
		end
	end
	hunted = best
	return best
end

-- The world guide of a step (Logic/Tutorial.guide) as a GuidePointer spec, nil = none.
local function guideSpec(step: Tutorial.Step, away: boolean): GuidePointer.Spec?
	local quests = State.Get({ "character", "quests" })
	local mainTaken = type(quests) == "table" and quests.main ~= nil
	local guide = Tutorial.guide(step, away, mainTaken)
	if not guide then
		return nil
	end
	if guide.kind == "npc" and guide.id then
		local def = Npcs.get(guide.id)
		return if def then { map = def.map, npc = def.id } else nil
	end
	if guide.kind == "monster" then
		local model = huntTarget()
		if model then
			return { model = model }
		end
	end
	local target = Fusion.peek(QuestTrack.Target)
	if target then
		return { map = target.map, x = target.x, z = target.z, npc = target.npc }
	end
	-- no quest target: the first hunting ground of the Meadows (the travel step's own guide)
	return if away then { map = "meadows", x = -672, z = 0 } else nil
end

local function tick()
	local state = current
	if not state or Fusion.peek(phase) ~= "playing" or not ServerModeView.isWorld() then
		hide()
		return
	end
	watchClientSteps(state)
	local step = Tutorial.current(state)
	local finale = false
	if not step and finaleUntil > os.clock() then
		step = Tutorial.finale(state)
		finale = step ~= nil
	end
	if not step or skipSent then
		hide()
		return
	end
	if step.id == "quest" and not guided then
		guided = true
		local quests = State.Get({ "character", "quests" })
		if type(quests) == "table" and quests.main == nil and (tonumber(quests.mainDone) or 0) == 0 then
			NavController.GuideToNpc("captain")
		end
	end
	if blocked() then
		hide()
		return
	end

	local touch = Fusion.peek(Device.Touch) == true
	local away = step.travel == true and Fusion.peek(zoneMap) == Config.StartingMap
	local binds = State.Get({ "account", "settings", "keys" })
	local args = if touch then {} else Tutorial.keyArgs(step, if type(binds) == "table" then binds else nil)
	local index = Tutorial.indexOf[step.id]
	local title = Text.now("tutorial.title")
	local nextView: TutorialHint.View = {
		caption = if finale
			then title
			else Text.now("tutorial.caption", { title = title, n = index, total = Tutorial.ACTIONS }),
		text = Text.now(Tutorial.text(step, touch, away), args),
		key = if touch or away then nil else plaque(args),
		finale = finale,
	}
	if not sameView(Fusion.peek(view), nextView) then
		view:set(nextView)
	end

	local factor = Scale.get()
	local size = root.AbsoluteSize / factor
	local bw = Fusion.peek(width)
	local bh = math.max(hint.box.AbsoluteSize.Y / factor, 120)
	local rect = if finale then nil else HudAnchors.find(root, Tutorial.anchorOf(step, away), touch, factor)
	local x, y, a = place(rect, size.X, size.Y, bw, bh, touch)
	local at = UDim2.fromOffset(math.floor(x), math.floor(y))
	if Fusion.peek(position) ~= at then
		position:set(at)
	end
	if not sameArrow(Fusion.peek(arrow), a) then
		arrow:set(a)
	end
	if not sameRect(Fusion.peek(outline), rect) then
		outline:set(rect)
	end
	GuidePointerController.Set("tutorial", if finale then nil else guideSpec(step, away))
	visible:set(true)
end

function TutorialController.Init(registry)
	UIController = registry.Get("UIController")
	WindowManager = registry.Get("WindowManager")
	NavController = registry.Get("NavController")
	CutsceneController = registry.Get("CutsceneController")
	LoginRewardController = registry.Get("LoginRewardController")
	ReturningController = registry.Get("ReturningController")
	GuidePointerController = registry.Get("GuidePointerController")
	TargetController = registry.Get("TargetController")
	root = UIController.GetLayer("Screens")
	hint = TutorialHint(scope, {
		View = view,
		Visible = visible,
		Position = position,
		Width = width,
		Arrow = arrow,
		Outline = outline,
		OnSkip = function()
			skipSent = true
			hide()
			Net.Send("TutorialSkip")
		end,
		OnClose = function()
			finaleUntil = 0
			hide()
		end,
	})
	hint.frame.Parent = root
end

function TutorialController.Start()
	scope:Observer(State.Value({ "character", "tutorial" })):onBind(onState)
	scope:Observer(phase):onBind(function()
		if Fusion.peek(phase) ~= "playing" then
			finaleUntil = 0
			guided = false
			lastAt, lastModel, walked = nil, nil, 0
			table.clear(sentAt)
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= TICK then
			acc = 0
			tick()
		end
	end)
end

return TutorialController
