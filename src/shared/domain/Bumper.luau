--!strict
-- Détection et résolution des chocs entre joueurs (CDC §5 « Knockback serveur », §6), sans API Roblox.
-- Le serveur décrit chaque joueur par un Body à 10 Hz ; Bumper décide qui éjecte qui et à quelle vitesse.
local BumperConfig = require("../config/BumperConfig")
local Formulas = require("./Formulas")

export type Body = {
	id: number,
	x: number,
	z: number,
	vx: number,
	vz: number,
	radius: number,
	mass: number, -- masse effective (Formulas.effectiveMass)
	isVehicle: boolean,
	isProtected: boolean, -- immunité, tournis en cours ou zone sécurisée
}

export type Collision = {
	attackerId: number,
	targetId: number,
	impactSpeed: number,
	dirX: number, -- direction d'éjection (de l'attaquant vers la cible), normalisée
	dirZ: number,
}

local Bumper = {}

function Bumper.isSafeZone(zone: string?): boolean
	return zone ~= nil and BumperConfig.SAFE_ZONES[zone] == true
end

-- L'attaquant est celui qui fonce le plus vers l'autre ; il doit être motorisé (décision A29).
-- La vitesse d'impact est la vitesse relative de rapprochement le long de l'axe des centres.
function Bumper.detect(a: Body, b: Body): Collision?
	local dx, dz = b.x - a.x, b.z - a.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-6 or distance > a.radius + b.radius + BumperConfig.CONTACT_MARGIN then
		return nil
	end
	local nx, nz = dx / distance, dz / distance
	local aToward = a.vx * nx + a.vz * nz
	local bToward = -(b.vx * nx + b.vz * nz)
	local attacker, target = a, b
	if bToward > aToward then
		attacker, target, nx, nz = b, a, -nx, -nz
	end
	local impact = aToward + bToward
	if not attacker.isVehicle or target.isProtected or impact < BumperConfig.MIN_IMPACT_SPEED then
		return nil
	end
	return { attackerId = attacker.id, targetId = target.id, impactSpeed = impact, dirX = nx, dirZ = nz }
end

-- Vitesses d'éjection (horizontale, verticale) en studs/s, d'après la formule du CDC §5 (décision A30).
function Bumper.launchSpeeds(impactSpeed: number, attackerMass: number, targetMass: number): (number, number)
	local force = Formulas.knockbackForce(impactSpeed, attackerMass, targetMass, BumperConfig.BUMPER_BONUS)
	local horizontal =
		math.clamp(force * BumperConfig.LAUNCH_SCALE, BumperConfig.MIN_LAUNCH_SPEED, BumperConfig.MAX_LAUNCH_SPEED)
	return horizontal, horizontal * BumperConfig.VERTICAL_RATIO
end

return Bumper
