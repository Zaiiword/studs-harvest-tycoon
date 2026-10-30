--!strict
-- Construit la carte concentrique dans Workspace à partir de MapGeometry/MapConfig (aucune pièce posée à la main).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)

local MapService = {}

local function color(name: string): Color3
	local rgb = MapConfig.ZONE_COLORS[name]
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function newPart(name: string, size: Vector3, cframe: CFrame, colorName: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color(colorName)
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.MaterialVariant = MapConfig.STUDS_MATERIAL_VARIANT
	part.Parent = parent
	return part
end

-- Pose une pièce plate dont la face supérieure est à `top`, orientée selon la direction radiale (yaw = -angle).
local function slab(
	name: string,
	x: number,
	z: number,
	angle: number,
	top: number,
	sizeX: number,
	sizeZ: number,
	colorName: string,
	parent: Instance
): Part
	local thickness = MapConfig.GROUND_THICKNESS
	local cframe = CFrame.new(x, top - thickness / 2, z) * CFrame.Angles(0, -angle, 0)
	return newPart(name, Vector3.new(sizeX, thickness, sizeZ), cframe, colorName, parent)
end

local function disc(zone: MapConfig.ZoneDef, parent: Instance)
	local top = MapConfig.LAYER_ELEVATION[zone.id]
	local part = newPart(
		zone.id,
		Vector3.new(MapConfig.GROUND_THICKNESS, zone.outerRadius * 2, zone.outerRadius * 2),
		CFrame.new(0, top - MapConfig.GROUND_THICKNESS / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		zone.id,
		parent
	)
	part.Shape = Enum.PartType.Cylinder
	part.TopSurface = Enum.SurfaceType.Smooth
end

local function buildRings(map: Folder)
	local rings = Instance.new("Folder")
	rings.Name = "Rings"
	rings.Parent = map

	-- Du plus grand au plus petit, chaque disque recouvre le précédent : l'altitude croissante évite le z-fighting.
	for i = #MapConfig.ZONES, 1, -1 do
		local zone = MapConfig.ZONES[i]
		if MapConfig.LAYER_ELEVATION[zone.id] and zone.id ~= "Crown" then
			disc(zone, rings)
		end
	end
end

local function buildCrown(map: Folder)
	local crownZone = MapGeometry.zone("Crown")
	local crown = Instance.new("Folder")
	crown.Name = "Crown"
	crown.Parent = map
	for _, segment in
		MapGeometry.annulusSegments(crownZone.innerRadius, crownZone.outerRadius, MapConfig.CROWN_SEGMENTS)
	do
		slab(
			`CrownSegment{segment.index}`,
			segment.x,
			segment.z,
			segment.angle,
			MapConfig.LAYER_ELEVATION.Crown,
			segment.depth,
			segment.arc,
			"Crown",
			crown
		)
	end
end

local function buildMoatFloor(map: Folder)
	local moat = MapGeometry.zone("Moat")
	local floor = newPart(
		"MoatFloor",
		Vector3.new(MapConfig.GROUND_THICKNESS, moat.outerRadius * 2, moat.outerRadius * 2),
		CFrame.new(0, MapConfig.MOAT_FLOOR_ELEVATION - MapConfig.GROUND_THICKNESS / 2, 0)
			* CFrame.Angles(0, 0, math.pi / 2),
		"Moat",
		map
	)
	floor.Shape = Enum.PartType.Cylinder
	floor.TopSurface = Enum.SurfaceType.Smooth
end

local function buildBridges(map: Folder)
	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = map
	for _, bridge in MapGeometry.bridges() do
		slab(
			`Bridge{bridge.index}`,
			bridge.x,
			bridge.z,
			bridge.angle,
			MapConfig.LAYER_ELEVATION.Crown,
			bridge.length,
			bridge.width,
			"BridgeAndBase",
			bridges
		)
	end
end

local function buildBases(map: Folder)
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = map
	for _, base in MapGeometry.baseCenters() do
		local floor = slab(
			`Base{base.index}`,
			base.x,
			base.z,
			base.angle,
			MapConfig.LAYER_ELEVATION.Crown + 0.2,
			MapConfig.BASE_SIZE,
			MapConfig.BASE_SIZE,
			"BridgeAndBase",
			bases
		)
		floor:SetAttribute("BaseIndex", base.index)
	end
end

function MapService:Init()
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"

	buildMoatFloor(map)
	buildCrown(map)
	buildRings(map)
	buildBridges(map)
	buildBases(map)

	map.Parent = Workspace
end

return MapService
