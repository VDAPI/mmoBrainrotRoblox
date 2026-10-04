--!strict
-- Number and time formatting for UI. Pure Luau.

local Format = {}

-- 1234567 -> "1 234 567" (thin grouping with a regular space, readable in PL and EN).
function Format.number(n: number, separator: string?): string
	local sep = separator or " "
	local negative = n < 0
	local int = math.floor(math.abs(n) + 0.5)
	local digits = tostring(int)
	local groups = {}
	local len = #digits
	local first = len % 3
	if first > 0 then
		table.insert(groups, string.sub(digits, 1, first))
	end
	for i = first + 1, len, 3 do
		table.insert(groups, string.sub(digits, i, i + 2))
	end
	return (if negative then "-" else "") .. table.concat(groups, sep)
end

local SUFFIXES = { "", "k", "M", "B", "T" }

-- 1234 -> "1.2k", 3400000 -> "3.4M", 999 -> "999".
function Format.short(n: number): string
	local negative = n < 0
	local value = math.abs(n)
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text
	if index == 1 then
		text = tostring(math.floor(value + 0.5))
	else
		local rounded = math.floor(value * 10) / 10
		if rounded == math.floor(rounded) then
			text = string.format("%d", rounded)
		else
			text = string.format("%.1f", rounded)
		end
		text ..= SUFFIXES[index]
	end
	return (if negative then "-" else "") .. text
end

-- 75 -> "01:15", 3725 -> "01:02:05" (hours only shown when needed).
function Format.time(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local h = total // 3600
	local m = (total % 3600) // 60
	local s = total % 60
	if h > 0 then
		return string.format("%02d:%02d:%02d", h, m, s)
	end
	return string.format("%02d:%02d", m, s)
end

-- Always hh:mm:ss.
function Format.timeLong(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", total // 3600, (total % 3600) // 60, total % 60)
end

return Format
