--!strict
local fs = require("@lune/fs")
local T = require("./Test")
local CameraLease = require("../src/shared/Logic/CameraLease")

T.describe("CameraLease", function()
	T.it("gives the camera to the last owner and back when it lets go", function()
		local s = CameraLease.new()
		T.expect(CameraLease.holder(s)).toBeNil()
		CameraLease.claim(s, "animlab", 0, { travel = true })
		CameraLease.claim(s, "cutscene", 1)
		T.expect(CameraLease.holder(s)).toBe("cutscene")
		T.expect(CameraLease.release(s, "cutscene")).toBe(true)
		T.expect(CameraLease.holder(s)).toBe("animlab")
		T.expect(CameraLease.release(s, "cutscene")).toBe(false)
		T.expect(CameraLease.release(s, "animlab")).toBe(true)
		T.expect(CameraLease.holder(s)).toBeNil()
	end)

	T.it("moves a claim taken again to the top with its new options", function()
		local s = CameraLease.new()
		CameraLease.claim(s, "cutscene", 0, { camera = false, lock = true })
		CameraLease.claim(s, "animlab", 0)
		T.expect(CameraLease.holder(s)).toBe("animlab")
		T.expect(CameraLease.locked(s)).toBe(true)
		CameraLease.claim(s, "cutscene", 1, { camera = true, lock = true })
		T.expect(CameraLease.holder(s)).toBe("cutscene")
		T.expect(#s.leases).toBe(2)
	end)

	T.it("locks movement only while a locking owner holds", function()
		local s = CameraLease.new()
		CameraLease.claim(s, "select", 0)
		T.expect(CameraLease.locked(s)).toBe(false)
		CameraLease.claim(s, "cutscene", 0, { camera = false, lock = true })
		T.expect(CameraLease.locked(s)).toBe(true)
		-- an input-only lease does not take the camera
		T.expect(CameraLease.holder(s)).toBe("select")
		CameraLease.release(s, "cutscene")
		T.expect(CameraLease.locked(s)).toBe(false)
	end)

	T.it("takes back leases past their deadline", function()
		local s = CameraLease.new()
		CameraLease.claim(s, "cutscene", 10, { ttl = 30, lock = true })
		CameraLease.claim(s, "select", 10)
		T.expect(#CameraLease.expired(s, 39)).toBe(0)
		local gone = CameraLease.expired(s, 40)
		T.expect(#gone).toBe(1)
		T.expect(gone[1]).toBe("cutscene")
		T.expect(CameraLease.locked(s)).toBe(false)
		T.expect(CameraLease.holder(s)).toBe("select")
	end)

	T.it("lets go of travel leases only", function()
		local s = CameraLease.new()
		CameraLease.claim(s, "animlab", 0, { travel = true })
		CameraLease.claim(s, "cutscene", 0)
		local gone = CameraLease.travelled(s)
		T.expect(#gone).toBe(1)
		T.expect(gone[1]).toBe("animlab")
		T.expect(CameraLease.holder(s)).toBe("cutscene")
	end)

	T.it("tells a teleport from walking, riding and Blink", function()
		T.expect(CameraLease.teleported({ 0, 5, 0 }, { 3, 5, 2 })).toBe(false)
		T.expect(CameraLease.teleported({ 0, 5, 0 }, { 20, 5, 0 })).toBe(false)
		T.expect(CameraLease.teleported({ 0, 5, 0 }, { 3976, 40, 10 })).toBe(true)
		T.expect(CameraLease.teleported(nil, { 0, 0, 0 })).toBe(false)
	end)

	T.it("gives an ownerless Scriptable camera back after the grace time", function()
		local s = CameraLease.new()
		-- the player's camera: nothing to do
		T.expect(CameraLease.watch(s, false, 0)).toBe(false)
		-- Scriptable with no owner: not on the first frame, after GRACE (15 fps frames)
		local now = 1
		T.expect(CameraLease.watch(s, true, now)).toBe(false)
		local fired = false
		for _ = 1, 20 do
			now += 1 / 15
			if CameraLease.watch(s, true, now) then
				fired = true
				break
			end
		end
		T.expect(fired).toBe(true)
		T.expect(now - 1 >= CameraLease.GRACE).toBe(true)
		-- an owner holds it: never
		CameraLease.claim(s, "cutscene", now)
		for _ = 1, 30 do
			now += 1 / 15
			T.expect(CameraLease.watch(s, true, now)).toBe(false)
		end
		-- a moment back on Custom resets the count
		CameraLease.release(s, "cutscene")
		T.expect(CameraLease.watch(s, true, now)).toBe(false)
		T.expect(CameraLease.watch(s, false, now + 0.3)).toBe(false)
		T.expect(CameraLease.watch(s, true, now + 0.4)).toBe(false)
		T.expect(CameraLease.watch(s, true, now + 0.6)).toBe(false)
		T.expect(CameraLease.watch(s, true, now + 0.95)).toBe(true)
	end)

	T.it("lets only CameraController (and a scene's frame writer while it holds) make the camera Scriptable", function()
		-- the game camera has one owner at a time: a new Scriptable camera goes through CameraController.Claim
		local allowed = {
			["src/client/Controllers/CameraController.luau"] = true,
			["src/client/Controllers/CutsceneController.luau"] = true,
		}
		local function walk(dir: string, out: { string })
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					walk(path, out)
				elseif string.match(name, "%.luau$") then
					table.insert(out, path)
				end
			end
		end
		local files: { string } = {}
		walk("src/client", files)
		local offenders: { string } = {}
		for _, path in files do
			if not allowed[path] and string.find(fs.readFile(path), "CameraType%.Scriptable") then
				table.insert(offenders, path)
			end
		end
		T.expect(table.concat(offenders, ", ")).toBe("")
	end)
end)
