--!strict
-- Reward codes (S17, DESIGN §21 "kody nagród"): typed in the options window, each one once per account.
-- Rewards arrive by mail (so a full backpack loses nothing). Add a code here for an event or a stream;
-- `expires` is a Unix time (os.time()) or nil. Codes are matched case-insensitively.

export type CodeDef = {
	code: string, -- upper case
	gold: number?,
	shards: number?, -- Dragon Currency, kept small: codes must not become pay-to-win
	items: { { id: string, n: number } }?,
	expires: number?,
}

local list: { CodeDef } = {
	{ code = "VAELTHORN", gold = 500, items = { { id = "potion_hp_1", n = 10 }, { id = "potion_mana_1", n = 5 } } },
	{ code = "WITAJ", gold = 300, items = { { id = "potion_hp_1", n = 5 } } },
	{ code = "WELCOME", gold = 300, items = { { id = "potion_hp_1", n = 5 } } },
}

local byCode: { [string]: CodeDef } = {}
for _, def in list do
	byCode[def.code] = def
end

return table.freeze({
	list = list,
	get = function(code: string): CodeDef?
		return byCode[code]
	end,
})
