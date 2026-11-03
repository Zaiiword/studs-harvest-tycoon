--!strict
-- Déplacements hors engin et accès à l'engin (A54), sans API Roblox : on marche dans la base, on court sur le
-- boulevard, et l'engin n'apparaît qu'en entrant dans le champ.
local MapConfig = require("../config/MapConfig")
local VehicleConfig = require("../config/VehicleConfig")
local MapGeometry = require("./MapGeometry")

local Movement = {}

local STEM, MOAT = MapConfig.STEM, MapConfig.MOAT

-- Vitesse à pied : celle de l'outil (Tiers 1-2) ou FOOT_SPEED (engin garé), -10 % sac plein (CDC §4), ×3 sur la route.
function Movement.walkSpeed(tier: VehicleConfig.TierDef, isBagFull: boolean, isOnRoad: boolean): number
	local speed = if tier.isVehicle then VehicleConfig.FOOT_SPEED else tier.speed
	local penalty = if isBagFull then VehicleConfig.FULL_SPEED_PENALTY else 0
	return speed * (1 - penalty) * (if isOnRoad then MapConfig.ROAD.SPEED_MULTIPLIER else 1)
end

-- On monte en entrant dans le champ. On ne descend qu'après avoir retraversé le pont : le retour, sac plein,
-- reste une zone d'embuscade (CDC §3), et un engin ne clignote pas à la frontière.
function Movement.shouldRide(x: number, z: number, isRiding: boolean): boolean
	if x >= STEM.minX and MapGeometry.zoneAt(x, z) ~= nil then
		return true
	end
	return isRiding and x >= MOAT.minX - MapConfig.BRIDGE_OVERLAP
end

return Movement
