--!strict
-- Server calls of the skills window (S59): nodes, the main path, breakpoints and the bar, one at a time. The server
-- checks every rule (place, combat, weapon); a refusal plays the error sound and shows its reason as a toast. Build
-- sets and their copy are handled by Components/BuildSetSwitch (S58).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

export type Actions = {
	buy: (nodeId: string) -> (),
	refund: (nodeId: string) -> (),
	resetAll: () -> (),
	chooseMain: (pathId: string, cost: ("free" | "scroll")?) -> (),
	chooseBp: (skillId: string, at: number, option: SkillData.BreakpointOption) -> (),
	toBar: (skillId: string) -> (),
	place: (slot: number) -> (),
}

local Actions = {}

-- Slot ("1".."10") holding `id` on `bar`, or nil.
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
			invoke("RefundNode", { nodeId })
		end,
		resetAll = function()
			confirm("paths.confirm.reset.title", "paths.confirm.reset.message", nil, function()
				invoke("ResetPaths", {})
			end)
		end,
		chooseMain = function(pathId: string, cost: ("free" | "scroll")?)
			local def = PathData.get(pathId)
			local name = if def then Text.now(def.nameKey) else pathId
			local paid = cost == "scroll"
			confirm(
				if paid then "paths.confirm.change.title" else "paths.confirm.choose.title",
				if paid then "paths.confirm.change.message" else "paths.confirm.choose.message",
				{ name = name },
				function()
					invoke("ChooseMainPath", { pathId })
				end
			)
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
		-- "To bar": the first free slot, or the 2 x 5 picker when the bar is full.
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
	}
	return actions
end

return Actions
