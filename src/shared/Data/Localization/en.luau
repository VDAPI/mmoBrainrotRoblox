--!strict
-- English strings. Every key must also exist in pl.luau (checked by tests/locale.spec.luau).
-- Placeholders: {name} is replaced by Locale.T(key, { name = ... }).

return {
	-- Common
	["common.cancel"] = "Cancel",

	-- Classes (DESIGN §4.2)
	["class.Warrior.name"] = "Warrior",
	["class.Warrior.role"] = "Melee · Tank",
	["class.Warrior.desc"] = "A front-line fighter with swords, axes and hammers. Strength drives his blows, Energy fuels his skills.",
	["class.Hunter.name"] = "Hunter",
	["class.Hunter.role"] = "Ranged · Critical hits",
	["class.Hunter.desc"] = "A marksman with bows and crossbows. Dexterity sharpens his aim and turns shots into critical hits.",
	["class.Mage.name"] = "Mage",
	["class.Mage.role"] = "Area damage · Elements",
	["class.Mage.desc"] = "A master of fire, ice and lightning who strikes whole groups. Intellect empowers spells paid with Mana.",
	["class.Cleric.name"] = "Cleric",
	["class.Cleric.role"] = "Healing · Support",
	["class.Cleric.desc"] = "A servant of the light who heals, shields allies and smites foes with holy magic. Intellect and Vitality.",

	-- Maps
	["map.city.name"] = "Vaelthorn",
	["map.unknown"] = "Unknown lands",

	-- Character selection
	["charSelect.subtitle"] = "Choose your character",
	["charSelect.loading"] = "Loading your characters…",
	["charSelect.mockWarning"] = "Test mode: no DataStore access, progress will not be saved after this session.",
	["charSelect.emptySlot"] = "Empty slot",
	["charSelect.createButton"] = "Create character",
	["charSelect.play"] = "Play",
	["charSelect.delete"] = "Delete",
	["charSelect.classLevel"] = "{class} · Level {level}",
	["charSelect.created"] = "{name} has joined the world of Vaelthorn.",
	["charSelect.deleted"] = "{name} has been deleted.",
	["charSelect.create.title"] = "New character · slot {slot}",
	["charSelect.create.chooseClass"] = "Choose a class",
	["charSelect.create.name"] = "Character name",
	["charSelect.create.namePlaceholder"] = "{min}–{max} letters or digits",
	["charSelect.create.checking"] = "Checking availability…",
	["charSelect.create.available"] = "Name available",
	["charSelect.create.submit"] = "Create",
	["charSelect.create.back"] = "Back",
	["charSelect.deleteModal.title"] = "Delete character",
	["charSelect.deleteModal.message"] = "This cannot be undone. Type <b>{name}</b> to confirm.",
	["charSelect.deleteModal.confirm"] = "Delete forever",

	-- HUD
	["hud.level"] = "Lv {level}",
	["hud.hp"] = "HP",
	["hud.mana"] = "Mana",
	["hud.energy"] = "Energy",
	["hud.menu.character"] = "Character (C)",
	["hud.menu.inventory"] = "Backpack (B)",
	["hud.menu.skills"] = "Skills (K)",
	["hud.menu.map"] = "World map (M)",
	["hud.menu.quests"] = "Quests (L)",
	["hud.menu.guild"] = "Guild (G)",
	["hud.menu.party"] = "Party (P)",
	["hud.menu.menu"] = "Menu (Esc)",

	-- Windows
	["window.soon"] = "Coming soon",
	["window.menu.title"] = "Menu",
	["window.character.title"] = "Character",
	["window.inventory.title"] = "Backpack",
	["window.skills.title"] = "Skills",
	["window.map.title"] = "World map",
	["window.quests.title"] = "Quests",
	["window.guild.title"] = "Guild",
	["window.party.title"] = "Party",

	-- Game menu
	["menu.resume"] = "Back to the game",
	["menu.switchCharacter"] = "Switch character",
	["menu.language"] = "Language",

	-- Nameplates and notifications
	["nameplate.levelClass"] = "Lv {level} {class}",
	["toast.enterWorld"] = "Welcome to Vaelthorn, {name}!",

	-- Errors (server answers carry these keys)
	["error.badRequest"] = "Invalid request.",
	["error.busy"] = "Please wait, the previous action is still in progress.",
	["error.confirmMismatch"] = "The name you typed does not match.",
	["error.internal"] = "Something went wrong. Please try again.",
	["error.network"] = "Connection problem. Please try again.",
	["error.notLoaded"] = "Your data is still loading.",
	["error.rateLimited"] = "Too many requests, slow down.",
	["error.slotEmpty"] = "This slot is empty.",
	["error.slotTaken"] = "This slot is already taken.",
	["error.wrongPhase"] = "You cannot do that right now.",
	["error.name.invalidUtf8"] = "The name contains invalid characters.",
	["error.name.tooShort"] = "The name must have at least {min} characters.",
	["error.name.tooLong"] = "The name can have at most {max} characters.",
	["error.name.invalidChars"] = "Only letters (including Polish ones) and digits are allowed.",
	["error.name.noLetter"] = "The name must contain at least one letter.",
	["error.name.filtered"] = "This name is not allowed.",
	["error.name.filterFailed"] = "The name could not be checked right now. Try again.",
	["error.name.storeFailed"] = "Name service unavailable. Try again in a moment.",
	["error.name.taken"] = "This name is already taken.",

	-- Kicks (shown in both languages)
	["kick.loadFailed"] = "Your data could not be loaded. Please rejoin.",
	["kick.sessionEnded"] = "Your data session ended (you probably joined another server).",

	-- Admin commands
	["admin.denied"] = "You do not have permission to use admin commands.",
	["admin.failed"] = "Command /{command} failed, see the server output.",
	["admin.needCharacter"] = "Enter the world with a character first.",
	["admin.help.header"] = "Admin commands:",
	["admin.usage.help"] = "/help: list admin commands",
	["admin.usage.gold"] = "/gold <amount>: add (or remove, if negative) gold on the active character",
	["admin.usage.shards"] = "/shards <amount>: add (or remove) Dragon Shards on the account",
	["admin.usage.wipe"] = "/wipe: delete the whole account (asks for /wipe confirm)",
	["admin.gold.ok"] = "Gold {amount}, now {total}.",
	["admin.shards.ok"] = "Dragon Shards {amount}, now {total}.",
	["admin.wipe.confirm"] = "This deletes ALL characters and account data. Type /wipe confirm within {seconds} s.",
	["admin.wipe.ok"] = "Account wiped.",
}
