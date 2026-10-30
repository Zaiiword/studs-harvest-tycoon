--!strict
-- Géométrie pure de la carte en T (CDC §3, décision A21 ; aucune API Roblox) : réseaux de cellules,
-- zones, bases, ponts et découpage du sol en briques.
-- Convention : `angle` est le cap de l'axe local X d'une pièce sur le plan (x, z) ; son yaw Roblox vaut -angle.

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

local PLAZA, MOAT, STEM = MapConfig.PLAZA, MapConfig.MOAT, MapConfig.STEM
local TOWARD_FIELD = 0 -- cap +X : des bases vers le champ

-- Centre monde de la cellule (i, j) d'un réseau : i le long de X, j le long de Z.
function MapGeometry.cellCenter(lattice: MapConfig.Lattice, i: number, j: number): (number, number)
	local cell = MapConfig.CELL_SIZE
	return lattice.minX + (i - 0.5) * cell, lattice.minZ + (j - 0.5) * cell
end

-- Demi-largeur de la tige à l'abscisse x : elle se rétrécit linéairement vers le bout du champ.
function MapGeometry.stemHalfWidth(x: number): number
	local progress = math.clamp((x - STEM.minX) / (STEM.maxX - STEM.minX), 0, 1)
	return STEM.startHalfWidth + (STEM.endHalfWidth - STEM.startHalfWidth) * progress
end

local function stemBandAt(x: number): string?
	local distance = x - STEM.minX
	for _, band in MapConfig.STEM_BANDS do
		if distance >= band.startDistance and distance < band.endDistance then
			return band.id
		end
	end
	return nil
end

-- Id de la zone qui contient le point (x, z), ou nil hors de la carte. Bornes semi-ouvertes [min, max).
function MapGeometry.zoneAt(x: number, z: number): string?
	if x >= PLAZA.minX and x < PLAZA.maxX then
		return if math.abs(z) < PLAZA.halfWidth then "Plaza" else nil
	end
	if x >= MOAT.minX and x < MOAT.maxX then
		return if math.abs(z) < PLAZA.halfWidth then "Moat" else nil
	end
	if x >= STEM.minX and x < STEM.maxX and math.abs(z) < MapGeometry.stemHalfWidth(x) then
		return stemBandAt(x)
	end
	return nil
end

function MapGeometry.bandOf(id: string): MapConfig.BandDef
	for _, band in MapConfig.STEM_BANDS do
		if band.id == id then
			return band
		end
	end
	error(`bande inconnue : {id}`)
end

-- Bases alignées sur la barre du T, centrées en Z, tournées vers le champ.
function MapGeometry.baseCenters(): { Placement }
	local bases: { Placement } = {}
	local firstZ = -(MapConfig.BASE_COUNT - 1) * MapConfig.BASE_PITCH / 2
	for i = 1, MapConfig.BASE_COUNT do
		local z = firstZ + (i - 1) * MapConfig.BASE_PITCH
		table.insert(bases, { index = i, x = MapConfig.BASE_CENTER_X, z = z, angle = TOWARD_FIELD })
	end
	return bases
end

-- Vrai si (x, z) est sur l'emprise carrée de la base.
function MapGeometry.isInsideBase(base: Placement, x: number, z: number): boolean
	local dx, dz = x - base.x, z - base.z
	local along = dx * math.cos(base.angle) + dz * math.sin(base.angle)
	local lateral = -dx * math.sin(base.angle) + dz * math.cos(base.angle)
	local half = MapConfig.BASE_SIZE / 2
	return math.abs(along) <= half and math.abs(lateral) <= half
end

-- Chaque pont traverse le fossé et recouvre chaque rive de BRIDGE_OVERLAP studs.
function MapGeometry.bridges(): { BridgePlacement }
	local length = MOAT.maxX - MOAT.minX + 2 * MapConfig.BRIDGE_OVERLAP
	local centerX = (MOAT.minX + MOAT.maxX) / 2
	local bridges: { BridgePlacement } = {}
	for i, z in MapConfig.BRIDGE_Z do
		table.insert(bridges, {
			index = i,
			x = centerX,
			z = z,
			angle = TOWARD_FIELD,
			length = length,
			width = MapConfig.BRIDGE_WIDTH,
		})
	end
	return bridges
end

-- Vrai si (x, z), élargi de `margin`, touche l'emprise d'un pont. Sert à ne pas faire pousser de blé dessous.
function MapGeometry.isUnderBridge(x: number, z: number, margin: number): boolean
	for _, bridge in MapGeometry.bridges() do
		local dx, dz = x - bridge.x, z - bridge.z
		if math.abs(dx) <= bridge.length / 2 + margin and math.abs(dz) <= bridge.width / 2 + margin then
			return true
		end
	end
	return false
end

-- Les rangées suivent l'axe Z : une colonne i du réseau devient quelques briques (une par zone traversée).
local function closeRun(runs: { FloorRun }, zone: string, i: number, firstJ: number, lastJ: number)
	local lattice = MapConfig.MAP_LATTICE
	local x, z1 = MapGeometry.cellCenter(lattice, i, firstJ)
	local _, z2 = MapGeometry.cellCenter(lattice, i, lastJ)
	local cell = MapConfig.CELL_SIZE
	table.insert(runs, { zone = zone, x = x, z = (z1 + z2) / 2, sizeX = cell, sizeZ = z2 - z1 + cell })
end

local function floorZoneAt(i: number, j: number): string?
	local x, z = MapGeometry.cellCenter(MapConfig.MAP_LATTICE, i, j)
	local zone = MapGeometry.zoneAt(x, z)
	return if zone and not MapConfig.VOID_ZONES[zone] then zone else nil
end

-- Découpe le sol en briques. Les zones vides (fossé) et l'extérieur de la carte ne reçoivent pas de sol.
function MapGeometry.floorRuns(): { FloorRun }
	local lattice = MapConfig.MAP_LATTICE
	local runs: { FloorRun } = {}
	for i = 1, lattice.cols do
		local currentZone: string? = nil
		local firstJ = 0
		for j = 1, lattice.rows + 1 do
			local zone = if j <= lattice.rows then floorZoneAt(i, j) else nil
			if zone ~= currentZone then
				if currentZone then
					closeRun(runs, currentZone, i, firstJ, j - 1)
				end
				currentZone, firstJ = zone, j
			end
		end
	end
	return runs
end

return MapGeometry
