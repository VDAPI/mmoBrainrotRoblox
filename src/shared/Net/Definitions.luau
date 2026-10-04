--!strict
-- Every remote in the game. Add new remotes here only; Net creates the instances on the server.
--
-- kind: "event" (RemoteEvent) | "function" (RemoteFunction, client -> server only)
-- dir:  "c2s" client -> server, "s2c" server -> client, "both"
-- rate: allowed calls per second per player (c2s only; burst = 2x rate)
-- args: argument spec checked by Net before the handler runs (c2s only), see Net.Check

export type Definition = {
	kind: "event" | "function",
	dir: "c2s" | "s2c" | "both",
	rate: number?,
	args: { string }?,
}

local Definitions: { [string]: Definition } = {
	-- State replication (server -> owner)
	StateSnapshot = { kind = "event", dir = "s2c" },
	StateDiff = { kind = "event", dir = "s2c" },
	RequestSnapshot = { kind = "event", dir = "c2s", rate = 0.5, args = {} },

	-- Notifications
	Toast = { kind = "event", dir = "s2c" }, -- (key, args?, kind?)
	SystemMessage = { kind = "event", dir = "s2c" }, -- (key, args?) shown in the chat system channel

	-- Character selection
	CheckName = { kind = "function", dir = "c2s", rate = 2, args = { "string" } },
	CreateCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = { "integer", "string", "string" } },
	DeleteCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = { "integer", "string" } },
	PlayCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = { "integer" } },
	SwitchCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = {} },

	-- Settings
	SetLanguage = { kind = "event", dir = "c2s", rate = 1, args = { "string" } },
	SetSetting = { kind = "event", dir = "c2s", rate = 2, args = { "string", "any" } }, -- (name, value), whitelisted

	-- Stats and progression
	AllocateStats = { kind = "function", dir = "c2s", rate = 2, args = { "table" } }, -- ({ str, dex, int, vit })
	LevelUp = { kind = "event", dir = "s2c" }, -- (player, newLevel, statPoints, skillPoints) to nearby players

	-- Combat
	SetTarget = { kind = "event", dir = "c2s", rate = 8, args = { "string?" } }, -- entityId or nil to clear
	CombatFx = { kind = "event", dir = "s2c" }, -- batched { k = "dmg" | "heal" | "atk" | "tele" | "reward", ... }

	-- Items (S04). Functions answer (ok, errorKey?).
	MoveItem = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "integer" } }, -- (from, to)
	SplitStack = { kind = "function", dir = "c2s", rate = 4, args = { "integer", "integer" } }, -- (from, amount)
	SortInventory = { kind = "function", dir = "c2s", rate = 1, args = {} },
	DestroyItem = { kind = "function", dir = "c2s", rate = 4, args = { "integer" } },
	UseItem = { kind = "function", dir = "c2s", rate = 6, args = { "integer" } },
	EquipItem = { kind = "function", dir = "c2s", rate = 6, args = { "integer", "string?" } }, -- (index, slot?)
	UnequipItem = { kind = "function", dir = "c2s", rate = 6, args = { "string", "integer?" } }, -- (slot, index?)
	SetPotionSlot = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string?" } }, -- (hp|mana|energy, itemId?)
	UsePotion = { kind = "function", dir = "c2s", rate = 6, args = { "string" } },
	PickupLoot = { kind = "function", dir = "c2s", rate = 10, args = { "string" } },
	LootSpawn = { kind = "event", dir = "s2c" }, -- (bag) only to the owner
	LootUpdate = { kind = "event", dir = "s2c" }, -- (bagId, items)
	LootRemove = { kind = "event", dir = "s2c" }, -- (bagId)
	LootPicked = { kind = "event", dir = "s2c" }, -- (items) what went into the backpack (legendary reveal)
	Announce = { kind = "event", dir = "s2c" }, -- (key, args) banner + system chat for everyone

	-- Skills (S05)
	LearnSkill = { kind = "function", dir = "c2s", rate = 6, args = { "string" } },
	SetHotbar = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "string?" } }, -- (slot 1..10, skillId?)
	ResetSkills = { kind = "function", dir = "c2s", rate = 1, args = {} },
	CastSkill = { kind = "function", dir = "c2s", rate = 8, args = { "string", "string?", "any" } }, -- (skillId, targetId?, aim: Vector3?)
	SkillFx = { kind = "event", dir = "s2c" }, -- skill visuals for players nearby

	-- PvP and death
	SetPvp = { kind = "function", dir = "c2s", rate = 1, args = { "boolean" } },
	RespawnNow = { kind = "function", dir = "c2s", rate = 1, args = {} },
}

return table.freeze(Definitions)
