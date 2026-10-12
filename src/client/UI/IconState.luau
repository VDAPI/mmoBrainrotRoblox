--!strict
-- Item icon atlases on the client (S35, S52): which sheets (Data/ItemIconSheets) are uploaded and loaded, and the
-- admin switch between pictures and the old glyphs (/icons art | glyph, not saved). Components draw the atlas only
-- when IconState.Art is true (every code-drawn sheet 1..SVG_SHEETS loaded); otherwise every icon is a glyph. Picture
-- sheets (S52, after the code-drawn ones) count one by one: an icon uses its picture once that sheet is loaded and
-- the code-drawn icon until then (IconState.readyIn).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcons = require(ReplicatedStorage.Shared.Logic.ItemIcons)

local scope = Fusion.scoped(Fusion)

local IconState = {}

-- The code-drawn sheets loaded (PreloadAsync said Success for each).
IconState.Ok = scope:Value(false)
-- Sheets that loaded, by number (code-drawn and picture sheets).
IconState.Loaded = scope:Value({} :: { [number]: boolean })
-- "art" (pictures when loaded) or "glyph" (admin switch).
IconState.Mode = scope:Value("art")
-- Draw pictures now.
IconState.Art = scope:Computed(function(use): boolean
	return use(IconState.Ok) and use(IconState.Mode) == "art"
end)
-- Result of the last preload per sheet ("Success", "Failure", ...; "none" before an upload).
IconState.Status = {} :: { [number]: string }

-- Readiness of the sheets for ItemIcons.resolve / named inside a Computed (re-runs when a sheet loads).
function IconState.readyIn(use: Fusion.Use): ItemIcons.Ready
	local loaded = use(IconState.Loaded)
	return function(n: number): boolean
		return loaded[n] == true
	end
end

local loading = false

-- Preloads the sheets once. Without asset ids of the code-drawn sheets it stays silent (glyphs); a sheet that does
-- not load gives one warning (a code-drawn one keeps glyphs everywhere, a picture sheet only its code-drawn icons).
function IconState.load()
	if loading then
		return
	end
	loading = true
	local ids: { [number]: string } = {}
	for n = 1, ItemIcons.SHEETS do
		local id = ItemIcons.sheet(n)
		IconState.Status[n] = if id then "pending" else "none"
		if id then
			ids[n] = id
		end
	end
	if not ItemIcons.ready() then
		return
	end
	-- Preload ImageLabels, not the id strings: PreloadAsync on a bare "rbxassetid://" string reports Failure for
	-- images that load fine (checked in Studio for these sheets and public assets); an instance fetches the image.
	local labels: { Instance } = {}
	for _, id in ids do
		local label = Instance.new("ImageLabel")
		label.Image = id
		table.insert(labels, label)
	end
	local loaded: { [number]: boolean } = {}
	local ok = pcall(function()
		ContentProvider:PreloadAsync(labels, function(contentId: string, status: Enum.AssetFetchStatus)
			for n, id in ids do
				if id == contentId then
					IconState.Status[n] = status.Name
					if status == Enum.AssetFetchStatus.Success then
						loaded[n] = true
					else
						warn(`[ItemIcons] sheet {n}: {status.Name}`)
					end
				end
			end
		end)
	end)
	for _, label in labels do
		label:Destroy()
	end
	local base = ok
	for n = 1, ItemIcons.SVG_SHEETS do
		base = base and loaded[n] == true
	end
	IconState.Loaded:set(if ok then loaded else {})
	IconState.Ok:set(base)
end

return IconState
