--!strict
-- Ciblage et force des objets de sabotage (CDC §6, A13, A41), sans API Roblox.
-- Les cibles protégées (immunité, tournis, zone sécurisée) sont toujours ignorées.
local SabotageConfig = require("../config/SabotageConfig")
local Bumper = require("./Bumper")

local Sabotage = {}

local GRAVITY = 196.2 -- gravité Roblox par défaut (studs/s²)

-- Vitesses (horizontale, verticale) pour qu'une éjection parcoure à peu près `distance` studs au sol.
-- Vol balistique : durée = 2 V / g, distance = H × durée.
function Sabotage.launchForDistance(distance: number): (number, number)
	local vertical = SabotageConfig.EJECT_VERTICAL_SPEED
	return distance * GRAVITY / (2 * vertical), vertical
end

local function distance(a: Bumper.Body, b: Bumper.Body): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Gant de Boxe : la cible non protégée la plus proche, au contact.
function Sabotage.gloveTarget(user: Bumper.Body, others: { Bumper.Body }): Bumper.Body?
	local best: Bumper.Body? = nil
	local bestDistance = SabotageConfig.GLOVE.RANGE + user.radius
	for _, other in others do
		local d = distance(user, other) - other.radius
		if other.id ~= user.id and not other.isProtected and d <= bestDistance then
			best, bestDistance = other, d
		end
	end
	return best
end

-- Bazooka : la cible non protégée la plus proche dans un cône devant le joueur (la ligne de vue est
-- vérifiée par le serveur avec un raycast).
function Sabotage.bazookaTarget(user: Bumper.Body, dirX: number, dirZ: number, others: { Bumper.Body }): Bumper.Body?
	local length = math.sqrt(dirX * dirX + dirZ * dirZ)
	if length < 1e-6 then
		return nil
	end
	local cosLimit = math.cos(math.rad(SabotageConfig.BAZOOKA.CONE_DEGREES))
	local best: Bumper.Body? = nil
	local bestDistance = SabotageConfig.BAZOOKA.RANGE
	for _, other in others do
		local d = distance(user, other)
		local cos = if d > 1e-6 then ((other.x - user.x) * dirX + (other.z - user.z) * dirZ) / (d * length) else 1
		if other.id ~= user.id and not other.isProtected and d <= bestDistance and cos >= cosLimit then
			best, bestDistance = other, d
		end
	end
	return best
end

-- Onde de Choc : toutes les cibles non protégées dans le rayon autour du Blé Arc-en-ciel, sauf le lanceur.
function Sabotage.dynamiteTargets(
	centerX: number,
	centerZ: number,
	userId: number,
	others: { Bumper.Body }
): { Bumper.Body }
	local targets: { Bumper.Body } = {}
	for _, other in others do
		local d = math.sqrt((other.x - centerX) ^ 2 + (other.z - centerZ) ^ 2)
		if other.id ~= userId and not other.isProtected and d <= SabotageConfig.DYNAMITE.RADIUS then
			table.insert(targets, other)
		end
	end
	return targets
end

return Sabotage
