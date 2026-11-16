--!strict
-- Couvoir et distributeurs d'œufs en Lego (CDC §7.2 « des distributeurs d'œufs bordent la base ») : un bouton au sol,
-- où le joueur marche pour faire éclore, et derrière un œuf géant dans sa caisse de paille, sous un panneau nom + prix au style des
-- boutons de l'usine. Les chances de chaque rareté (A42) sont dans le menu 🐾, onglet Œufs : la base reste lisible.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local IconConfig = require(ReplicatedStorage.Shared.config.IconConfig)
local PetVisualConfig = require(ReplicatedStorage.Shared.config.PetVisualConfig)
local SceneryConfig = require(ReplicatedStorage.Shared.config.SceneryConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local EggModel = require(ReplicatedStorage.Shared.util.EggModel)
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
	return `{Format.money(egg.price)} {if egg.currency == "gems" then "gemmes" else "$"}`
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
			cframe = origin
				* CFrame.new(centerX, top + HATCHERY.TILE_HEIGHT / 2, HATCHERY.MIN_Z + (row - 0.5) * rowDepth),
			size = Vector3.new(width, HATCHERY.TILE_HEIGHT, rowDepth),
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

-- Couronne de brins de paille et halo lumineux sous l'œuf.
local function buildNest(model: Model, strawTop: CFrame, glow: { number })
	for k = 1, DISPENSER.NEST_TWIGS do
		local angle = k * 2 * math.pi / DISPENSER.NEST_TWIGS
		local twig = decorBlock(model, {
			name = "Twig",
			cframe = strawTop
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(DISPENSER.NEST_RADIUS, 0.45, 0)
				* CFrame.Angles(0, math.rad(20), math.rad(if k % 2 == 0 then 12 else -8)),
			size = Vector3.new(1.1, 0.9, 2.3),
			color = if k % 2 == 0 then DISPENSER.STRAW_COLOR else DISPENSER.STRAW_DARK_COLOR,
		})
		twig.CastShadow = false
	end
	local halo = decorBlock(model, {
		name = "Halo",
		cframe = strawTop * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2),
		size = Vector3.new(0.2, DISPENSER.HALO_DIAMETER, DISPENSER.HALO_DIAMETER),
		color = glow,
	})
	halo.Shape = Enum.PartType.Cylinder
	halo.Material = Enum.Material.Neon
	halo.CastShadow = false
end

-- Lueur et étincelles de la couleur de l'œuf.
local function decorateShell(shell: BasePart, glow: { number })
	local light = Instance.new("PointLight")
	light.Color = Bricks.rgb(glow)
	light.Range, light.Brightness = DISPENSER.LIGHT_RANGE, DISPENSER.LIGHT_BRIGHTNESS
	light.Parent = shell
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = DISPENSER.SPARKLE_TEXTURE
	sparkles.Rate = DISPENSER.SPARKLE_RATE
	sparkles.Lifetime = NumberRange.new(1, 1.8)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparkles.LightEmission = 0.8
	sparkles.Color = ColorSequence.new(Bricks.rgb(glow))
	sparkles.Parent = shell
end

function PetModels.dispenser(parent: Instance?, egg: PetConfig.EggDef, placement: Placement): Model
	local model = Instance.new("Model")
	model.Name = egg.id
	local lift = Vector3.new(0, MapConfig.DECK_TOP, 0)
	Build.block(model, {
		name = "Rim",
		cframe = placement.padCFrame + lift + Vector3.new(0, DISPENSER.RIM_HEIGHT / 2, 0),
		size = Vector3.new(PetConfig.DISPENSER_SIZE + 1.2, DISPENSER.RIM_HEIGHT, PetConfig.DISPENSER_SIZE + 1.2),
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
	local strawTop = placement.eggCFrame + lift + Vector3.new(0, baseSize.Y + 0.4, 0)
	buildNest(model, strawTop, EggModel.glowColor(egg.id))
	local eggSize = vector(DISPENSER.EGG_SIZE)
	local body =
		EggModel.build(egg.id, egg.color, eggSize, strawTop + Vector3.new(0, DISPENSER.EGG_HOVER + eggSize.Y / 2, 0))
	local shell = body.PrimaryPart :: BasePart
	decorateShell(shell, EggModel.glowColor(egg.id))
	-- L'œuf flotte et se dandine : animé par chaque client (SceneryFxController), comme les canards du fossé.
	body.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	body:SetAttribute(SceneryConfig.BOB_HEIGHT, DISPENSER.BOB.height)
	body:SetAttribute(SceneryConfig.BOB_PERIOD, DISPENSER.BOB.period)
	body:SetAttribute(SceneryConfig.BOB_TILT, DISPENSER.BOB.tilt)
	body:SetAttribute(SceneryConfig.BOB_ROAM, 0)
	CollectionService:AddTag(body, SceneryConfig.BOB_TAG)
	body.Parent = model
	local label = TycoonButtons.label(shell, IconConfig.EGG_PREFIX .. egg.id, DISPENSER.EGG_SIZE[2] / 2 + EGG_LABEL_GAP)
	TycoonButtons.paint(label, "egg", egg.name, priceText(egg))
	model.PrimaryPart = shell
	model.Parent = parent
	return model
end

return PetModels
