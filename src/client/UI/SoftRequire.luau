--!strict
-- Studio check 2026-10-31: Play once started before Rojo had created a new module (Shared/Logic/TopBand), and the
-- toasts, the announcements and the ~25 controllers that require them failed with it. The message layer requires the
-- newer modules it can live without through here: a missing or broken one logs a warning and the caller gets
-- `fallback` (the old fixed places), so one module never takes the rest down.
--   local TopBand = SoftRequire(function() return require(...) end, FALLBACK :: any, "TopBand")

local function SoftRequire<T>(get: () -> T, fallback: T, name: string): T
	local ok, result = pcall(get)
	if ok then
		return result
	end
	warn(`SoftRequire: {name} is not available, using its fallback ({result})`)
	return fallback
end

return SoftRequire
