--!strict
-- Server calls of the skills window (S59): nodes, breakpoints and the bar, one at a time. The server
-- checks every rule (place, combat, weapon); a refusal plays the error sound and shows its reason as a toast. Build
-- sets and their copy are handled by Components/BuildSetSwitch (S58).
-- S137 (DESIGN-18 §3): skill ranks are reserved in the window ("+", "-", "Spend as the pool suggests") and sent as one
-- AllocateSkills; "-" on a bought rank asks RefundSkillRank (with the gold price from Progression.freeRespecLevel);
-- "Reset" asks ResetSkills.
-- S138 (DESIGN-18 §3.2, §7): no main path choice; "-" on a node and "Refund all nodes" from Progression.freeRespecLevel
-- show the gold price (SkillPoints.refundCost) in the confirmation; "Reset" is the full reset (ranks and nodes; the
-- scroll pays when the reset is not free).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local SkillPoints = require(ReplicatedStorage.Shared.Logic.SkillPoints)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

export type Actions = {
	buy: (nodeId: string) -> (),
	refund: (nodeId: string) -> (),
	resetAll: () -> (),
	chooseBp: (skillId: string, at: number, option: SkillData.BreakpointOption) -> (),
	toBar: (skillId: string) -> (),
	place: (slot: number) -> (),
	-- S137
	addRank: (skillId: string) -> (),
	removeRank: (skillId: string) -> (),
	suggest: () -> (),
	confirmRanks: () -> (),
	resetSkills: () -> (),
}

local Actions = {}

-- Slot ("1".."8") holding `id` on `bar`, or nil.
function Actions.slotOf(bar: any, id: string): string?
	if type(bar) ~= "table" then
		return nil
	end
	for slot, existing in bar do
		if existing == id then
			return slot
		end
	end
	return nil
end

local function fail(err: string?)
	Sounds.play("error")
	Toast.push(Text.now(err or "error.internal"), "error")
end

