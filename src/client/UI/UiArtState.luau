--!strict
-- Interface pictures on the client (S119): which files of Data/UiArt (atlases and single pictures) are uploaded and
-- loaded. Atlases load once at start (UIController, next to IconState.load); single pictures (painted maps, class
-- portraits, boss portraits, dungeon banners) only when a window asks for them (UiArtState.ensure). A key draws its
-- picture only while IconState.Mode is "art" (/icons glyph switches every picture off) and its file is loaded;
-- otherwise the place keeps today's glyph (UI/Components/ArtIcon, UiArtState.decorate for code without Fusion).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.IconState)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local peek = Fusion.peek
local scope = Fusion.scoped(Fusion)

export type Look = {
	image: string,
	offset: Vector2, -- ImageRectOffset (zero for a single picture)
	size: Vector2, -- ImageRectSize (zero = the whole image)
	tint: boolean, -- a silhouette: ImageColor3 = the glyph colour
	single: boolean,
}

local UiArtState = {}

-- Files that loaded (PreloadAsync said Success), by file name.
UiArtState.Loaded = scope:Value({} :: { [string]: boolean })
-- Result of the last preload per file ("Success", "Failure", ...; "none" without an id, "pending").
UiArtState.Status = {} :: { [string]: string }

local requested: { [string]: boolean } = {}

local function preload(files: { string })
	local ids: { [string]: string } = {}
	local labels: { Instance } = {}
	for _, file in files do
		local id = UiArt.idOf(file)
		if requested[file] then
			continue
		end
		requested[file] = true
		if not id then
			UiArtState.Status[file] = "none"
			continue
		end
		UiArtState.Status[file] = "pending"
		ids[file] = id
		-- ImageLabels, not bare id strings (IconState: PreloadAsync on a string reports Failure for good images).
		local label = Instance.new("ImageLabel")
		label.Image = id
		table.insert(labels, label)
	end
	if #labels == 0 then
		return
	end
	local loaded: { [string]: boolean } = {}
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(labels, function(contentId: string, status: Enum.AssetFetchStatus)
			for file, id in ids do
				if id == contentId then
					UiArtState.Status[file] = status.Name
					if status == Enum.AssetFetchStatus.Success then
						loaded[file] = true
					else
						warn(`[UiArt] {file}: {status.Name}`)
					end
				end
			end
		end)
	end)
	for _, label in labels do
		label:Destroy()
	end
	-- A thrown PreloadAsync (or a file it never reported) still gets its one warning; a later ensure may retry it.
	for file in ids do
		if UiArtState.Status[file] == "pending" then
			UiArtState.Status[file] = "Failure"
			requested[file] = nil
			warn(`[UiArt] {file}: {if ok then "not reported" else tostring(err)}`)
		end
	end
	if next(loaded) == nil then
		return
	end
	local merged = table.clone(peek(UiArtState.Loaded))
	for file in loaded do
		merged[file] = true
	end
	UiArtState.Loaded:set(merged)
end

-- Preloads every atlas once (one PreloadAsync, one warning per file that does not load). Yields: call in a task.
function UiArtState.load()
	preload(UiArt.atlasFiles())
end

-- Loads a single picture (or atlas) file once, in the background. Safe to call on every window open.
function UiArtState.ensure(file: string?)
	if not file or requested[file] then
		return
	end
	task.spawn(preload, { file })
end

-- Same for the file of a key.
function UiArtState.ensureKey(key: string?)
	UiArtState.ensure(UiArt.fileOf(key))
end

local function lookOf(loaded: { [string]: boolean }, mode: string, key: string?): Look?
	if mode ~= "art" or not key then
		return nil
	end
	local file = UiArt.fileOf(key)
	if not file or not loaded[file] then
		return nil
	end
	local id = UiArt.idOf(file)
	if not id then
		return nil
	end
	local cell = UiArt.cell(key)
	if cell then
		return {
			image = id,
			offset = Vector2.new(cell.x, cell.y),
			size = Vector2.new(UiArt.CELL, UiArt.CELL),
			tint = UiArt.tinted(key),
			single = false,
		}
	end
	return { image = id, offset = Vector2.zero, size = Vector2.zero, tint = false, single = true }
end

