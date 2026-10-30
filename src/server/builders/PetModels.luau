--!strict
-- Distributeurs d'œufs en Lego (CDC §7.2 « des distributeurs d'œufs bordent la base ») : un bouton au sol, où le
-- joueur marche pour faire éclore, et à côté un œuf géant sur son socle, avec le prix et les chances de chaque
-- rareté (transparence, A42).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local PetVisualConfig = require(ReplicatedStorage.Shared.config.PetVisualConfig)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Build = require(script.Parent.Build)

local PetModels = {}

local DISPENSER = PetVisualConfig.DISPENSER
local PAD_THICKNESS = 0.4

export type Placement = { padCFrame: CFrame, eggCFrame: CFrame } -- au niveau du plancher de la base

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

-- Texte de l'étiquette : nom, prix, puis chaque rareté possible avec sa chance.
function PetModels.dispenserLabel(egg: PetConfig.EggDef): string
	local currency = if egg.currency == "gems" then "💎" else "$"
	local lines = { `{egg.name} · {Format.money(egg.price)} {currency}` }
	for _, rarity in PetConfig.RARITIES do
		local weight = egg.odds[rarity.id]
		if weight then
			table.insert(lines, `{rarity.name} {weight} %`)
		end
	end
	return table.concat(lines, "\n")
end

local function attachLabel(part: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 120)
	gui.StudsOffset = Vector3.new(0, DISPENSER.EGG_SIZE[2] / 2 + 3, 0)
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = part
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
	attachLabel(shell, PetModels.dispenserLabel(egg))
	model.PrimaryPart = shell
	model.Parent = parent
	return model
end

return PetModels
