--!strict
-- W26: the imported Tripo models (ReplicatedStorage.Assets.Monsters.<id>, docs/wyglad/SESJE-W.md) that replace the
-- generated look of a monster kind or boss. Data/MonsterLooks merges each entry into its look as `asset` (model = the
-- key, tint = true). The hitbox numbers are the generator's at LookScale 1, so the fight stays the same; the models
-- were scaled in Studio to the generator's height (hover plans stand `Anatomy.HOVER` above their root part).
-- rig "bones": clips from Data/MonsterClips/<id> (client/Anim/BoneClips); "static": no clips yet.

export type Entry = {
	rig: "bones" | "static",
	rootSize: { number },
	hipHeight: number,
	height: number,
	walkSpeed: number,
}

local MonsterAssets: { [string]: Entry } = {
	bandit = { rig = "bones", rootSize = { 1.56, 1.77, 1.02 }, hipHeight = 1.94, height = 4.77, walkSpeed = 7.2 },
	desertMummy = { rig = "bones", rootSize = { 1.34, 1.86, 0.88 }, hipHeight = 2.03, height = 5.33, walkSpeed = 8.0 },
	dragonspawn = { rig = "bones", rootSize = { 1.70, 1.77, 1.11 }, hipHeight = 1.94, height = 5.18, walkSpeed = 7.8 },
	flameSmith = { rig = "bones", rootSize = { 2.00, 1.86, 1.29 }, hipHeight = 2.03, height = 4.73, walkSpeed = 7.1 },
	darkCultist = { rig = "bones", rootSize = { 1.49, 1.77, 0.97 }, hipHeight = 2.15, height = 5.85, walkSpeed = 8.8 },
	renegadeDwarf = { rig = "bones", rootSize = { 2.07, 1.36, 1.34 }, hipHeight = 1.45, height = 4.12, walkSpeed = 6.2 },
	koboldMiner = { rig = "bones", rootSize = { 1.41, 1.53, 1.22 }, hipHeight = 1.37, height = 3.45, walkSpeed = 5.2 },
	fireImp = { rig = "bones", rootSize = { 1.34, 1.19, 0.88 }, hipHeight = 1.26, height = 4.08, walkSpeed = 6.1 },
	forestWraith = { rig = "bones", rootSize = { 1.83, 2.91, 1.50 }, hipHeight = 2.75, height = 6.33, walkSpeed = 9.5 },
	hrimvald = { rig = "bones", rootSize = { 2.58, 2.95, 1.66 }, hipHeight = 3.29, height = 8.79, walkSpeed = 13.2 },
	frostGiant = { rig = "bones", rootSize = { 2.29, 2.78, 1.48 }, hipHeight = 3.10, height = 6.91, walkSpeed = 10.4 },
	goblinShaman = { rig = "bones", rootSize = { 1.34, 1.31, 0.88 }, hipHeight = 1.43, height = 4.65, walkSpeed = 7.0 },
	grimrok = { rig = "bones", rootSize = { 2.29, 1.61, 1.48 }, hipHeight = 1.75, height = 5.40, walkSpeed = 8.1 },
	frozenKnight = { rig = "bones", rootSize = { 1.78, 1.94, 1.16 }, hipHeight = 2.13, height = 5.00, walkSpeed = 7.5 },
	fireGolem = { rig = "bones", rootSize = { 2.58, 2.75, 2.08 }, hipHeight = 1.27, height = 4.58, walkSpeed = 6.9 },
	marshWitch = { rig = "bones", rootSize = { 1.41, 1.91, 1.27 }, hipHeight = 2.20, height = 6.05, walkSpeed = 9.1 },
	necromancer = { rig = "bones", rootSize = { 1.41, 1.77, 0.93 }, hipHeight = 2.15, height = 5.18, walkSpeed = 7.8 },
	azgor = { rig = "bones", rootSize = { 2.58, 3.00, 2.10 }, hipHeight = 1.42, height = 5.70, walkSpeed = 8.6 },
	ashOrc = { rig = "bones", rootSize = { 2.07, 1.97, 1.34 }, hipHeight = 2.17, height = 5.01, walkSpeed = 7.5 },
	skeletonGuard = { rig = "bones", rootSize = { 1.56, 1.77, 1.02 }, hipHeight = 1.94, height = 4.82, walkSpeed = 7.2 },
	swampTroll = { rig = "bones", rootSize = { 2.60, 3.09, 2.92 }, hipHeight = 1.74, height = 4.72, walkSpeed = 7.1 },
	morvane = { rig = "bones", rootSize = { 1.49, 2.03, 0.97 }, hipHeight = 2.47, height = 6.79, walkSpeed = 10.2 },
	werewolf = { rig = "bones", rootSize = { 2.20, 2.85, 2.60 }, hipHeight = 1.49, height = 4.98, walkSpeed = 7.5 },
	yeti = { rig = "bones", rootSize = { 2.70, 3.22, 3.03 }, hipHeight = 1.59, height = 4.76, walkSpeed = 7.1 },
	crystalGuardian = {
		rig = "bones",
		rootSize = { 3.08, 2.58, 3.08 },
		hipHeight = 1.36,
		height = 5.10,
		walkSpeed = 7.6,
	},
	goblinScout = { rig = "bones", rootSize = { 1.34, 1.27, 0.88 }, hipHeight = 1.36, height = 3.67, walkSpeed = 5.5 },
	magmaGolem = { rig = "bones", rootSize = { 2.58, 3.12, 2.12 }, hipHeight = 1.49, height = 5.16, walkSpeed = 7.7 },
	wolf = { rig = "static", rootSize = { 1.56, 1.34, 2.91 }, hipHeight = 1.06, height = 3.39, walkSpeed = 5.1 },
	boar = { rig = "static", rootSize = { 1.94, 1.77, 3.02 }, hipHeight = 0.70, height = 2.74, walkSpeed = 4.1 },
	wasteHyena = { rig = "static", rootSize = { 1.56, 1.72, 3.05 }, hipHeight = 0.97, height = 3.70, walkSpeed = 5.6 },
	iceMammoth = { rig = "static", rootSize = { 2.91, 2.69, 3.99 }, hipHeight = 1.72, height = 4.97, walkSpeed = 7.5 },
	youngFrostDragon = {
		rig = "static",
		rootSize = { 1.82, 1.61, 3.23 },
		hipHeight = 1.17,
		height = 3.83,
		walkSpeed = 5.7,
	},
	wyvern = { rig = "static", rootSize = { 1.86, 1.61, 3.23 }, hipHeight = 1.17, height = 3.63, walkSpeed = 5.4 },
	peakHarpy = { rig = "static", rootSize = { 1.40, 1.72, 1.18 }, hipHeight = 3.54, height = 6.20, walkSpeed = 9.3 },
	ashVulture = { rig = "static", rootSize = { 1.23, 1.18, 1.83 }, hipHeight = 2.88, height = 5.02, walkSpeed = 7.5 },
	iceElemental = { rig = "static", rootSize = { 1.61, 1.94, 1.61 }, hipHeight = 2.78, height = 5.00, walkSpeed = 7.5 },
	basilisk = { rig = "static", rootSize = { 1.94, 1.34, 3.56 }, hipHeight = 0.38, height = 2.04, walkSpeed = 3.1 },
	desertScorpion = {
		rig = "static",
		rootSize = { 1.94, 0.96, 2.15 },
		hipHeight = 0.33,
		height = 3.14,
		walkSpeed = 4.7,
	},
	bloodBat = { rig = "static", rootSize = { 1.07, 1.29, 1.07 }, hipHeight = 2.76, height = 5.13, walkSpeed = 7.7 },
	carrionCrow = { rig = "static", rootSize = { 1.23, 1.18, 1.83 }, hipHeight = 2.88, height = 4.33, walkSpeed = 6.5 },
	bogSerpent = { rig = "static", rootSize = { 1.40, 1.04, 1.72 }, hipHeight = 0.10, height = 1.60, walkSpeed = 2.4 },
	swampToad = { rig = "static", rootSize = { 2.26, 1.56, 2.15 }, hipHeight = 0.17, height = 2.02, walkSpeed = 3.0 },
	rotEnt = { rig = "static", rootSize = { 1.94, 4.64, 1.94 }, hipHeight = 0.61, height = 6.88, walkSpeed = 10.3 },
	salamander = { rig = "static", rootSize = { 1.40, 1.02, 2.91 }, hipHeight = 0.36, height = 1.71, walkSpeed = 2.6 },
	caveSpider = { rig = "static", rootSize = { 1.50, 1.02, 1.50 }, hipHeight = 0.54, height = 2.35, walkSpeed = 3.5 },
	lynx = { rig = "static", rootSize = { 1.56, 1.34, 2.91 }, hipHeight = 1.06, height = 3.61, walkSpeed = 5.4 },
	rabbit = { rig = "static", rootSize = { 1.50, 1.34, 1.94 }, hipHeight = 0.28, height = 2.96, walkSpeed = 4.4 },
}

return MonsterAssets
