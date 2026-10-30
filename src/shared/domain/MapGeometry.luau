--!strict
-- Géométrie pure de la carte (aucune API Roblox) : positions des bases et des ponts, zones par rayon.
-- Convention : un angle θ place un point en (r·cosθ, r·sinθ) sur le plan (x, z). L'axe local X d'une pièce
-- pointe dans la direction radiale ; son yaw Roblox vaut donc -θ.

local MapConfig = require("../config/MapConfig")

export type Placement = {
	index: number,
	x: number,
	z: number,
	angle: number, -- radians
}

export type BridgePlacement = Placement & {
	length: number,
	width: number,
}

export type Segment = Placement & {
	depth: number, -- épaisseur radiale
	arc: number, -- longueur tangentielle
}

local MapGeometry = {}

local TWO_PI = 2 * math.pi

local function polar(index: number, radius: number, angle: number): Placement
	return { index = index, x = radius * math.cos(angle), z = radius * math.sin(angle), angle = angle }
end

local function zoneById(id: string): MapConfig.ZoneDef
	for _, zone in MapConfig.ZONES do
		if zone.id == id then
			return zone
		end
	end
	error(`zone inconnue : {id}`)
end

function MapGeometry.zone(id: string): MapConfig.ZoneDef
	return zoneById(id)
end

function MapGeometry.baseCenters(): { Placement }
	local bases: { Placement } = {}
	local step = TWO_PI / MapConfig.BASE_COUNT
	local start = math.rad(MapConfig.BASE_START_ANGLE_DEG)
	for i = 1, MapConfig.BASE_COUNT do
		table.insert(bases, polar(i, MapConfig.BASE_RADIUS, start + (i - 1) * step))
	end
	return bases
end

-- Un pont va de l'anneau Blé Vert à la couronne en recouvrant chaque rive de BRIDGE_OVERLAP studs.
function MapGeometry.bridges(): { BridgePlacement }
	local moat = zoneById("Moat")
	local inner = moat.innerRadius - MapConfig.BRIDGE_OVERLAP
	local outer = moat.outerRadius + MapConfig.BRIDGE_OVERLAP
	local mid = (inner + outer) / 2
	local step = TWO_PI / MapConfig.BRIDGE_COUNT
	local start = math.rad(MapConfig.BRIDGE_START_ANGLE_DEG)

	local bridges: { BridgePlacement } = {}
	for i = 1, MapConfig.BRIDGE_COUNT do
		local placement = polar(i, mid, start + (i - 1) * step) :: any
		placement.length = outer - inner
		placement.width = MapConfig.BRIDGE_WIDTH
		table.insert(bridges, placement :: BridgePlacement)
	end
	return bridges
end

-- Découpe un anneau en segments rectangulaires (Roblox n'a pas de pièce annulaire).
function MapGeometry.annulusSegments(innerRadius: number, outerRadius: number, count: number): { Segment }
	assert(count >= 3, "un anneau demande au moins 3 segments")
	assert(outerRadius > innerRadius, "outerRadius doit dépasser innerRadius")
	local mid = (innerRadius + outerRadius) / 2
	local step = TWO_PI / count
	-- La corde est élargie pour que les segments voisins se recouvrent côté extérieur sans trou.
	local arc = 2 * outerRadius * math.tan(step / 2)

	local segments: { Segment } = {}
	for i = 1, count do
		local placement = polar(i, mid, (i - 1) * step) :: any
		placement.depth = outerRadius - innerRadius
		placement.arc = arc
		table.insert(segments, placement :: Segment)
	end
	return segments
end

-- Id de la zone qui contient le point (x, z). Les rayons sont semi-ouverts : [inner, outer).
function MapGeometry.zoneAt(x: number, z: number): string?
	local radius = math.sqrt(x * x + z * z)
	for _, zone in MapConfig.ZONES do
		if radius >= zone.innerRadius and radius < zone.outerRadius then
			return zone.id
		end
	end
	return nil
end

return MapGeometry
