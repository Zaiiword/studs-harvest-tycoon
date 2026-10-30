--!strict
-- Géométrie pure de la carte (CDC §3, aucune API Roblox) : réseau de cellules, zones, bases, ponts, sol.
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

-- Une rangée de cellules contiguës d'une même zone, posée comme une seule brique de sol.
export type FloorRun = {
	zone: string,
	x: number,
	z: number,
	sizeX: number,
	sizeZ: number,
}

local MapGeometry = {}

local TWO_PI = 2 * math.pi

local function polar(index: number, radius: number, angle: number): Placement
	return { index = index, x = radius * math.cos(angle), z = radius * math.sin(angle), angle = angle }
end

function MapGeometry.zone(id: string): MapConfig.ZoneDef
	for _, zone in MapConfig.ZONES do
		if zone.id == id then
			return zone
		end
	end
	error(`zone inconnue : {id}`)
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

-- Centre monde de la cellule (i, j) d'un réseau de `gridSize` cellules par côté, centré sur l'origine.
-- Avec un gridSize pair, tous les réseaux de même CELL_SIZE sont alignés entre eux.
function MapGeometry.cellCenter(gridSize: number, i: number, j: number): (number, number)
	local offset = (gridSize + 1) / 2
	return (i - offset) * MapConfig.CELL_SIZE, (j - offset) * MapConfig.CELL_SIZE
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

-- Vrai si (x, z) est sur l'emprise carrée de la base, orientée vers le centre.
function MapGeometry.isInsideBase(base: Placement, x: number, z: number): boolean
	local dx, dz = x - base.x, z - base.z
	local radial = dx * math.cos(base.angle) + dz * math.sin(base.angle)
	local lateral = -dx * math.sin(base.angle) + dz * math.cos(base.angle)
	local half = MapConfig.BASE_SIZE / 2
	return math.abs(radial) <= half and math.abs(lateral) <= half
end

-- Un pont va de l'anneau Blé Vert à la couronne en recouvrant chaque rive de BRIDGE_OVERLAP studs.
function MapGeometry.bridges(): { BridgePlacement }
	local moat = MapGeometry.zone("Moat")
	local inner = moat.innerRadius - MapConfig.BRIDGE_OVERLAP
	local outer = moat.outerRadius + MapConfig.BRIDGE_OVERLAP
	local step = TWO_PI / MapConfig.BRIDGE_COUNT
	local start = math.rad(MapConfig.BRIDGE_START_ANGLE_DEG)

	local bridges: { BridgePlacement } = {}
	for i = 1, MapConfig.BRIDGE_COUNT do
		local placement = polar(i, (inner + outer) / 2, start + (i - 1) * step) :: any
		placement.length = outer - inner
		placement.width = MapConfig.BRIDGE_WIDTH
		table.insert(bridges, placement :: BridgePlacement)
	end
	return bridges
end

-- Vrai si (x, z), élargi de `margin`, touche l'emprise d'un pont. Sert à ne pas faire pousser de blé dessous.
function MapGeometry.isUnderBridge(x: number, z: number, margin: number): boolean
	for _, bridge in MapGeometry.bridges() do
		local dx, dz = x - bridge.x, z - bridge.z
		local along = dx * math.cos(bridge.angle) + dz * math.sin(bridge.angle)
		local lateral = -dx * math.sin(bridge.angle) + dz * math.cos(bridge.angle)
		if math.abs(along) <= bridge.length / 2 + margin and math.abs(lateral) <= bridge.width / 2 + margin then
			return true
		end
	end
	return false
end

local function closeRun(runs: { FloorRun }, zone: string, firstI: number, lastI: number, j: number)
	local gridSize = MapConfig.MAP_GRID_SIZE
	local x1, z = MapGeometry.cellCenter(gridSize, firstI, j)
	local x2 = MapGeometry.cellCenter(gridSize, lastI, j)
	local cell = MapConfig.CELL_SIZE
	table.insert(runs, { zone = zone, x = (x1 + x2) / 2, z = z, sizeX = x2 - x1 + cell, sizeZ = cell })
end

-- Découpe le sol en rangées : chaque ligne du réseau devient quelques briques (une par zone traversée).
-- Les zones vides (fossé) et l'extérieur de la carte ne reçoivent pas de sol.
function MapGeometry.floorRuns(): { FloorRun }
	local gridSize = MapConfig.MAP_GRID_SIZE
	local runs: { FloorRun } = {}
	for j = 1, gridSize do
		local currentZone: string? = nil
		local firstI = 0
		for i = 1, gridSize + 1 do
			local zone: string? = nil
			if i <= gridSize then
				local x, z = MapGeometry.cellCenter(gridSize, i, j)
				zone = MapGeometry.zoneAt(x, z)
				if zone and MapConfig.VOID_ZONES[zone] then
					zone = nil
				end
			end
			if zone ~= currentZone then
				if currentZone then
					closeRun(runs, currentZone, firstI, i - 1, j)
				end
				currentZone, firstI = zone, i
			end
		end
	end
	return runs
end

return MapGeometry
