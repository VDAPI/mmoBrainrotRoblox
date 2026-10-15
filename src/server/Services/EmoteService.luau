--!strict
-- Emotes (S123, DESIGN-17 §4): the server checks and announces, every client plays. PlayEmote (the emote wheel) and
-- the chat command "/e <alias>" ("/emote" too; aliases in Data/Emotes, Polish and English) go through
-- Logic/CosmeticRules.canEmote: owned (free ones always), alive, out of combat, not riding, no skill channel or cast,
-- Data/Emotes.COOLDOWN seconds since the last one. A started emote is the character model's attribute
-- Emote = "<emoteId>:<n>" (n counts up, so the same emote plays again); it replicates to every client, which plays
-- the motion (EmoteController, AnimationController.Emote); there is no server -> client remote. The attribute clears
-- on death, damage, mounting and a new model. Roblox's own avatar emote command (RBXEmoteCommand) is switched off.
-- Casting: the skill channel / cast time published by SkillService as the state branch { "skills", "channel" };
-- instant skills interrupt the emote on the clients (AnimationController.Skill replaces it).
-- MountService is taken lazily (S96: it depends on ResourceService and more; never needed during Init).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared

local CosmeticRules = require(Shared.Logic.CosmeticRules)
local Cosmetics = require(Shared.Data.Cosmetics)
local Emotes = require(Shared.Data.Emotes)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)

local log = Log.new("EmoteService")

local EmoteService = {
	Name = "EmoteService",
	Deps = { "DataService", "PlayerStateService", "CharacterService", "ResourceService" },
}

local ATTRIBUTE = "Emote"

local DataService: any
local PlayerStateService: any
local CharacterService: any
local ResourceService: any
local Registry: any
local MountService: any

local last: { [Player]: number } = {}
local counter: { [Player]: number } = {}
local watch: { [Player]: RBXScriptConnection } = {}

local function mountService(): any
	MountService = MountService or Registry.Get("MountService")
	return MountService
end

-- Clears the emote of the player's model (nothing plays any more).
function EmoteService.Stop(player: Player)
	local model = player.Character
	if model and model:GetAttribute(ATTRIBUTE) ~= nil then
		model:SetAttribute(ATTRIBUTE, nil)
	end
end

local function casting(player: Player): boolean
	return PlayerStateService.Get(player, { "skills", "channel" }) ~= nil
end

-- PlayEmote: (cosmetic id) -> ok, error key.
local function play(player: Player, cosmeticId: string): (boolean, string?)
	local def = Cosmetics.get(cosmeticId)
	local emote = if def and def.kind == "emote" and def.emote then Emotes.get(def.emote) else nil
	local model = player.Character
	local data = DataService.GetData(player)
	if not def or not emote then
		return false, "emote.error.unknown"
	end
	if not model or not data or not PlayerStateService.GetCharacter(player) then
		return false, "emote.error.dead"
	end
	local now = os.clock()
	local ok, err = CosmeticRules.canEmote({
		owned = CosmeticRules.owns(def, data),
		dead = ResourceService.IsDead(player),
		combat = ResourceService.InCombat(player),
		riding = mountService().IsRiding(player) or model:GetAttribute("Mount") ~= nil,
		casting = casting(player),
		last = last[player] or 0,
		now = now,
	})
	if not ok then
		return false, err
	end
	local n = (counter[player] or 0) + 1
	counter[player] = n
	last[player] = now
	model:SetAttribute(ATTRIBUTE, `{emote.id}:{n}`)
	return true, nil
end

-- "/e" without an alias: the aliases of the owned emotes.
local function help(player: Player)
	local data = DataService.GetData(player)
	local names: { string } = {}
	for _, id in CosmeticRules.ownedEmotes(data) do
		local def = Cosmetics.get(id)
		local emote = def and def.emote and Emotes.get(def.emote)
		if emote then
			table.insert(names, table.concat(emote.aliases, "/"))
		end
	end
	Net.Fire(player, "Toast", "emote.help", { list = table.concat(names, ", ") }, "info")
end

local function onCommand(textSource: TextSource, message: string)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player then
		return
	end
	local words = string.split(message, " ")
	local alias: string? = nil
	for i = 2, #words do
		if words[i] ~= "" then
			alias = words[i]
			break
		end
	end
	if alias == nil then
		help(player)
		return
	end
	local id, err = CosmeticRules.emoteByAlias(alias, DataService.GetData(player))
	if not id then
		Net.Fire(player, "Toast", err or "emote.error.unknown", nil, "error")
		return
	end
	local ok, playErr = play(player, id)
	if not ok then
		Net.Fire(player, "Toast", playErr or "error.internal", nil, "error")
	end
end

-- Roblox's default /e (avatar animations) would answer the same command: switched off when it exists. The default
-- commands live under TextChatService.TextChatCommands (create.roblox.com, "In-experience text chat": the
-- RBXEmoteCommand has the aliases /e and /emote); an older or changed layout only logs a warning.
local function disableDefault()
	local ok, err = pcall(function()
		local folder = TextChatService:FindFirstChild("TextChatCommands")
		local default = folder and folder:FindFirstChild("RBXEmoteCommand")
		if default and default:IsA("TextChatCommand") then
			default.Enabled = false
		else
			log:warn("RBXEmoteCommand not found; the default /e may answer too")
		end
	end)
	if not ok then
		log:warn("could not switch off RBXEmoteCommand: %s", tostring(err))
	end
end

local function onModel(player: Player, model: Model)
	model:SetAttribute(ATTRIBUTE, nil)
	local old = watch[player]
	if old then
		old:Disconnect()
	end
	-- mounting ends the gesture (the rider pose takes over)
	watch[player] = model:GetAttributeChangedSignal("Mount"):Connect(function()
		if model:GetAttribute("Mount") ~= nil and model:GetAttribute(ATTRIBUTE) ~= nil then
			model:SetAttribute(ATTRIBUTE, nil)
		end
	end)
end

function EmoteService.Init(registry)
	Registry = registry
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ResourceService = registry.Get("ResourceService")
end

function EmoteService.Start()
	Net.Handle("PlayEmote", play)
	CharacterService.ModelSpawned:Connect(onModel)
	ResourceService.Died:Connect(EmoteService.Stop)
	ResourceService.Damaged:Connect(EmoteService.Stop)

	local command = Instance.new("TextChatCommand")
	command.Name = "VaelthornEmote"
	command.PrimaryAlias = "/e"
	command.SecondaryAlias = "/emote"
	command.Triggered:Connect(onCommand)
	-- defer: the default commands are created by TextChatService itself
	task.defer(disableDefault)
	command.Parent = TextChatService

	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
		counter[player] = nil
		local old = watch[player]
		watch[player] = nil
		if old then
			old:Disconnect()
		end
	end)
end

return EmoteService
