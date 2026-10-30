--!strict
-- Rendu d'une plante du champ à partir des formes de PlantConfig (A36, A39). Deux pools de pièces
-- pré-créées (détaillé / simple) : on ne fait jamais d'Instance.new pendant le jeu (docs/CLEAN_CODE.md §5).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local PlantConfig = require(ReplicatedStorage.Shared.config.PlantConfig)
local Decor = require(ReplicatedStorage.Shared.domain.Decor)
local FieldGrid = require(ReplicatedStorage.Shared.domain.FieldGrid)
local Rarity = require(ReplicatedStorage.Shared.domain.Rarity)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

export type Kind = "detailed" | "simple"
export type Plant = { kind: Kind, parts: { Part } }

local PlantRenderer = {}

local PARKED = CFrame.new(0, -1000, 0)
local WHITE = { 255, 255, 255 }

local pools: { [Kind]: { Plant } } = { detailed = {}, simple = {} }

local function shaded(rgb: { number }, shade: number): Color3
	local color = Bricks.rgb(rgb)
	return Color3.new(math.min(1, color.R * shade), math.min(1, color.G * shade), math.min(1, color.B * shade))
end

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

-- Crée `count` plantes de chaque niveau de détail, rangées sous `parent`.
function PlantRenderer.init(parent: Instance, detailedCount: number, simpleCount: number)
	local counts: { [Kind]: number } = { detailed = detailedCount, simple = simpleCount }
	local pieces: { [Kind]: number } = { detailed = PlantConfig.DETAILED_PIECES, simple = PlantConfig.SIMPLE_PIECES }
	for kind, count in counts do
		for k = 1, count do
			local plant: Plant = { kind = kind, parts = {} }
			for p = 1, pieces[kind] do
				local part = Bricks.decor(`{kind}{k}_{p}`, Vector3.one, WHITE)
				part.Transparency = 1
				part.CFrame = PARKED
				part.Parent = parent
				table.insert(plant.parts, part)
			end
			table.insert(pools[kind], plant)
		end
	end
end

function PlantRenderer.acquire(kind: Kind): Plant?
	return table.remove(pools[kind])
end

function PlantRenderer.hide(plant: Plant)
	for _, part in plant.parts do
		part.Transparency = 1
	end
end

function PlantRenderer.release(plant: Plant)
	PlantRenderer.hide(plant)
	for _, part in plant.parts do
		part.CFrame = PARKED
	end
	table.insert(pools[plant.kind], plant)
end

-- Pose la plante de la cellule `index` : forme de sa bande, taille de sa rareté, et une variation propre
-- (hauteur, orientation, inclinaison, teinte) pour que le champ ne ressemble pas à une grille.
function PlantRenderer.render(plant: Plant, index: number, cell: FieldGrid.Cell)
	local shapes = PlantConfig.SHAPES[cell.zone]
	local shape = if plant.kind == "detailed" then shapes.detailed else shapes.simple
	local colors = PlantConfig.COLORS[cell.zone]
	local variation = Decor.stalkVariation(index)
	local scale = Rarity.byId(cell.rarity).sizeMultiplier
	local stretch = Vector3.new(scale, scale * variation.heightScale, scale)
	local foot = CFrame.new(cell.x, MapConfig.FLOOR_TOP, cell.z)
		* CFrame.Angles(0, variation.yaw, 0)
		* CFrame.Angles(variation.lean, 0, 0)
	local isRainbow = cell.rarity == Rarity.RAINBOW
	local earMaterial = PlantConfig.EAR_MATERIAL[cell.zone]
	for p, part in plant.parts do
		local piece = shape[p]
		if not piece then
			part.Transparency = 1 -- forme plus simple que le nombre de pièces du pool
			continue
		end
		local tilt = piece.tilt or { 0, 0, 0 }
		part.Size = vector(piece.size) * stretch
		part.CFrame = foot * CFrame.new(vector(piece.offset) * stretch) * CFrame.Angles(tilt[1], tilt[2], tilt[3])
		part.Color = shaded(colors[piece.role], variation.shade)
		local isEar = piece.role == "ear"
		part.Material = if isEar and isRainbow
			then Enum.Material.Neon
			elseif isEar and earMaterial then (Enum.Material :: any)[earMaterial]
			else Enum.Material.Plastic
		part.Transparency = 0
	end
end

-- Arc-en-ciel : la couleur des épis tourne sur la roue chromatique.
function PlantRenderer.paintEars(plant: Plant, cell: FieldGrid.Cell, color: Color3)
	local shapes = PlantConfig.SHAPES[cell.zone]
	local shape = if plant.kind == "detailed" then shapes.detailed else shapes.simple
	for p, part in plant.parts do
		local piece = shape[p]
		if piece and piece.role == "ear" then
			part.Color = color
		end
	end
end

return PlantRenderer
