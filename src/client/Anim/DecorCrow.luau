--!strict
-- Owner 2026-11-02 ("yes" to the Tripo crow): the decorative crows on the dead trees (MeadowsLifeController,
-- WorldLifeController) wear the carrion crow's model (Assets.Monsters.carrionCrow) at a crow's size instead of two
-- balls and two sticks. Perched it stands still in the flyer template's perch pose (Data/FlyerStyles crow `perch`,
-- written once: no cost while it sits); flying off it beats its wings (Logic/FlyerMotion through client/Anim/FlyerRig).
-- Made only once a crow comes into view, a few a frame (the model is skinned); without the model or its rig the
-- controllers keep their balls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlyerMotion = require(ReplicatedStorage.Shared.Logic.FlyerMotion)
local LookBuild = require(ReplicatedStorage.Shared.Util.LookBuild)
local MonsterAssets = require(ReplicatedStorage.Shared.Data.MonsterAssets)
local FlyerRig = require(script.Parent.FlyerRig)

local DecorCrow = {}

export type Crow = {
	model: Model,
	rig: FlyerRig.Rig,
	clock: number,
	perched: boolean,
	lift: number, -- studs: the body's middle over the pivot in flight
}

local MODEL = "carrionCrow"
local STYLE = "crow"
-- The model's size over its template's: a perched crow about 1.5 studs long (the monster's look is about 3.2).
DecorCrow.SCALE = 0.45
-- A perch point is the middle of the old 0.8 ball, this far over what it sits on (Logic/MeadowsGen/Kit.SIT).
DecorCrow.SIT = 0.35
-- Models made in one frame at most (a skinned clone, its rig and its pose).
DecorCrow.PER_FRAME = 3
-- What it flies off at (studs/s; the controllers move it about 67 studs in 3 s).
local CRUISE = 22

local missing = false
local madeAt = -1
local made = 0

local function stepRig(c: Crow, dt: number, speed: number, perch: boolean, snap: boolean)
	c.clock += dt
	local posed = FlyerMotion.step(c.rig.motion, {
		now = c.clock,
		dt = dt,
		speed = speed,
		yawRate = 0,
		combat = false,
		perch = perch,
		snap = snap,
	})
	FlyerRig.apply(c.rig, posed)
end

-- The crow's model under `parent`, perched; nil when there is none to make (`later` true: over this frame's budget,
-- ask again next frame; false: the model or its rig is missing, keep the balls).
function DecorCrow.make(seed: number, parent: Instance): (Crow?, boolean)
	if missing then
		return nil, false
	end
	local now = time()
	if now ~= madeAt then
		madeAt, made = now, 0
	end
	if made >= DecorCrow.PER_FRAME then
		return nil, true
	end
	made += 1
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Monsters")
	local template = folder and folder:FindFirstChild(MODEL)
	local entry = MonsterAssets[MODEL]
	if not template or not template:IsA("Model") or not entry then
		missing = true
		return nil, false
	end
	local model = template:Clone()
	LookBuild.stripScripts(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Destroy()
	end
	if not model.PrimaryPart then
		model.PrimaryPart = (
			model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
		) :: BasePart?
	end
	if not model.PrimaryPart then
		model:Destroy()
		missing = true
		return nil, false
	end
	model:ScaleTo(model:GetScale() * DecorCrow.SCALE)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
			if item.Name == "HumanoidRootPart" then
				item.Transparency = 1
			end
		end
	end
	model.Name = "crow"
	model.Parent = parent
	local rig = FlyerRig.new(model, STYLE, seed, MODEL)
	if not rig then
		model:Destroy()
		missing = true
		return nil, false
	end
	local crow: Crow = {
		model = model,
		rig = rig,
		clock = 0,
		perched = false,
		lift = (entry.hipHeight + entry.rootSize[2] / 2) * DecorCrow.SCALE,
	}
	DecorCrow.perch(crow)
	return crow, false
end

-- Settles it on its perch at once (it lands unseen: the controllers bring a crow back while the player is away).
function DecorCrow.perch(c: Crow)
	stepRig(c, 0, 0, true, true)
	stepRig(c, 0.5, 0, true, false) -- (past the snap's fade, Logic/FlyerMotion FADE)
	c.perched = true
end

-- One frame of the flight off the perch: it rises, the wings beat.
function DecorCrow.fly(c: Crow, dt: number)
	stepRig(c, dt, CRUISE, false, false)
	c.perched = false
end

-- Puts it at `at` facing `yaw` (rad, its front -Z): perched, `at` is the perch point (DecorCrow.SIT over the branch);
-- flying, the body's middle.
function DecorCrow.place(c: Crow, at: Vector3, yaw: number)
	local ground = if c.perched then at - Vector3.new(0, DecorCrow.SIT, 0) else at - Vector3.new(0, c.lift, 0)
	c.model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, yaw, 0))
end

return DecorCrow
