--!strict
-- Experience and levels (DESIGN §4.6). GiveExp is the single entry point for every EXP source
-- (monsters S03, quests S11); it applies the character's EXP bonus and handles level-ups:
-- stat points (skill ranks come from the level, S56; path points are not stored, S57), full resources, the LevelUp
-- effect for nearby players. Stat points go to both build sets (S58, ROZWOJ 2.9); SetLevel down fits both sets to the
-- level, ResetStats (Scroll of Oblivion, /stats reset) touches only the active one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Config = require(Shared.Config)
local Exp = require(Shared.Logic.Exp)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Paths = require(Shared.Logic.Paths)
local Signal = require(ReplicatedStorage.Packages.Signal)
local StatPlan = require(Shared.Logic.StatPlan)
local Types = require(Shared.Types)

local log = Log.new("LevelService")

local LevelService = {
	Name = "LevelService",
	Deps = { "PlayerStateService", "StatService", "ResourceService" },
	-- (player, newLevel, levelsGained)
	LeveledUp = Signal.new(),
	LevelChanged = Signal.new(), -- (player, newLevel, oldLevel) S56: every level change, also SetLevel down
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
	local statPts = Exp.pointsForLevels(from, to)
	PlayerStateService.Set(player, { "character", "level" }, to)
	PlayerStateService.Set(player, { "character", "statPoints" }, character.statPoints + statPts)
	-- S58: the inactive build set gets the same stat points (ROZWOJ 2.9).
	local other: any = character.buildOther
	if type(other) == "table" and type(other.statPoints) == "number" then
		PlayerStateService.Set(player, { "character", "buildOther", "statPoints" }, other.statPoints + statPts)
	end
	setLevelAttribute(player, to)
	StatService.Recompute(player)
	ResourceService.Restore(player)
	local pathPts = Paths.pointsAt(to) - Paths.pointsAt(from)
	Net.FireList(nearbyPlayers(player), "LevelUp", player, to, statPts, pathPts, from)
	-- S124: leaderboard tie-break and Hall of Fame (DESIGN-17 §5); set before LevelChanged so LeaderboardService sees it.
	-- SetLevel up comes here too; going down keeps the field (the first moment stays).
	if to >= Config.MaxLevel and from < Config.MaxLevel and character.reached100At == nil then
		PlayerStateService.Set(player, { "character", "reached100At" }, os.time())
	end
	LevelService.LevelChanged:Fire(player, to, from)
	LevelService.LeveledUp:Fire(player, to, to - from)
	Analytics.progression(player, "Level", to, `level_{to}`) -- an empty level name is rejected by AnalyticsService
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

-- Resets allocated stats of the active build set to the class start and refunds every point (Scroll of Oblivion,
-- /stats reset).
function LevelService.ResetStats(player: Player)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return
	end
	PlayerStateService.Set(player, { "character", "stats" }, StatPlan.startOf(character.class))
	PlayerStateService.Set(player, { "character", "statPoints" }, StatPlan.total(character.level))
	StatService.Recompute(player)
end

-- Admin: sets the level directly, recalculating free points. Lowering fits both build sets to the new level: path ranks
-- go back (Logic/Paths), stats reset when more is spent than the level grants (StatPlan.refit).
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
	-- down: both build sets are clamped to the new level (ROZWOJ 2.9); the active bar follows on LevelChanged
	PlayerStateService.Set(player, { "character", "path" }, Paths.clampToLevel(character, target))
	PlayerStateService.Set(player, { "character", "level" }, target)
	setLevelAttribute(player, target)
	local stats, points = StatPlan.refit(character.class, target, character.stats :: any)
	PlayerStateService.Set(player, { "character", "stats" }, stats)
	PlayerStateService.Set(player, { "character", "statPoints" }, points)
	if type(character.buildOther) == "table" then
		local other = Paths.cleanSet(character, character.buildOther, target)
		other.stats, other.statPoints = StatPlan.refit(character.class, target, other.stats :: any)
		PlayerStateService.Set(player, { "character", "buildOther" }, other)
	end
	StatService.Recompute(player)
	ResourceService.Restore(player)
	if target ~= from then
		LevelService.LevelChanged:Fire(player, target, from)
	end
end

function LevelService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	StatService = registry.Get("StatService")
	ResourceService = registry.Get("ResourceService")
end

return LevelService