function Actions.new(ctx: Context.Ctx): Actions
	local busy = false

	-- Runs one remote; `after(ok, err)` replaces the default error toast.
	local function invoke(remote: string, args: { any }, after: ((ok: boolean, err: string?) -> ())?)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err = Net.Invoke(remote, table.unpack(args))
			busy = false
			if after then
				after(ok == true, err)
			elseif not ok then
				fail(err)
			end
		end)
	end

	local function confirm(titleKey: string, messageKey: string, args: { [string]: any }?, run: () -> ())
		ctx.props.ShowModal({
			Title = Text.now(titleKey),
			Message = Text.now(messageKey, args),
			ConfirmText = Text.now("common.confirm"),
			CancelText = Text.now("common.cancel"),
			OnConfirm = function(): (boolean, string?)
				run()
				return true, nil
			end,
		})
	end

	local actions: Actions
	actions = {
		buy = function(nodeId: string)
			invoke("BuyNode", { nodeId })
		end,
		refund = function(nodeId: string)
			local character = Fusion.peek(ctx.character)
			local cost = if character then SkillPoints.nodeRefundCost(character, nodeId) else 0
			if cost <= 0 then
				invoke("RefundNode", { nodeId })
				return
			end
			local node = Paths.findNode(nodeId)
			local name = if node then Text.now(node.nameKey) else nodeId
			confirm(
				"paths.confirm.refund.title",
				"paths.confirm.refund.message",
				{ node = name, gold = cost },
				function()
					invoke("RefundNode", { nodeId })
				end
			)
		end,
		resetAll = function()
			local character: any = Fusion.peek(ctx.character)
			local cost = if character and character.respecFree ~= true
				then SkillPoints.nodesRefundCost(character)
				else 0
			local message = if cost > 0 then "paths.confirm.reset.paid" else "paths.confirm.reset.message"
			confirm("paths.confirm.reset.title", message, { gold = cost }, function()
				invoke("ResetPaths", {})
			end)
		end,
		chooseBp = function(skillId: string, at: number, option: SkillData.BreakpointOption)
			invoke("ChooseBreakpoint", { skillId, at, option }, function(ok: boolean, err: string?)
				if ok then
					ctx.bpError:set(nil)
					local skill = SkillData.get(skillId)
					local name = if skill then Text.now(skill.nameKey) else skillId
					Toast.push(
						Text.now("bp.done", { skill = name, rank = at, option = string.upper(option) }),
						"success"
					)
				else
					ctx.bpError:set({ key = Skills.choiceKey(skillId, at), err = err or "error.internal" })
					fail(err)
				end
			end)
		end,
		-- "To bar": the first free slot, or the 2 x 4 picker when the bar is full.
		toBar = function(skillId: string)
			if busy then
				return
			end
			local bar = Fusion.peek(ctx.hotbar)
			local current = if type(bar) == "table" then bar else {}
			if Actions.slotOf(current, skillId) == nil and Skills.firstFreeSlot(current) == nil then
				ctx.picking:set(skillId)
				return
			end
			invoke("PutOnBar", { skillId }, function(ok: boolean, err: string?)
				if ok then
					return
				end
				if err == "skills.error.barFull" then
					ctx.picking:set(skillId)
				else
					fail(err)
				end
			end)
		end,
		place = function(slot: number)
			local skillId = Fusion.peek(ctx.picking)
			if not skillId then
				return
			end
			invoke("PutOnBar", { skillId, slot }, function(ok: boolean, err: string?)
				if ok then
					ctx.picking:set(nil)
				else
					fail(err)
				end
			end)
		end,
		-- S137: one more rank in the reservation when SkillPoints.canBuy allows it on the planned character.
		addRank = function(skillId: string)
			local planned = Fusion.peek(ctx.planned)
			local pool = Fusion.peek(ctx.pool)
			if not planned or not pool then
				return
			end
			local ok, err = SkillPoints.canBuy(planned, pool, skillId, 1)
			if not ok then
				fail(err)
				return
			end
			local reserve = table.clone(Fusion.peek(ctx.reserve))
			reserve[skillId] = (reserve[skillId] or 0) + 1
			ctx.reserve:set(reserve)
		end,
		-- S137: a reserved rank goes back at once; a bought one through the server (a price from freeRespecLevel).
		removeRank = function(skillId: string)
			local reserve: { [string]: number } = table.clone(Fusion.peek(ctx.reserve))
			local reserved = reserve[skillId] or 0
			if reserved > 0 then
				reserve[skillId] = if reserved > 1 then reserved - 1 else nil :: any
				ctx.reserve:set(reserve)
				return
			end
			local character = Fusion.peek(ctx.character)
			local pool = Fusion.peek(ctx.pool)
			if not character or not pool or SkillPoints.bought(character, pool, skillId) <= 0 then
				return
			end
			local skill = SkillData.get(skillId)
			local name = if skill then Text.now(skill.nameKey) else skillId
			if character.level < Progression.freeRespecLevel then
				invoke("RefundSkillRank", { pool, skillId })
				return
			end
			confirm(
				"skills.points.refundTitle",
				"skills.points.refundMessage",
				{ skill = name, gold = SkillPoints.refundCost(character.level, 1) },
				function()
					invoke("RefundSkillRank", { pool, skillId })
				end
			)
		end,
		suggest = function()
			local planned = Fusion.peek(ctx.planned)
			local pool = Fusion.peek(ctx.pool)
			if not planned or not pool then
				return
			end
			local reserve = table.clone(Fusion.peek(ctx.reserve))
			for id, n in SkillPoints.suggest(planned, pool) do
				reserve[id] = (reserve[id] or 0) + n
			end
			ctx.reserve:set(reserve)
		end,
		confirmRanks = function()
			local pool = Fusion.peek(ctx.pool)
			local reserve = Fusion.peek(ctx.reserve)
			if not pool or next(reserve) == nil then
				return
			end
			invoke("AllocateSkills", { pool, table.clone(reserve) }, function(ok: boolean, err: string?)
				if ok then
					ctx.reserve:set({})
				else
					fail(err)
				end
			end)
		end,
		resetSkills = function()
			confirm("skills.points.resetTitle", "skills.reset.confirm", nil, function()
				invoke("ResetSkills", {})
			end)
		end,
	}
	return actions
end

return Actions
