--!strict
-- Minimal test framework for Lune (ARCHITECTURE §12). Specs do:
--   local T = require("./Test")
--   T.describe("Rng", function() T.it("is deterministic", function() T.expect(a).toBe(b) end) end)
-- tests/run.luau requires every *.spec.luau and calls T.report().

local Test = {}

type Failure = { name: string, message: string }

local prefix: { string } = {}
local passed = 0
local failures: { Failure } = {}

local function fullName(name: string): string
	local parts = table.clone(prefix)
	table.insert(parts, name)
	return table.concat(parts, " > ")
end

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	local keys = {}
	for k in value do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, k in keys do
		table.insert(parts, `{tostring(k)}={show(value[k])}`)
		if #parts > 12 then
			table.insert(parts, "...")
			break
		end
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function Test.describe(name: string, body: () -> ())
	table.insert(prefix, name)
	body()
	table.remove(prefix)
end

function Test.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		table.insert(failures, { name = fullName(name), message = tostring(err) })
	end
end

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeNear: (expected: number, epsilon: number?) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeNil: () -> (),
	toThrow: (pattern: string?) -> (),
	toBeBetween: (low: number, high: number) -> (),
}

function Test.expect(actual: any): Expectation
	local function fail(message: string)
		error(message, 3)
	end
	return {
		toBe = function(expected)
			if actual ~= expected then
				fail(`expected {show(expected)}, got {show(actual)}`)
			end
		end,
		toEqual = function(expected)
			if not deepEqual(actual, expected) then
				fail(`expected {show(expected)}, got {show(actual)}`)
			end
		end,
		toBeNear = function(expected, epsilon)
			local eps = epsilon or 1e-6
			if type(actual) ~= "number" or math.abs(actual - expected) > eps then
				fail(`expected {expected} ± {eps}, got {show(actual)}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected a truthy value, got {show(actual)}`)
			end
		end,
		toBeFalsy = function()
			if actual then
				fail(`expected a falsy value, got {show(actual)}`)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				fail(`expected nil, got {show(actual)}`)
			end
		end,
		toThrow = function(pattern)
			assert(type(actual) == "function", "toThrow expects a function")
			local ok, err = pcall(actual)
			if ok then
				fail("expected the function to throw")
			elseif pattern and not string.find(tostring(err), pattern, 1, true) then
				fail(`expected error containing {show(pattern)}, got {show(tostring(err))}`)
			end
		end,
		toBeBetween = function(low, high)
			if type(actual) ~= "number" or actual < low or actual > high then
				fail(`expected a number in [{low}, {high}], got {show(actual)}`)
			end
		end,
	}
end

-- Prints the summary. Returns the number of failures.
function Test.report(): number
	for _, failure in failures do
		print(`FAIL  {failure.name}\n      {failure.message}`)
	end
	print(`\n{passed} passed, {#failures} failed`)
	return #failures
end

return Test
