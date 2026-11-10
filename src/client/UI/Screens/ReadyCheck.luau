--!strict
-- Ready check overlay (S134f, DESIGN §16): while the state branch `readyCheck` exists (DungeonService): the boss,
-- every asked member with ✓ / ✗ / …, "Ready" / "Not now" (44 px and more, phones) and a bar of the time left. Once
-- everyone said yes the buttons go and the big 3-2-1 comes from BossAnnounce. Mounted once by DungeonController.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the check is a
-- prompt (Components/Prompt, UI/Notify's queue; it beats every other prompt and card): "Ready for <boss>?" with ✓ and
-- ✕ and the bar of the time left; the members' answers wait under 'Więcej ▸'. After the own answer the line says
-- whom it waits for, then that the fight starts; the prompt goes with the check.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Notify = require(script.Parent.Parent.Notify)
local Prompt = require(script.Parent.Parent.Components.Prompt)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local ReadyCheck = {}

local ROW = 24 -- a member's row under 'Więcej ▸'

local function answer(yes: boolean)
	Sounds.play("click")
	task.spawn(function()
		local ok, err = Net.Invoke("DungeonReady", yes)
		if not ok then
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

-- The members and their answers (✓ / ✗ / …), live.
local function members(check: Fusion.UsedAs<any>): (Scope, boolean) -> Instance
	return function(s: Scope, phone: boolean): Instance
		local rows = s:Computed(function(use, inner: Scope): { Instance }
			local c = use(check)
			local out: { Instance } = {}
			if type(c) ~= "table" or type(c.members) ~= "table" then
				return out
			end
			for i, member in c.members do
				local mark = if member.answer == true then "✓" elseif member.answer == false then "✗" else "…"
				local color = if member.answer == true
					then Theme.Iron.Success
					elseif member.answer == false then Theme.Iron.Danger
					else Theme.Iron.TextMuted
				table.insert(
					out,
					inner:New("TextLabel")({
						LayoutOrder = i,
						Size = UDim2.new(1, 0, 0, ROW),
						BackgroundTransparency = 1,
						Text = `{mark}  {member.name}`,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = if phone then Theme.TextSize.Caption else Theme.TextSize.Small,
						TextColor3 = color,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					})
				)
			end
			return out
		end)
		return s:New("Frame")({
			Name = "Members",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[Children] = {
				s:New("UIPadding")({
					PaddingLeft = UDim.new(0, Theme.Padding.Medium),
					PaddingRight = UDim.new(0, Theme.Padding.Small),
				}),
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
				rows :: any,
			},
		})
	end
end

-- Shows the prompt while the state branch `readyCheck` exists (DungeonController calls it once).
function ReadyCheck.watch(scope: Scope)
	local check = State.Value({ "readyCheck" })
	local myId = Players.LocalPlayer.UserId
	local handle: Notify.Handle? = nil
	local shownFor: number? = nil -- the check the prompt belongs to (its end time)

	local function close()
		if handle then
			handle.close()
			handle = nil
		end
	end
	local function mine(use: Fusion.Use): boolean?
		local c = use(check)
		if type(c) ~= "table" or type(c.members) ~= "table" then
			return nil
		end
		for _, member in c.members do
			if member.id == myId then
				return member.answer
			end
		end
		return nil
	end
	local function going(use: Fusion.Use): boolean
		local c = use(check)
		return type(c) == "table" and c.goAt ~= nil
	end

	scope:Observer(check):onBind(function()
		local c = Fusion.peek(check)
		if type(c) ~= "table" then
			close()
			shownFor = nil
			return
		end
		local id = tonumber(c.endsAt) or 0
		if shownFor == id then
			return -- the same check: the prompt follows its answers
		end
		close()
		shownFor = id
		local count = if type(c.members) == "table" then #c.members else 0
		handle = Prompt.push({
			class = "readyCheck",
			icon = "⚔",
			seconds = math.max(1, id - Workspace:GetServerTimeNow()),
			total = Config.Boss.readyTimeout,
			keep = true, -- the check's state answers: the line changes, the prompt goes with the check
			line = function(use: Fusion.Use, _left: number): string
				if going(use) then
					return Text.get(use, "dungeon.ready.go")
				elseif mine(use) ~= nil then
					return Text.get(use, "dungeon.ready.waiting")
				end
				local now = use(check)
				local boss = if type(now) == "table" and type(now.bossKey) == "string"
					then Text.get(use, now.bossKey)
					else ""
				return Text.get(use, "dungeon.ready.title", { boss = boss })
			end,
			accept = function()
				answer(true)
			end,
			decline = function()
				answer(false)
			end,
			answered = function(use: Fusion.Use): boolean
				return going(use) or mine(use) ~= nil
			end,
			more = if count > 0 then members(check) else nil,
			moreHeight = count * ROW + 4,
		})
	end)
end

return ReadyCheck
