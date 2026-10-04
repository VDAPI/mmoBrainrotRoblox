--!strict
-- Tiny prefixed logger. Log.new("DataService"):info("loaded %s", name)

local Config = require("../Config")

local Log = {}
Log.__index = Log

export type Logger = typeof(setmetatable({} :: { prefix: string }, Log))

local function render(fmt: string, ...: any): string
	if select("#", ...) == 0 then
		return fmt
	end
	local ok, result = pcall(string.format, fmt, ...)
	return if ok then result else fmt
end

function Log.new(name: string): Logger
	return setmetatable({ prefix = `[{name}]` }, Log)
end

function Log.debug(self: Logger, fmt: string, ...: any)
	if Config.Debug.VerboseLogs then
		print(self.prefix, render(fmt, ...))
	end
end

function Log.info(self: Logger, fmt: string, ...: any)
	print(self.prefix, render(fmt, ...))
end

function Log.warn(self: Logger, fmt: string, ...: any)
	warn(self.prefix, render(fmt, ...))
end

-- Logs an error without throwing (use `error` to throw).
function Log.error(self: Logger, fmt: string, ...: any)
	warn(self.prefix, "ERROR:", render(fmt, ...))
end

return Log
