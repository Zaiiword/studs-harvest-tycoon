--!strict
-- Distributeurs d'œufs en Lego (CDC §7.2 « des distributeurs d'œufs bordent la base ») : un bouton au sol, où le
-- joueur marche pour faire éclore, et à côté un œuf géant sur son socle, sous un panneau nom + prix au style des
-- boutons de l'usine. Les chances de chaque rareté (A42) sont dans le menu 🐾, onglet Œufs : la base reste lisible.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local PetVisualConfig = require(ReplicatedStorage.Shared.config.PetVisualConfig)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Build = require(script.Parent.Build)
local TycoonButtons = require(script.Parent.TycoonButtons)

local PetModels = {}

local DISPENSER = PetVisualConfig.DISPENSER
local PAD_THICKNESS = 0.4
local EGG_LABEL_GAP = 3 -- panneau au-dessus de l'œuf géant

export type Placement = { padCFrame: CFrame, eggCFrame: CFrame } -- au niveau du plancher de la base

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function priceText(egg: PetConfig.EggDef): string
	return `{Format.money(egg.price)} {if egg.currency == "gems" then "💎" else "$"}`
end

function PetModels.dispenser(parent: Instance, egg: PetConfig.EggDef, placement: Placement): Model
	local model = Instance.new("Model")
	model.Name = egg.id
	local lift = Vector3.new(0, MapConfig.DECK_TOP, 0)
	Build.block(model, {
		name = "Pad",
		cframe = placement.padCFrame + lift + Vector3.new(0, PAD_THICKNESS / 2, 0),
		size = Vector3.new(PetConfig.DISPENSER_SIZE, PAD_THICKNESS, PetConfig.DISPENSER_SIZE),
		color = egg.color,
	})
	local baseSize = vector(DISPENSER.BASE_SIZE)
	Build.block(model, {
		name = "Socle",
		cframe = placement.eggCFrame + lift + Vector3.new(0, baseSize.Y / 2, 0),
		size = baseSize,
		color = DISPENSER.BASE_COLOR,
	})
	local eggSize = vector(DISPENSER.EGG_SIZE)
	local shell = Build.block(model, {
		name = "Egg",
		cframe = placement.eggCFrame + lift + Vector3.new(0, baseSize.Y + eggSize.Y / 2, 0),
		size = eggSize,
		color = egg.color,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- la sphère épouse la taille de la pièce : un œuf étiré
	mesh.Parent = shell
	local label = TycoonButtons.label(shell, "🥚", DISPENSER.EGG_SIZE[2] / 2 + EGG_LABEL_GAP)
	TycoonButtons.paint(label, "egg", egg.name, priceText(egg))
	model.PrimaryPart = shell
	model.Parent = parent
	return model
end

return PetModels
