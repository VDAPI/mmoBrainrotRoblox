--!strict
-- Experience and levels (DESIGN §4.6). GiveExp is the single entry point for every EXP source
-- (monsters S03, quests S11); it applies the character's EXP bonus and handles level-ups:
-- stat/skill points, full resources, the LevelUp effect for nearby players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Classes = require(Shared.Data.Classes)
local Config = require(Shared.Config)
local Exp = require(Shared.Logic.Exp)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("LevelService")

local LevelService = {
	Name = "LevelService",
	Deps = { "PlayerStateService", "StatService", "ResourceService" },
	-- (player, newLevel, levelsGained)
	LeveledUp = Signal.new(),
}

local PlayerStateService: any
local StatService: any
local ResourceService: any

local function nearbyPlayers(player: Player): { Player }
	local list = { player }
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return list
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= Config.EffectRadius then
				table.insert(list, other)
			end
		end
	end
	return list
end

local function setLevelAttribute(player: Player, level: number)
	local model = player.Character
	if model then
		model:SetAttribute("Level", level)
	end
end

local function onLevelsGained(player: Player, character: Types.CharacterData, from: number, to: number)
	local statPts, skillPts = Exp.pointsForLevels(from, to)
	PlayerStateService.Set(player, { "character", "level" }, to)
	PlayerStateService.Set(player, { "character", "statPoints" }, character.statPoints + statPts)
	PlayerStateService.Set(player, { "character", "skillPoints" }, character.skillPoints + skillPts)
	setLevelAttribute(player, to)
	StatService.Recompute(player)
	ResourceService.Restore(player)
	Net.FireList(nearbyPlayers(player), "LevelUp", player, to, statPts, skillPts)
	LevelService.LeveledUp:Fire(player, to, to - from)
	log:info("%s reached level %d", player.Name, to)
end

-- Grants EXP (before the character's EXP bonus). Returns levels gained.
function LevelService.GiveExp(player: Player, amount: number, _source: string?): number
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character or amount <= 0 or amount ~= amount then
		return 0
	end
	local bonus = StatService.GetValue(player, "expBonus")
	local gained = math.floor(amount * (1 + bonus / 100))
	local from = character.level
	local level, exp, levels = Exp.applyExp(from, character.exp, gained, Config.MaxLevel)
	PlayerStateService.Set(player, { "character", "exp" }, exp)
	if levels > 0 then
		onLevelsGained(player, character, from, level)
	end
	return levels
end

-- Points a character should have in total at its level (class start stats are free).
local function totalPoints(level: number): (number, number)
	return Exp.pointsForLevels(1, level)
end

local function spentStatPoints(character: Types.CharacterData): number
	local class = Classes.get(character.class)
	if not class then
		return 0
	end
	local spent = 0
	for id, value in character.stats :: any do
		spent += value - ((class.startStats :: any)[id] or 0)
	end
	return spent
end

local function spentSkillPoints(character: Types.CharacterData): number
	local spent = 0
	for _, level in character.skills do
		spent += level
	end
	return spent
end

-- Resets allocated stats to the class start and refunds every point (Scroll of Oblivion, /stats reset).
function LevelService.ResetStats(player: Player)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local class = character and Classes.get(character.class)
	if not character or not class then
		return
	end
	local statTotal = totalPoints(character.level)
	PlayerStateService.Set(player, { "character", "stats" }, table.clone(class.startStats))
	PlayerStateService.Set(player, { "character", "statPoints" }, statTotal)
	StatService.Recompute(player)
end

-- Admin: sets the level directly, recalculating free points. Lowering below the allocated amount resets stats.
function LevelService.SetLevel(player: Player, level: number)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return
	end
	local target = math.clamp(math.floor(level), 1, Config.MaxLevel)
	local from = character.level
	PlayerStateService.Set(player, { "character", "exp" }, 0)
	if target > from then
		onLevelsGained(player, character, from, target)
		return
	end
	local statTotal, skillTotal = totalPoints(target)
	PlayerStateService.Set(player, { "character", "level" }, target)
	setLevelAttribute(player, target)
	local freeSkill = skillTotal - spentSkillPoints(character)
	PlayerStateService.Set(player, { "character", "skillPoints" }, math.max(0, freeSkill))
	local freeStat = statTotal - spentStatPoints(character)
	if freeStat < 0 then
		LevelService.ResetStats(player)
	else
		PlayerStateService.Set(player, { "character", "statPoints" }, freeStat)
		StatService.Recompute(player)
	end
	ResourceService.Restore(player)
end

function LevelService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	StatService = registry.Get("StatService")
	ResourceService = registry.Get("ResourceService")
end

return LevelService
