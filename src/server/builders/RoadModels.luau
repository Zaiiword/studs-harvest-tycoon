--!strict
-- Boulevard de la barre du T (A54) : asphalte, raccords vers les ponts, ligne centrale en pointillés, bordures de
-- course, néons, drapeaux et arches « VERS LE CHAMP ». Placement calculé par Decor et MapGeometry (purs, testés).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DecorConfig = require(ReplicatedStorage.Shared.config.DecorConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local Decor = require(ReplicatedStorage.Shared.domain.Decor)
local Build = require(script.Parent.Build)

local RoadModels = {}

local ROAD, STYLE = MapConfig.ROAD, DecorConfig.ROAD
local TOP = MapConfig.DECK_TOP
local THICKNESS = MapConfig.GROUND_THICKNESS
local PAINT_HEIGHT = 0.06 -- peinture au sol : juste au-dessus de l'asphalte, sans le toucher à fleur
local PILLAR = 2
local WHITE = { 248, 248, 248 }
local CLOTH = Vector3.new(0.2, 3, 5)

-- Tout ce qui décore la route ne gêne ni le joueur ni les requêtes physiques.
local function ghost(part: Part): Part
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	return part
end

local function neon(part: Part): Part
	part.Material = Enum.Material.Neon
	return ghost(part)
end

local function asphalt(parent: Instance, center: Vector3, sizeX: number, sizeZ: number)
	Build.block(parent, {
		name = "Asphalt",
		cframe = CFrame.new(center.X, TOP - THICKNESS / 2, center.Z),
		size = Vector3.new(sizeX, THICKNESS, sizeZ),
		color = STYLE.COLOR,
	})
end

local function buildSurface(parent: Instance)
	local centerX = (ROAD.minX + ROAD.maxX) / 2
	local width = ROAD.maxX - ROAD.minX
	asphalt(parent, Vector3.new(centerX, 0, 0), width, ROAD.halfLength * 2)
	-- Raccord du boulevard jusqu'au tablier de chaque pont.
	local bridgeEnd = MapConfig.MOAT.minX - MapConfig.BRIDGE_OVERLAP
	for _, z in MapConfig.BRIDGE_Z do
		asphalt(parent, Vector3.new((ROAD.maxX + bridgeEnd) / 2, 0, z), bridgeEnd - ROAD.maxX, MapConfig.BRIDGE_WIDTH)
	end
	for _, side in { -1, 1 } do
		local strip = STYLE.NEON
		neon(Build.block(parent, {
			name = "NeonEdge",
			cframe = CFrame.new(centerX + side * (width / 2 - strip.inset), TOP + PAINT_HEIGHT, 0),
			size = Vector3.new(strip.width, PAINT_HEIGHT, ROAD.halfLength * 2),
			color = strip.color,
		}))
	end
end

local function buildMarkings(parent: Instance)
	local centerX = (ROAD.minX + ROAD.maxX) / 2
	local dash = STYLE.DASH
	for _, z in Decor.roadDashes() do
		ghost(Build.block(parent, {
			name = "Dash",
			cframe = CFrame.new(centerX, TOP + PAINT_HEIGHT, z),
			size = Vector3.new(dash.width, PAINT_HEIGHT, dash.length),
			color = STYLE.LINE_COLOR,
		}))
	end
	local curb = STYLE.CURB
	for _, spot in Decor.roadCurbs() do
		ghost(Build.block(parent, {
			name = "Curb",
			cframe = CFrame.new(spot.x, TOP + curb.height / 2, spot.z),
			size = Vector3.new(curb.width, curb.height, curb.length),
			color = curb.colors[spot.colorIndex],
		}))
	end
end

local function buildFlags(parent: Instance)
	local flag = STYLE.FLAG
	for index, spot in Decor.roadFlags() do
		ghost(Build.block(parent, {
			name = "FlagPole",
			cframe = CFrame.new(spot.x, TOP + flag.height / 2, spot.z),
			size = Vector3.new(0.5, flag.height, 0.5),
			color = WHITE,
		}))
		ghost(Build.block(parent, {
			name = "FlagCloth",
			cframe = CFrame.new(spot.x, TOP + flag.height - CLOTH.Y / 2, spot.z + CLOTH.Z / 2),
			size = CLOTH,
			color = flag.colors[index % #flag.colors + 1],
		}))
	end
end

-- Arche à l'entrée de chaque pont, lisible dans les deux sens.
local function buildArch(parent: Instance, z: number)
	local arch = STYLE.ARCH
	local halfSpan = MapConfig.BRIDGE_WIDTH / 2 + PILLAR
	for _, side in { -1, 1 } do
		Build.block(parent, {
			name = "ArchPillar",
			cframe = CFrame.new(arch.x, TOP + arch.height / 2, z + side * halfSpan),
			size = Vector3.new(PILLAR, arch.height, PILLAR),
			color = arch.color,
		})
	end
	local beam = Build.block(parent, {
		name = "ArchBeam",
		cframe = CFrame.new(arch.x, TOP + arch.height + arch.beamHeight / 2, z),
		size = Vector3.new(PILLAR, arch.beamHeight, halfSpan * 2 + PILLAR),
		color = arch.color,
	})
	Build.sign(beam, Enum.NormalId.Left, arch.toField, WHITE)
	Build.sign(beam, Enum.NormalId.Right, arch.toBases, WHITE)
	neon(Build.block(parent, {
		name = "ArchNeon",
		cframe = CFrame.new(arch.x, TOP + arch.height - 0.2, z),
		size = Vector3.new(PILLAR + 0.2, 0.4, halfSpan * 2 + PILLAR),
		color = arch.neon,
	}))
end

function RoadModels.build(parent: Instance)
	buildSurface(parent)
	buildMarkings(parent)
	buildFlags(parent)
	for _, z in MapConfig.BRIDGE_Z do
		buildArch(parent, z)
	end
end

return RoadModels
