--!strict
-- Hotspot dynamique (CDC §3, A11), sans API Roblox : zone ronde à valeur ×3 tirée dans le Blé Diamant.
local EventConfig = require("../config/EventConfig")
local MapConfig = require("../config/MapConfig")
local MapGeometry = require("./MapGeometry")

export type Spot = { x: number, z: number }

local Hotspot = {}

local HOTSPOT = EventConfig.HOTSPOT

function Hotspot.pick(rng: () -> number): Spot
	local band = MapGeometry.bandOf(HOTSPOT.BAND)
	local margin = HOTSPOT.RADIUS
	local fromX = MapConfig.STEM.minX + band.startDistance + margin
	local toX = MapConfig.STEM.minX + band.endDistance - margin
	local x = fromX + (toX - fromX) * rng()
	local halfWidth = MapGeometry.stemHalfWidth(x) * HOTSPOT.LATERAL_FILL
	return { x = x, z = (rng() * 2 - 1) * halfWidth }
end

function Hotspot.contains(spot: Spot?, x: number, z: number): boolean
	if not spot then
		return false
	end
	return (x - spot.x) ^ 2 + (z - spot.z) ^ 2 <= HOTSPOT.RADIUS ^ 2
end

return Hotspot