-- The picture of a key inside a Computed (nil = draw the glyph).
function UiArtState.look(use: Fusion.Use, key: string?): Look?
	return lookOf(use(UiArtState.Loaded), use(IconState.Mode), key)
end

function UiArtState.ready(use: Fusion.Use, key: string?): boolean
	return UiArtState.look(use, key) ~= nil
end

-- Outside Computeds (map canvas, minimap, nameplates).
function UiArtState.lookNow(key: string?): Look?
	return lookOf(peek(UiArtState.Loaded), peek(IconState.Mode), key)
end

-- Sets an ImageLabel to a look (atlas cell or whole picture).
function UiArtState.apply(image: ImageLabel, look: Look)
	image.Image = look.image
	image.ImageRectOffset = look.offset
	image.ImageRectSize = look.size
end

-- ------------------------------------------------------------------------------------------------ plain labels

type Entry = {
	image: ImageLabel,
	key: string?,
	tint: Color3?,
	alpha: number,
	stroke: number,
	rotation: number,
}

local entries: { [TextLabel]: Entry } = {}

local function refresh(label: TextLabel, entry: Entry)
	local look = UiArtState.lookNow(entry.key)
	if look then
		UiArtState.apply(entry.image, look)
		entry.image.ImageColor3 = if look.tint and entry.tint then entry.tint else Color3.new(1, 1, 1)
		entry.image.ImageTransparency = entry.alpha
		entry.image.Rotation = entry.rotation
		entry.image.Visible = true
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
	else
		entry.image.Visible = false
		label.TextTransparency = entry.alpha
		label.TextStrokeTransparency = entry.stroke
	end
end

export type DecorateOptions = {
	tint: Color3?, -- silhouette colour (default: the label's text colour)
	size: number?, -- picture side in pixels (default: the label's height)
}

-- Gives a glyph TextLabel built without Fusion a picture: one ImageLabel child (centred, square), shown instead of the
-- glyph while the key's file is loaded. The label keeps its position, visibility and parent; code that later changes
-- the label's text transparency or the key goes through UiArtState.fade / retarget. Created once per label.
function UiArtState.decorate(label: TextLabel, key: string?, opts: DecorateOptions?): ImageLabel
	local existing = entries[label]
	if existing then
		existing.key = key
		refresh(label, existing)
		return existing.image
	end
	local o: DecorateOptions = opts or {}
	local side = o.size or label.Size.Y.Offset
	local image = Instance.new("ImageLabel")
	image.Name = "Art"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = if side > 0 then UDim2.fromOffset(side, side) else UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = label.ZIndex
	image.Visible = false
	image.Parent = label
	local entry: Entry = {
		image = image,
		key = key,
		tint = o.tint or label.TextColor3,
		alpha = label.TextTransparency,
		stroke = label.TextStrokeTransparency,
		rotation = 0,
	}
	entries[label] = entry
	label.Destroying:Connect(function()
		entries[label] = nil
	end)
	refresh(label, entry)
	return image
end

-- New key and / or tint of a decorated label (pooled markers: only properties change, no instances).
function UiArtState.retarget(label: TextLabel, key: string?, tint: Color3?, rotation: number?)
	local entry = entries[label]
	if not entry then
		UiArtState.decorate(label, key, { tint = tint })
		entry = entries[label]
	end
	if not entry then
		return
	end
	if entry.key == key and (tint == nil or entry.tint == tint) and (rotation == nil or entry.rotation == rotation) then
		return
	end
	entry.key = key
	if tint then
		entry.tint = tint
	end
	if rotation then
		entry.rotation = rotation
	end
	refresh(label, entry)
end

-- Text / picture transparency of a decorated label (the glyph's own values when no picture is shown).
function UiArtState.fade(label: TextLabel, transparency: number, stroke: number, tint: Color3?)
	local entry = entries[label]
	if not entry then
		label.TextTransparency = transparency
		label.TextStrokeTransparency = stroke
		return
	end
	entry.alpha = transparency
	entry.stroke = stroke
	if tint then
		entry.tint = tint
	end
	refresh(label, entry)
end

local function refreshAll()
	for label, entry in entries do
		refresh(label, entry)
	end
end
scope:Observer(UiArtState.Loaded):onChange(refreshAll)
scope:Observer(IconState.Mode):onChange(refreshAll)

return UiArtState
