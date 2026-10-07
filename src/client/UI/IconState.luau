--!strict
-- Item icon atlases on the client (S35): whether the three sheets (Data/ItemIconSheets) are uploaded and loaded,
-- and the admin switch between pictures and the old glyphs (/icons art | glyph, not saved). Components draw the
-- atlas only when IconState.Art is true; otherwise every icon is a glyph, never a half set.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcons = require(ReplicatedStorage.Shared.Logic.ItemIcons)

local scope = Fusion.scoped(Fusion)

local IconState = {}

-- The sheets loaded (PreloadAsync said Success for each).
IconState.Ok = scope:Value(false)
-- "art" (pictures when loaded) or "glyph" (admin switch).
IconState.Mode = scope:Value("art")
-- Draw pictures now.
IconState.Art = scope:Computed(function(use): boolean
	return use(IconState.Ok) and use(IconState.Mode) == "art"
end)
-- Result of the last preload per sheet ("Success", "Failure", ...; "none" before an upload).
IconState.Status = {} :: { [number]: string }

local loading = false

-- Preloads the sheets once. Without asset ids it stays silent (glyphs); a sheet that does not load gives one
-- warning and keeps glyphs everywhere.
function IconState.load()
	if loading then
		return
	end
	loading = true
	local ids = {}
	for n = 1, ItemIcons.SHEETS do
		local id = ItemIcons.sheet(n)
		IconState.Status[n] = if id then "pending" else "none"
		if id then
			table.insert(ids, id)
		end
	end
	if not ItemIcons.ready() then
		return
	end
	local failed = false
	local ok = pcall(function()
		ContentProvider:PreloadAsync(ids, function(contentId: string, status: Enum.AssetFetchStatus)
			for n = 1, #ids do
				if ItemIcons.sheet(n) == contentId then
					IconState.Status[n] = status.Name
					if status ~= Enum.AssetFetchStatus.Success then
						failed = true
						warn(`[ItemIcons] sheet {n}: {status.Name}`)
					end
				end
			end
		end)
	end)
	IconState.Ok:set(ok and not failed)
end

return IconState
