--!strict
-- Emotes (S123, DESIGN-17 §4), client side. Every client watches the attribute Emote = "<emoteId>:<n>" on the models
-- of all players (EmoteService sets it) and plays the motion (AnimationController.Emote); a cleared attribute stops it.
-- A looping emote ends when its character moves or jumps (the root's horizontal speed, the same on every client);
-- a new value of the attribute plays again even for the same emote (the counter n); a value present when a model is
-- first seen plays nothing (it may be long over). The emote wheel
-- (UI/Screens/EmoteWheel) opens with the key of Data/Keybinds "emote_wheel" (T) and the HUD button (Toggle); a
-- choice asks the server (PlayEmote) and closes the wheel. The wheel dims everything while the character is dead,
-- riding or casting (combat and the cooldown only the server knows: its answer is a toast).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Emotes = require(ReplicatedStorage.Shared.Data.Emotes)
local EmoteWheel = require(script.Parent.Parent.UI.Screens.EmoteWheel)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local EmoteController = {
	Name = "EmoteController",
	Deps = { "UIController", "AnimationController" },
}

local ATTRIBUTE = "Emote"
local MOVE_SPEED = 2 -- studs/s of the root, horizontally: the character walks
local CHECK_EVERY = 0.1

local UIController: any
local AnimationController: any

local scope = Fusion.scoped(Fusion)
local wheelScope: Fusion.Scope<typeof(Fusion)>? = nil
local playing: { [Model]: boolean } = {}
local watched: { [Model]: RBXScriptConnection } = {}

local hp = State.Value({ "character", "hp" })
local channel = State.Value({ "skills", "channel" })
local mountTick = scope:Value(0) -- bumped when the own model's Mount attribute changes

-- Why an emote cannot start now on this client (nil = it may; the server decides the rest).
local blocked = scope:Computed(function(use): string?
	use(mountTick)
	local value = use(hp)
	if type(value) == "number" and value <= 0 then
		return "emote.error.dead"
	end
	local model = Players.LocalPlayer.Character
	if model and model:GetAttribute("Mount") ~= nil then
		return "emote.error.riding"
	end
	if use(channel) ~= nil then
		return "emote.error.casting"
	end
	return nil
end)

local function emoteOf(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local id = string.match(value, "^([%w_]+):%d+$")
	return if id and Emotes.get(id) then id else nil
end

local function onAttribute(model: Model)
	local id = emoteOf(model:GetAttribute(ATTRIBUTE))
	if id then
		if AnimationController.Emote(model, id) then
			playing[model] = true
		end
	elseif playing[model] then
		playing[model] = nil
		AnimationController.StopEmote(model)
	end
end

local function watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = model:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		onAttribute(model)
	end)
	model.Destroying:Connect(function()
		local connection = watched[model]
		watched[model] = nil
		playing[model] = nil
		if connection then
			connection:Disconnect()
		end
	end)
	if Players.LocalPlayer.Character == model then
		model:GetAttributeChangedSignal("Mount"):Connect(function()
			mountTick:set(Fusion.peek(mountTick) + 1)
		end)
	end
	-- A value already there on first sight is not played: the server leaves it set after the emote ends (a finished
	-- gesture, a loop its player walked out of), so a newcomer or a model streamed in would replay a stale one.
end

local function onPlayer(player: Player)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

-- A looping emote ends when its character walks away; a finished one is forgotten.
local function checkMoving()
	for model in playing do
		if not AnimationController.IsEmoting(model) then
			playing[model] = nil
			continue
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local v = root.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > MOVE_SPEED or math.abs(v.Y) > 8 then
				playing[model] = nil
				AnimationController.EndEmote(model)
			end
		end
	end
end

function EmoteController.Close()
	if wheelScope then
		Fusion.doCleanup(wheelScope)
		wheelScope = nil
	end
end

-- Asks the server to play an emote cosmetic (the wheel and anything else).
function EmoteController.Play(cosmeticId: string)
	EmoteController.Close()
	task.spawn(function()
		local ok, err = Net.Invoke("PlayEmote", cosmeticId)
		if not ok then
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

-- The wardrobe's preview: plays an emote on the own character locally (nobody else sees it; walking ends it).
function EmoteController.Preview(emoteId: string)
	local model = Players.LocalPlayer.Character
	if model and AnimationController.Emote(model, emoteId) then
		playing[model] = true
	end
end

-- Opens the emote wheel, or closes it when open.
function EmoteController.Toggle()
	if wheelScope then
		EmoteController.Close()
		return
	end
	if State.Get({ "session", "phase" }) ~= "playing" then
		return
	end
	local s = UIController.Scope:innerScope()
	wheelScope = s
	EmoteWheel(s, {
		Play = EmoteController.Play,
		Close = EmoteController.Close,
		Blocked = blocked,
	}).Parent =
		UIController.GetLayer("Windows")
end

function EmoteController.Init(registry: any)
	UIController = registry.Get("UIController")
	AnimationController = registry.Get("AnimationController")
end

function EmoteController.Start()
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= CHECK_EVERY then
			elapsed = 0
			checkMoving()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if Keybinds.is(input.KeyCode, "emote_wheel") then
			EmoteController.Toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and wheelScope then
			EmoteController.Close()
		end
	end)
	-- the wheel never outlives the game screen (character select)
	scope:Observer(State.Value({ "session", "phase" })):onChange(function()
		EmoteController.Close()
	end)
end

return EmoteController
