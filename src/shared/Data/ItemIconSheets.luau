--!strict
-- Asset ids of the item icon atlases art/icons/items_<n>.png (S35), in sheet order. Filled in by hand after
-- the upload in Studio (docs/ASSETS.md, "Ikony przedmiotów"). An empty string means "not uploaded yet":
-- the UI then keeps the old glyph icons, so the game works before and after the upload.

return table.freeze({
	"", -- items_1.png, e.g. "rbxassetid://1234567890"
	"", -- items_2.png
	"", -- items_3.png
})
