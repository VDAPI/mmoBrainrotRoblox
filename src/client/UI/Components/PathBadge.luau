--!strict
-- The main path sign of a party member (S60): the same mark as the path tab of the skills window (S59), the weapon
-- icon of Paths.iconWeapon, else the first letter of the path name, on a small Panel-coloured plate. nil for a
-- member without a main path or with a path that has no PathDef.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcon = require(script.Parent.ItemIcon)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local PathBadge = {}

function PathBadge.def(pathId: any): PathData.PathDef?
	return if type(pathId) == "string" then PathData.byId[pathId] else nil
end

-- First letter of a UTF-8 string (Polish letters are several bytes).
local function firstLetter(text: string): string
	for _, code in utf8.codes(text) do
		return utf8.char(code)
	end
	return "?"
end

function PathBadge.new(scope: Scope, use: Fusion.Use, pathId: any, size: number, position: UDim2): Instance?
	local def = PathBadge.def(pathId)
	if not def then
		return nil
	end
	local weaponType = Paths.iconWeapon(def)
	local item = if weaponType then Items.get(`{weaponType}_1`) else nil
	local inner: Instance = if item
		then ItemIcon(scope, { Def = item, Size = UDim2.fromScale(1, 1) })
		else scope:New("TextLabel")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = firstLetter(Text.get(use, def.nameKey)),
			TextScaled = true,
			FontFace = Theme.Fonts.BodyBold,
			TextColor3 = Theme.Colors.GoldBright,
		})
	return scope:New("Frame")({
		Name = "PathBadge",
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 3,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			inner,
		},
	})
end

return PathBadge
