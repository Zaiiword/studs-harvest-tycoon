--!strict
-- Machines de l'usine en briques (CDC §7.1 : Moulin, Four, Usine), posées sur la base.
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

local BUILDERS: { [string]: Builder } = {
	Mill = buildMill,
	Oven = buildOven,
	Factory = buildFactory,
}

-- Construit la machine et renvoie sa pièce principale (qui porte l'étiquette).
function TycoonModels.machine(parent: Instance?, machine: TycoonConfig.MachineDef, origin: CFrame): Part
	local model = Instance.new("Model")
	model.Name = machine.id
	local main = BUILDERS[machine.id](model, origin, TycoonConfig.LAYOUT.MACHINE_SIZE, machine.color)
	model.PrimaryPart = main
	model.Parent = parent
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
