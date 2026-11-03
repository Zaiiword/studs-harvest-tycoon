--!strict
-- Machines de l'usine en briques (CDC §7.1 : Moulin, Four, Usine ; A56 : Séchoir, Presse, Emballeuse à l'étage).
-- `origin` : centre du pied de la machine, axe X local tourné vers le champ (vers les boutons).
-- Les ailes du moulin forment un Model « MillBlades » que le client fait tourner (TycoonAnimController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local Build = require(script.Parent.Build)

local TycoonModels = {}

TycoonModels.BLADES_NAME = "MillBlades"

local ROOF_COLOR = { 196, 40, 28 }
local DARK_COLOR = { 27, 42, 53 }
local STONE_COLOR = { 99, 95, 98 }
local WINDOW_COLOR = { 128, 230, 255 }
local BLADE_COLOR = { 124, 92, 70 }

type Builder = (model: Model, origin: CFrame, size: number, color: { number }) -> Part

local function buildMill(model: Model, origin: CFrame, size: number, color: { number }): Part
	local towerHeight = size * 1.4
	local tower = Build.block(model, {
		name = "Tower",
		cframe = origin * CFrame.new(0, towerHeight / 2, 0),
		size = Vector3.new(size * 0.8, towerHeight, size * 0.8),
		color = color,
	})
	Build.block(model, {
		name = "Roof",
		cframe = origin * CFrame.new(0, towerHeight + 1, 0),
		size = Vector3.new(size, 2, size),
		color = ROOF_COLOR,
	})
	local blades = Instance.new("Model")
	blades.Name = TycoonModels.BLADES_NAME
	local hubCFrame = origin * CFrame.new(size * 0.45, towerHeight * 0.75, 0)
	local hub =
		Build.block(blades, { name = "Hub", cframe = hubCFrame, size = Vector3.new(1, 2, 2), color = DARK_COLOR })
	for name, size3 in { BladeA = Vector3.new(0.4, size * 1.6, 1.4), BladeB = Vector3.new(0.4, 1.4, size * 1.6) } do
		Build.block(
			blades,
			{ name = name, cframe = hubCFrame * CFrame.new(0.5, 0, 0), size = size3, color = BLADE_COLOR }
		)
	end
	blades.PrimaryPart = hub
	blades.Parent = model
	return tower
end

local function buildOven(model: Model, origin: CFrame, size: number, color: { number }): Part
	local height = size * 0.7
	local body = Build.block(model, {
		name = "Body",
		cframe = origin * CFrame.new(0, height / 2, 0),
		size = Vector3.new(size, height, size),
		color = color,
	})
	Build.block(model, {
		name = "Door",
		cframe = origin * CFrame.new(size / 2 + 0.2, height * 0.35, 0),
		size = Vector3.new(0.4, height * 0.5, size * 0.4),
		color = DARK_COLOR,
	})
	Build.block(model, {
		name = "Chimney",
		cframe = origin * CFrame.new(-size / 4, height + 2.5, size / 4),
		size = Vector3.new(2, 5, 2),
		color = STONE_COLOR,
	})
	return body
end

local function buildFactory(model: Model, origin: CFrame, size: number, color: { number }): Part
	local width, height = size * 1.3, size * 1.1
	local body = Build.block(model, {
		name = "Body",
		cframe = origin * CFrame.new(0, height / 2, 0),
		size = Vector3.new(size, height, width),
		color = color,
	})
	Build.block(model, {
		name = "Windows",
		cframe = origin * CFrame.new(size / 2 + 0.2, height * 0.6, 0),
		size = Vector3.new(0.4, 2, width * 0.8),
		color = WINDOW_COLOR,
	})
	for _, side in { -1, 1 } do
		Build.block(model, {
			name = "Chimney",
			cframe = origin * CFrame.new(-size / 4, height + 4, side * width / 4),
			size = Vector3.new(2.5, 8, 2.5),
			color = STONE_COLOR,
		})
	end
	return body
end

-- Séchoir : deux tambours couchés sur un bâti, cheminée de vapeur.
local function buildDryer(model: Model, origin: CFrame, size: number, color: { number }): Part
	local body = Build.block(model, {
		name = "Body",
		cframe = origin * CFrame.new(0, 1, 0),
		size = Vector3.new(size, 2, size),
		color = STONE_COLOR,
	})
	for _, side in { -1, 1 } do
		local drum = Build.block(model, {
			name = "Drum",
			cframe = origin * CFrame.new(0, 4, side * size * 0.24),
			size = Vector3.new(size * 0.9, size * 0.42, size * 0.42),
			color = color,
		})
		drum.Shape = Enum.PartType.Cylinder
	end
	Build.block(model, {
		name = "Chimney",
		cframe = origin * CFrame.new(-size / 4, 7, 0),
		size = Vector3.new(1.4, 4, 1.4),
		color = DARK_COLOR,
	})
	return body
end

-- Presse : portique et plateau, gros vérin au centre.
local function buildPress(model: Model, origin: CFrame, size: number, color: { number }): Part
	local body = Build.block(model, {
		name = "Body",
		cframe = origin * CFrame.new(0, 1.2, 0),
		size = Vector3.new(size, 2.4, size),
		color = color,
	})
	for _, side in { -1, 1 } do
		Build.block(model, {
			name = "Column",
			cframe = origin * CFrame.new(0, 5, side * (size / 2 - 0.8)),
			size = Vector3.new(1.6, 6, 1.6),
			color = DARK_COLOR,
		})
	end
	Build.block(model, {
		name = "Head",
		cframe = origin * CFrame.new(0, 8.6, 0),
		size = Vector3.new(size, 1.6, size),
		color = color,
	})
	Build.block(model, {
		name = "Ram",
		cframe = origin * CFrame.new(0, 5.6, 0),
		size = Vector3.new(3, 4.4, 3),
		color = STONE_COLOR,
	})
	return body
end

-- Emballeuse : table à colis dorés, sous une hotte vitrée.
local function buildPacker(model: Model, origin: CFrame, size: number, color: { number }): Part
	local body = Build.block(model, {
		name = "Body",
		cframe = origin * CFrame.new(0, 1.5, 0),
		size = Vector3.new(size, 3, size),
		color = DARK_COLOR,
	})
	for _, spot in { { -2, -2 }, { 2, -2 }, { 0, 1.8 } } do
		Build.block(model, {
			name = "Box",
			cframe = origin * CFrame.new(spot[1], 4, spot[2]),
			size = Vector3.new(2.2, 2, 2.2),
			color = color,
		})
	end
	local hood = Build.block(model, {
		name = "Hood",
		cframe = origin * CFrame.new(0, 8, 0),
		size = Vector3.new(size, 1, size),
		color = WINDOW_COLOR,
	})
	hood.Transparency = 0.3
	return body
end

local BUILDERS: { [string]: Builder } = {
	Mill = buildMill,
	Oven = buildOven,
	Factory = buildFactory,
	Dryer = buildDryer,
	Press = buildPress,
	Packer = buildPacker,
}

-- Goulotte qui relie le tapis roulant à la machine.
local function buildChute(model: Model, origin: CFrame, size: number, length: number)
	Build.block(model, {
		name = "Chute",
		cframe = origin * CFrame.new(-(size / 2 + length / 2), 1.2, 0),
		size = Vector3.new(length + 1, 0.5, 3),
		color = STONE_COLOR,
	})
end

-- Construit la machine et renvoie sa pièce principale (qui porte l'étiquette). Le modèle n'a pas de parent :
-- l'appelant le place après l'avoir horodaté.
function TycoonModels.machine(machine: TycoonConfig.MachineDef, origin: CFrame): Part
	local model = Instance.new("Model")
	model.Name = machine.id
	local size = machine.size or TycoonConfig.LAYOUT.MACHINE_SIZE
	local main = BUILDERS[machine.id](model, origin, size, machine.color)
	if machine.chute then
		buildChute(model, origin, size, machine.chute)
	end
	model.PrimaryPart = main
	return main
end

-- Toit rouge posé sur le silo ; repositionné à chaque changement de hauteur.
function TycoonModels.siloRoof(parent: Instance, radius: number): Part
	local roof = Build.block(parent, {
		name = "SiloRoof",
		cframe = CFrame.new(),
		size = Vector3.one * (radius * 2 + 1),
		color = ROOF_COLOR,
	})
	roof.Shape = Enum.PartType.Ball
	return roof
end

return TycoonModels
