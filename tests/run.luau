--!strict
-- Runs every tests/*.spec.luau with Lune: `lune run tests/run.luau`. Exit code 1 on any failure.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Test = require("./Test")

local specs = {}
for _, file in fs.readDir("tests") do
	local name = string.match(file, "^(.+%.spec)%.luau$")
	if name then
		table.insert(specs, name)
	end
end
table.sort(specs)

for _, spec in specs do
	local ok, err = pcall(function()
		(require :: any)(`./{spec}`)
	end)
	if not ok then
		Test.describe(spec, function()
			Test.it("loads", function()
				error(err, 0)
			end)
		end)
	end
end

print(`ran {#specs} spec files`)
process.exit(if Test.report() > 0 then 1 else 0)
