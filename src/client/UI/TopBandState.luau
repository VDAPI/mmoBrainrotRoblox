--!strict
-- UI plan phase 2: what the top band of messages keeps clear of. Studio check of phase 4: a tile that stays near the
-- top while it shows (the tutorial's, Controllers/TutorialController), in screen pixels (as AbsolutePosition).
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): UI/Notify's queue
-- (Logic/NoticeQueue) decides which banner and toast show, so the banners' flags and the toasts' top that lived here
-- went; UI/Notify reads the tile (Logic/TopBand.slots puts a message that would meet it beside it, else under it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

type Rect = { left: number, top: number, right: number, bottom: number }

local TopBandState = {}

local scope = Fusion.scoped(Fusion)

-- The tile the band keeps clear of; nil: none.
TopBandState.Keep = scope:Value(nil :: Rect?)

-- Sets the tile the band keeps clear of (nil: none), only when it changed.
function TopBandState.keep(rect: Rect?)
	local now = Fusion.peek(TopBandState.Keep)
	if rect == nil or now == nil then
		if rect ~= now then
			TopBandState.Keep:set(rect)
		end
		return
	end
	if now.left ~= rect.left or now.top ~= rect.top or now.right ~= rect.right or now.bottom ~= rect.bottom then
		TopBandState.Keep:set(rect)
	end
end

return TopBandState
