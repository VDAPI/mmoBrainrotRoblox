--!strict
-- Asset ids of the item icon atlases art/icons/items_<n>.png (S35), in sheet order. Filled in by hand after
-- the upload in Studio (docs/ASSETS.md, "Ikony przedmiotów"). An empty string means "not uploaded yet": for the
-- code-drawn sheets 1..SVG_SHEETS the UI keeps the old glyph icons; for picture sheets (S52, tools/icons/import_png.py
-- writes "" here for every sheet it changed) it keeps the code-drawn icons. The game works before and after the upload.

return table.freeze({
	"rbxassetid://104431147179940", -- items_1.png
	"rbxassetid://113622747165970", -- items_2.png
	"rbxassetid://103992189653299", -- items_3.png
	"rbxassetid://138699466409669", -- items_4.png
	"rbxassetid://98316238490036", -- items_5.png
	"rbxassetid://124843781940021", -- items_6.png
	"rbxassetid://84392218433501", -- items_7.png
	"rbxassetid://97549795264129", -- items_8.png
	"rbxassetid://85060312795414", -- items_9.png
	"rbxassetid://81410443343423", -- items_10.png
	"rbxassetid://107582805090716", -- items_11.png
	"rbxassetid://125235074996800", -- items_12.png
	"rbxassetid://104977681264631", -- items_13.png
	"rbxassetid://91320870718887", -- items_14.png
	"rbxassetid://139265819090472", -- items_15.png
	"rbxassetid://136537754535619", -- items_16.png
	"rbxassetid://101372121453377", -- items_17.png
	"rbxassetid://95986866649011", -- items_18.png
	"rbxassetid://97997907088255", -- items_19.png
})
