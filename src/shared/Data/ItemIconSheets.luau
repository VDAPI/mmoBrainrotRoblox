--!strict
-- Asset ids of the item icon atlases art/icons/items_<n>.png (S35), in sheet order. Filled in by hand after
-- the upload in Studio (docs/ASSETS.md, "Ikony przedmiotów"). An empty string means "not uploaded yet":
-- the UI then keeps the old glyph icons, so the game works before and after the upload.

return table.freeze({
	"rbxassetid://104431147179940", -- items_1.png
	"rbxassetid://113622747165970", -- items_2.png
	"rbxassetid://103992189653299", -- items_3.png
})
