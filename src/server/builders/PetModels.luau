--!strict
-- Couvoir et distributeurs d'œufs en Lego (CDC §7.2 « des distributeurs d'œufs bordent la base ») : un bouton au sol,
-- où le joueur marche pour faire éclore, et derrière un œuf géant dans sa caisse de paille, sous un panneau nom + prix au style des
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
local HATCHERY = PetVisualConfig.HATCHERY
local PAD_THICKNESS = 0.4
local EGG_LABEL_GAP = 3 -- panneau au-dessus de l'œuf géant

export type Placement = { padCFrame: CFrame, eggCFrame: CFrame } -- au niveau du plancher de la base

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function priceText(egg: PetConfig.EggDef): string
	return `{Format.money(egg.price)} {if egg.currency == "gems" then "💎" else "$"}`
end

local function decorBlock(parent: Instance, spec: Build.BlockSpec): Part
	local part = Build.block(parent, spec)
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	return part
end

-- Terrasse dallée, bordure, haie et enseigne : le couvoir existe dès le départ, les œufs s'y ajoutent ensuite.
-- `origin` : centre de la base, au niveau du sol.
function PetModels.hatchery(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Hatchery"
	local top = MapConfig.DECK_TOP
	local width, depth = HATCHERY.MAX_X - HATCHERY.MIN_X, HATCHERY.MAX_Z - HATCHERY.MIN_Z
	local centerX, centerZ = (HATCHERY.MIN_X + HATCHERY.MAX_X) / 2, (HATCHERY.MIN_Z + HATCHERY.MAX_Z) / 2
	local rows = math.ceil(depth / HATCHERY.ROW_DEPTH)
	for row = 1, rows do
		local rowDepth = depth / rows
		decorBlock(model, {
			name = "Tiles",
			cframe = origin * CFrame.new(centerX, top + 0.1, HATCHERY.MIN_Z + (row - 0.5) * rowDepth),
			size = Vector3.new(width, 0.2, rowDepth),
			color = HATCHERY.COLORS[row % #HATCHERY.COLORS + 1],
		})
	end
	for _, side in { -1, 1 } do
		decorBlock(model, {
			name = "Border",
			cframe = origin * CFrame.new(centerX + side * (width / 2 + 0.3), top + 0.25, centerZ),
			size = Vector3.new(0.6, 0.5, depth + 1.2),
			color = HATCHERY.BORDER_COLOR,
		})
	end
	decorBlock(model, {
		name = "Border",
		cframe = origin * CFrame.new(centerX, top + 0.25, HATCHERY.MAX_Z + 0.3),
		size = Vector3.new(width, 0.5, 0.6),
		color = HATCHERY.BORDER_COLOR,
	})
	decorBlock(model, {
		name = "Hedge",
		cframe = origin * CFrame.new(centerX, top + HATCHERY.HEDGE_HEIGHT / 2, HATCHERY.MIN_Z - 0.75),
		size = Vector3.new(width + 1.2, HATCHERY.HEDGE_HEIGHT, 1.5),
		color = HATCHERY.HEDGE_COLOR,
	})
	local signWidth, signHeight = HATCHERY.SIGN_SIZE[1], HATCHERY.SIGN_SIZE[2]
	for _, side in { -1, 1 } do
		decorBlock(model, {
			name = "SignPost",
			cframe = origin * CFrame.new(
				centerX + side * (signWidth / 2 - 1),
				top + HATCHERY.SIGN_POST_HEIGHT / 2,
				HATCHERY.MIN_Z - 0.75
			),
			size = Vector3.new(0.8, HATCHERY.SIGN_POST_HEIGHT, 0.8),
			color = HATCHERY.SIGN_COLOR,
		})
	end
	local board = decorBlock(model, {
		name = "Sign",
		cframe = origin * CFrame.new(centerX, top + HATCHERY.SIGN_POST_HEIGHT, HATCHERY.MIN_Z - 0.75),
		size = Vector3.new(signWidth, signHeight, 0.5),
		color = HATCHERY.SIGN_COLOR,
	})
	Build.sign(board, Enum.NormalId.Back, HATCHERY.SIGN_TEXT, { 255, 255, 255 })
	model.Parent = parent
end

function PetModels.dispenser(parent: Instance?, egg: PetConfig.EggDef, placement: Placement): Model
	local model = Instance.new("Model")
	model.Name = egg.id
	local lift = Vector3.new(0, MapConfig.DECK_TOP, 0)
	Build.block(model, {
		name = "Rim",
		cframe = placement.padCFrame + lift + Vector3.new(0, PAD_THICKNESS / 4, 0),
		size = Vector3.new(PetConfig.DISPENSER_SIZE + 1.2, PAD_THICKNESS / 2, PetConfig.DISPENSER_SIZE + 1.2),
		color = DISPENSER.RIM_COLOR,
	})
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
	Build.block(model, {
		name = "Straw",
		cframe = placement.eggCFrame + lift + Vector3.new(0, baseSize.Y + 0.2, 0),
		size = Vector3.new(baseSize.X - 1, 0.4, baseSize.Z - 1),
		color = DISPENSER.STRAW_COLOR,
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
