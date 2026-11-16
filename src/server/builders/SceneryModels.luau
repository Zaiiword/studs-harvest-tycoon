--!strict
-- Modèles du paysage en briques (A69) : collines et montagnes en gradins, arbres de plusieurs essences, moulins,
-- îles, phare, voiliers, montgolfières, nuages, canards, nénuphars. Tout est décoratif : aucune collision, aucune
-- requête physique. Les ailes des moulins forment un Model « MillBlades » que le client fait déjà tourner
-- (TycoonAnimController) ; ce qui flotte ou dérive porte une étiquette lue par SceneryFxController.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local SceneryConfig = require(ReplicatedStorage.Shared.config.SceneryConfig)
local Scenery = require(ReplicatedStorage.Shared.domain.Scenery)
local Build = require(script.Parent.Build)
local TycoonModels = require(script.Parent.TycoonModels)

local SceneryModels = {}

local TREE = SceneryConfig.TREE
local WATER_TOP = MapConfig.WATER_TOP
local BLACK = { 27, 42, 53 }
local WHITE = { 248, 248, 248 }
local QUARTER = math.pi / 2

local function ghost(part: Part): Part
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	return part
end

-- Brique décorative : `cframe` est le centre de la brique.
local function piece(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: { number }): Part
	return ghost(Build.block(parent, { name = name, cframe = cframe, size = size, color = color }))
end

local function smooth(part: Part): Part
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.LeftSurface, part.RightSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.FrontSurface, part.BackSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return part
end

local function neon(part: Part): Part
	smooth(part).Material = Enum.Material.Neon
	return part
end

local function cylinder(part: Part): Part
	part.Shape = Enum.PartType.Cylinder
	return smooth(part)
end

local function model(parent: Instance, name: string): Model
	local created = Instance.new("Model")
	created.Name = name
	created.Parent = parent
	return created
end

-- Modèle animé par le client : envoyé d'un bloc avec ses pièces, pour que son pivot soit connu à l'arrivée.
local function animated(created: Model, primary: BasePart, tag: string, bob: SceneryConfig.Bob?, roam: number?)
	created.PrimaryPart = primary
	created.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if bob then
		created:SetAttribute(SceneryConfig.BOB_HEIGHT, bob.height)
		created:SetAttribute(SceneryConfig.BOB_PERIOD, bob.period)
		created:SetAttribute(SceneryConfig.BOB_TILT, bob.tilt)
		created:SetAttribute(SceneryConfig.BOB_ROAM, roam or 0)
	end
	CollectionService:AddTag(created, tag)
end

local function colorOf(palette: { { number } }, index: number): { number }
	return palette[(index - 1) % #palette + 1]
end

---------------------------------------------------------------------------------------------------------------
-- Arbres
---------------------------------------------------------------------------------------------------------------

local function trunk(parent: Instance, base: CFrame, width: number, height: number, color: { number })
	piece(parent, "Trunk", base * CFrame.new(0, height / 2, 0), Vector3.new(width, height, width), color)
end

local function pine(parent: Instance, base: CFrame, scale: number, leaf: { number })
	trunk(parent, base, 2 * scale, 6 * scale, TREE.TRUNK_COLOR)
	local layers = { { 9, 7 }, { 7, 9.8 }, { 4.5, 12.4 }, { 2, 14.6 } }
	for _, layer in layers do
		local size = layer[1] * scale
		piece(parent, "Leaves", base * CFrame.new(0, layer[2] * scale, 0), Vector3.new(size, 2.8 * scale, size), leaf)
	end
end

-- Houppier arrondi : un cube et deux dalles en croix, coiffés d'un petit cube.
local function round(parent: Instance, base: CFrame, scale: number, inner: { number }, outer: { number })
	trunk(parent, base, 2.4 * scale, 7 * scale, TREE.TRUNK_COLOR)
	local middle = base * CFrame.new(0, 10 * scale, 0)
	piece(parent, "Leaves", middle, Vector3.one * 8 * scale, inner)
	piece(parent, "Leaves", middle, Vector3.new(11, 5, 6.5) * scale, outer)
	piece(parent, "Leaves", middle, Vector3.new(6.5, 5, 11) * scale, outer)
	piece(parent, "Leaves", base * CFrame.new(0, 14.6 * scale, 0), Vector3.new(5, 2.6, 5) * scale, outer)
end

local function apples(parent: Instance, base: CFrame, scale: number)
	local spots = { { 4.4, 8.4, 2 }, { -4.4, 9, -1.5 }, { 1.5, 8.2, -4.4 }, { -2, 9.4, 4.4 }, { 3.4, 12.4, -3.4 } }
	for _, spot in spots do
		local offset = Vector3.new(spot[1], spot[2], spot[3]) * scale
		piece(parent, "Apple", base * CFrame.new(offset), Vector3.one * 1.3 * scale, TREE.APPLE_COLOR)
	end
end

local function palm(parent: Instance, base: CFrame, scale: number)
	local lean = base
	for k = 1, 4 do
		lean = lean * CFrame.Angles(0, 0, math.rad(4))
		piece(
			parent,
			"Trunk",
			lean * CFrame.new(0, (k - 0.5) * 3.2 * scale, 0),
			Vector3.new(1.6, 3.4, 1.6) * scale,
			TREE.PALM_TRUNK_COLOR
		)
	end
	local top = lean * CFrame.new(0, 13 * scale, 0)
	piece(parent, "Leaves", top, Vector3.one * 2 * scale, TREE.PALM_LEAF_COLOR)
	for k = 0, 4 do
		local frond = top * CFrame.Angles(0, k * math.rad(72), 0) * CFrame.Angles(0, 0, math.rad(-18))
		piece(
			parent,
			"Leaves",
			frond * CFrame.new(4.2 * scale, 0, 0),
			Vector3.new(7, 0.7, 2.4) * scale,
			TREE.PALM_LEAF_COLOR
		)
	end
end

-- `base` : pied de l'arbre. `shade` (0 à 1) choisit la nuance du feuillage.
function SceneryModels.tree(parent: Instance, kind: string, base: CFrame, scale: number, shade: number)
	local index = math.floor(shade * 12) + 1
	if kind == "pine" then
		pine(parent, base, scale, colorOf(TREE.LEAF_COLORS, index))
	elseif kind == "palm" then
		palm(parent, base, scale)
	elseif kind == "blossom" then
		round(parent, base, scale, colorOf(TREE.BLOSSOM_COLORS, index), colorOf(TREE.BLOSSOM_COLORS, index + 1))
	elseif kind == "autumn" then
		round(parent, base, scale, colorOf(TREE.AUTUMN_COLORS, index), colorOf(TREE.AUTUMN_COLORS, index + 1))
	else
		round(parent, base, scale, colorOf(TREE.LEAF_COLORS, index), colorOf(TREE.LEAF_COLORS, index + 1))
		if kind == "apple" then
			apples(parent, base, scale)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Collines, montagnes, volcan, îles
---------------------------------------------------------------------------------------------------------------

type TierColor = (tier: number, tiers: number) -> { number }

-- Empile `tiers` plaques carrées de plus en plus petites ; rend le centre du sommet et son demi-côté.
local function terraces(
	parent: Instance,
	base: CFrame,
	radius: number,
	tiers: number,
	tierHeight: number,
	sharpness: number,
	colorAt: TierColor
): (CFrame, number)
	local half = radius
	for tier = 1, tiers do
		half = radius * (1 - (tier - 1) / (tiers + 0.6)) ^ sharpness
		-- Une plaque sur deux est tournée d'un huitième de tour : la silhouette paraît taillée, pas pyramidale.
		local turn = if tier % 2 == 0 then math.rad(45) else 0
		local reach = if tier % 2 == 0 then half * 0.82 else half
		piece(
			parent,
			"Tier",
			base * CFrame.new(0, (tier - 0.5) * tierHeight, 0) * CFrame.Angles(0, turn, 0),
			Vector3.new(reach * 2, tierHeight, reach * 2),
			colorAt(tier, tiers)
		)
	end
	return base * CFrame.new(0, tiers * tierHeight, 0), half * 0.8
end

local function windmill(parent: Instance, base: CFrame)
	local config = SceneryConfig.WINDMILL
	local created = model(parent, "Windmill")
	local stage = config.HEIGHT / 3
	for k = 1, 3 do
		local width = config.WIDTH * (1 - (k - 1) * 0.17)
		piece(
			created,
			"Tower",
			base * CFrame.new(0, (k - 0.5) * stage, 0),
			Vector3.new(width, stage, width),
			config.TOWER_COLOR
		)
	end
	piece(created, "Roof", base * CFrame.new(0, config.HEIGHT + 1.5, 0), Vector3.new(9, 3, 9), config.ROOF_COLOR)
	piece(created, "Roof", base * CFrame.new(0, config.HEIGHT + 4, 0), Vector3.new(5, 2, 5), config.ROOF_COLOR)
	piece(created, "Door", base * CFrame.new(config.WIDTH / 2, 3, 0), Vector3.new(0.4, 6, 3.4), config.BLADE_COLOR)
	-- Les ailes tournent autour de l'axe X du moyeu (convention de TycoonAnimController).
	local blades = model(created, TycoonModels.BLADES_NAME)
	local hubFrame = base * CFrame.new(config.WIDTH / 2 - 0.4, config.HEIGHT - 4, 0)
	local hub = piece(blades, "Hub", hubFrame, Vector3.new(2.4, 2.4, 2.4), BLACK)
	for k = 0, 3 do
		local arm = hubFrame * CFrame.Angles(k * QUARTER, 0, 0)
		local length = config.BLADE_LENGTH
		piece(blades, "Arm", arm * CFrame.new(0.6, length / 2, 0), Vector3.new(0.6, length, 0.8), config.BLADE_COLOR)
		piece(
			blades,
			"Sail",
			arm * CFrame.new(0.6, length / 2 + 2.5, 2.2),
			Vector3.new(0.3, length - 5, 4.4),
			config.SAIL_COLOR
		)
	end
	blades.PrimaryPart = hub
	blades.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- Colline des berges, ou montagne enneigée au loin. Le moulin regarde le champ.
function SceneryModels.hill(parent: Instance, hill: Scenery.Hill)
	local created = model(parent, if hill.kind == "mountain" then "Mountain" else "Hill")
	local yaw = CFrame.Angles(0, math.rad(hill.yaw), 0)
	if hill.kind == "mountain" then
		local config = SceneryConfig.MOUNTAIN
		local base = CFrame.new(hill.x, WATER_TOP - 2, hill.z) * yaw
		terraces(created, base, hill.radius, hill.tiers, config.TIER_HEIGHT, 1.15, function(tier, tiers)
			if tier / tiers > config.SNOW_FROM then
				return config.SNOW_COLOR
			end
			return colorOf(if tier <= config.GRASS_TIERS then config.GRASS_COLORS else config.ROCK_COLORS, tier)
		end)
		return
	end
	local config = SceneryConfig.HILL
	local base = CFrame.new(hill.x, SceneryConfig.BANK.TOP, hill.z) * yaw
	local top, half = terraces(created, base, hill.radius, hill.tiers, config.TIER_HEIGHT, 0.8, function(tier)
		return colorOf(config.COLORS, tier + math.floor(hill.yaw))
	end)
	local summit = CFrame.new(top.Position)
	if hill.feature == "windmill" and half >= SceneryConfig.WINDMILL.WIDTH / 2 then
		-- L'axe X du moulin pointe vers le champ : -Z sur la berge +Z, +Z sur la berge -Z.
		windmill(created, summit * CFrame.Angles(0, hill.side * QUARTER, 0))
	else
		local spread = math.max(half - 4, 0)
		local kinds = { "round", "pine", "blossom" }
		for k = 1, 3 do
			local angle = math.rad(hill.yaw + k * 120)
			local foot = summit * CFrame.new(math.cos(angle) * spread * 0.6, 0, math.sin(angle) * spread * 0.6)
			SceneryModels.tree(created, kinds[(math.floor(hill.yaw) + k) % #kinds + 1], foot, 1.2, k / 3)
		end
	end
end

-- Volcan du Météore, derrière l'arène du boss, flanqué de deux montagnes sombres.
function SceneryModels.volcano(parent: Instance, x: number, baseY: number)
	local config = SceneryConfig.VOLCANO
	local created = model(parent, "Volcano")
	local function rock(tier: number): { number }
		return colorOf(config.ROCK_COLORS, tier)
	end
	local base = CFrame.new(x, baseY, 0)
	local top, half = terraces(created, base, config.RADIUS, config.TIERS, config.TIER_HEIGHT, 0.9, rock)
	local lava = neon(
		piece(created, "Lava", top * CFrame.new(0, 0.6, 0), Vector3.new(half * 1.6, 1.2, half * 1.6), config.LAVA_COLOR)
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(config.LAVA_COLOR[1], config.LAVA_COLOR[2], config.LAVA_COLOR[3])
	light.Range, light.Brightness = 60, 4
	light.Parent = lava
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 3
	smoke.Lifetime = NumberRange.new(14, 18)
	smoke.Speed = NumberRange.new(9, 13)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 22), NumberSequenceKeypoint.new(1, 70) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(110, 90, 100))
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.LightInfluence = 0.3
	smoke.Parent = lava
	-- Coulées de lave : deux bandes lumineuses qui descendent la face tournée vers le champ.
	for _, offset in { -0.35, 0.3 } do
		for tier = config.TIERS - 4, config.TIERS do
			local tierHalf = config.RADIUS * (1 - (tier - 1) / (config.TIERS + 0.6)) ^ 0.9
			local reach = if tier % 2 == 0 then tierHalf * 0.82 * math.sqrt(2) else tierHalf
			neon(
				piece(
					created,
					"LavaFlow",
					base * CFrame.new(-reach - 0.3, (tier - 0.5) * config.TIER_HEIGHT, offset * tierHalf),
					Vector3.new(0.6, config.TIER_HEIGHT, tierHalf * 0.22),
					config.LAVA_COLOR
				)
			)
		end
	end
	for _, flank in config.FLANKS do
		terraces(created, CFrame.new(x - 60, baseY, flank.z), flank.radius, flank.tiers, config.TIER_HEIGHT, 1.1, rock)
	end
end

function SceneryModels.island(
	parent: Instance,
	spot: { x: number, z: number, radius: number, tiers: number, palms: number }
)
	local config = SceneryConfig.ISLAND
	local created = model(parent, "Island")
	local base = CFrame.new(spot.x, WATER_TOP - 2, spot.z) * CFrame.Angles(0, math.rad(spot.x % 90), 0)
	local top, half = terraces(created, base, spot.radius, spot.tiers, config.TIER_HEIGHT, 0.9, function(tier)
		return if tier == 1 then config.SAND_COLOR else colorOf(SceneryConfig.HILL.COLORS, tier)
	end)
	for k = 1, spot.palms do
		local angle = k * 2 * math.pi / spot.palms + spot.z
		-- Les palmiers poussent sur la plage : au bord de la première plaque, les pieds dans le sable.
		local reach = if k % 2 == 0 then spot.radius * 0.86 else half * 0.5
		local height = if k % 2 == 0 then config.TIER_HEIGHT else spot.tiers * config.TIER_HEIGHT
		local foot = base * CFrame.new(math.cos(angle) * reach, height, math.sin(angle) * reach)
		SceneryModels.tree(created, "palm", foot * CFrame.Angles(0, angle, 0), 1.6, 0)
	end
	return top
end

function SceneryModels.lighthouse(parent: Instance)
	local config = SceneryConfig.LIGHTHOUSE
	local created = model(parent, "Lighthouse")
	local base = CFrame.new(config.x, WATER_TOP - 2, config.z)
	local top = terraces(created, base, config.ROCK_RADIUS, 2, 5, 0.8, function()
		return config.ROCK_COLOR
	end)
	local foot = CFrame.new(top.Position)
	for k = 1, config.STRIPES do
		local width = config.WIDTH * (1 - (k - 1) * 0.06)
		piece(
			created,
			"Stripe",
			foot * CFrame.new(0, (k - 0.5) * config.STRIPE_HEIGHT, 0),
			Vector3.new(width, config.STRIPE_HEIGHT, width),
			colorOf(config.COLORS, k)
		)
	end
	local height = config.STRIPES * config.STRIPE_HEIGHT
	piece(created, "Gallery", foot * CFrame.new(0, height + 0.5, 0), Vector3.new(13, 1, 13), BLACK)
	local lamp =
		neon(piece(created, "Lamp", foot * CFrame.new(0, height + 4, 0), Vector3.new(6, 6, 6), config.LAMP_COLOR))
	local light = Instance.new("PointLight")
	light.Color = lamp.Color
	light.Range, light.Brightness = 60, 3
	light.Parent = lamp
	piece(created, "Roof", foot * CFrame.new(0, height + 8, 0), Vector3.new(9, 2, 9), config.COLORS[1])
	piece(created, "Roof", foot * CFrame.new(0, height + 10, 0), Vector3.new(5, 2, 5), config.COLORS[1])
end

---------------------------------------------------------------------------------------------------------------
-- Ce qui flotte : voiliers, montgolfières, nuages, canards, nénuphars
---------------------------------------------------------------------------------------------------------------

function SceneryModels.boat(parent: Instance, spot: { x: number, z: number, yaw: number }, index: number)
	local config = SceneryConfig.BOAT
	local created = model(parent, "Boat")
	local base = CFrame.new(spot.x, WATER_TOP, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
	local color = colorOf(config.HULL_COLORS, index)
	local hull = piece(created, "Hull", base * CFrame.new(0, 1, 0), Vector3.new(7, 3.4, 18), color)
	piece(
		created,
		"Bow",
		base * CFrame.new(0, 1, -9) * CFrame.Angles(0, math.rad(45), 0),
		Vector3.new(5, 3.4, 5),
		color
	)
	piece(created, "Deck", base * CFrame.new(0, 2.9, 0), Vector3.new(6, 0.5, 16), { 226, 196, 150 })
	piece(created, "Mast", base * CFrame.new(0, 12, -1), Vector3.new(0.9, 19, 0.9), { 124, 92, 70 })
	piece(created, "Sail", base * CFrame.new(0, 12.5, 3.2), Vector3.new(0.4, 15, 7.4), config.SAIL_COLOR)
	piece(created, "Sail", base * CFrame.new(0, 9.5, -5.2), Vector3.new(0.4, 9, 5), config.SAIL_COLOR)
	piece(created, "Flag", base * CFrame.new(0, 22.4, 0.6), Vector3.new(0.3, 1.8, 3), color)
	animated(created, hull, SceneryConfig.BOB_TAG, config.BOB, 0)
end

function SceneryModels.balloon(parent: Instance, spot: { x: number, y: number, z: number }, index: number)
	local config = SceneryConfig.BALLOON
	local created = model(parent, "Balloon")
	local palette = colorOf(config.PALETTES :: { any }, index) :: { { number } }
	local base = CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, index, 0)
	local primary: Part? = nil
	for k, width in config.TIERS do
		local tier = piece(
			created,
			"Envelope",
			base
				* CFrame.new(0, (k - 0.5) * config.TIER_HEIGHT, 0)
				* CFrame.Angles(0, if k % 2 == 0 then math.rad(45) else 0, 0),
			Vector3.new(width, config.TIER_HEIGHT, width) * (if k % 2 == 0 then 0.8 else 1)
				+ Vector3.new(0, if k % 2 == 0 then config.TIER_HEIGHT * 0.2 else 0, 0),
			colorOf(palette, k)
		)
		primary = primary or tier
	end
	piece(created, "Basket", base * CFrame.new(0, -9, 0), Vector3.new(6, 5, 6), config.BASKET_COLOR)
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		piece(
			created,
			"Rope",
			base * CFrame.new(corner[1] * 2.8, -3.2, corner[2] * 2.8),
			Vector3.new(0.3, 7, 0.3),
			BLACK
		)
	end
	animated(created, primary :: Part, SceneryConfig.BOB_TAG, config.BOB, 30)
end

function SceneryModels.cloud(parent: Instance, cloud: Scenery.Cloud)
	local config = SceneryConfig.CLOUD
	local created = model(parent, "Cloud")
	local base = CFrame.new(cloud.x, cloud.y, cloud.z)
	local primary: Part? = nil
	for _, block in config.BLOCKS do
		local offset = Vector3.new(block[1], block[2], block[3]) * cloud.scale
		local size = Vector3.new(block[4], block[5], block[6]) * cloud.scale
		local part = smooth(piece(created, "Puff", base * CFrame.new(offset), size, config.COLOR))
		part.CastShadow = false
		primary = primary or part
	end
	animated(created, primary :: Part, SceneryConfig.DRIFT_TAG, nil, nil)
end

function SceneryModels.duck(parent: Instance, spot: Scenery.Floater)
	local config = SceneryConfig.RIVER
	local created = model(parent, "Duck")
	local base = CFrame.new(spot.x, WATER_TOP, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
	local body = piece(created, "Body", base * CFrame.new(0, 1.2, 0), Vector3.new(3.2, 2.4, 4.4), config.DUCK_COLOR)
	piece(created, "Head", base * CFrame.new(0, 3.2, -1.6), Vector3.new(2.2, 2.2, 2.2), config.DUCK_COLOR)
	piece(created, "Beak", base * CFrame.new(0, 2.9, -3), Vector3.new(1.2, 0.6, 1), config.BEAK_COLOR)
	piece(created, "Tail", base * CFrame.new(0, 2.2, 2.4), Vector3.new(1.6, 1.2, 1), config.DUCK_COLOR)
	for _, side in { -1, 1 } do
		piece(created, "Eye", base * CFrame.new(side * 1.12, 3.5, -2), Vector3.new(0.1, 0.5, 0.5), BLACK)
	end
	animated(created, body, SceneryConfig.BOB_TAG, config.BOB, 6)
end

function SceneryModels.lily(parent: Instance, spot: Scenery.Floater)
	local config = SceneryConfig.RIVER
	local size = 3.5 + (spot.yaw % 3)
	local base = CFrame.new(spot.x, WATER_TOP + 0.15, spot.z)
	local pad = cylinder(
		piece(parent, "Lily", base * CFrame.Angles(0, 0, QUARTER), Vector3.new(0.3, size, size), config.LILY_COLOR)
	)
	pad.CastShadow = false
	local flower = config.FLOWER_COLORS[spot.variant]
	if flower then
		piece(parent, "LilyFlower", base * CFrame.new(0, 0.6, 0), Vector3.new(1.4, 0.8, 1.4), flower)
		piece(parent, "LilyHeart", base * CFrame.new(0, 1.1, 0), Vector3.new(0.6, 0.5, 0.6), { 255, 215, 60 })
	end
end

---------------------------------------------------------------------------------------------------------------
-- Jardins, lampadaires, plage
---------------------------------------------------------------------------------------------------------------

local GARDEN = SceneryConfig.GARDEN

local function flowers(parent: Instance, base: CFrame, variant: number)
	local spots = { { 0, 0 }, { 1.8, 1.2 }, { -1.6, 1.6 }, { 1.2, -1.8 }, { -1.4, -1.4 } }
	for k, spot in spots do
		local height = 1.2 + (k % 3) * 0.5
		local foot = base * CFrame.new(spot[1], 0, spot[2])
		piece(parent, "Stem", foot * CFrame.new(0, height / 2, 0), Vector3.new(0.3, height, 0.3), GARDEN.STEM_COLOR)
		piece(
			parent,
			"Flower",
			foot * CFrame.new(0, height + 0.3, 0),
			Vector3.new(1, 0.6, 1),
			colorOf(GARDEN.FLOWER_COLORS, variant + k)
		)
	end
end

local function bush(parent: Instance, base: CFrame, variant: number, scale: number)
	local color = colorOf(GARDEN.BUSH_COLORS, variant)
	piece(parent, "Bush", base * CFrame.new(0, 1.3 * scale, 0), Vector3.new(4.4, 2.6, 4.4) * scale, color)
	piece(
		parent,
		"Bush",
		base * CFrame.new(0.5 * scale, 3 * scale, -0.3 * scale),
		Vector3.new(2.8, 1.6, 2.8) * scale,
		color
	)
	if variant % 3 == 0 then
		piece(parent, "Berry", base * CFrame.new(2.2 * scale, 1.8 * scale, 0.8), Vector3.one * 0.6, TREE.APPLE_COLOR)
		piece(parent, "Berry", base * CFrame.new(-0.9, 2 * scale, 2.2 * scale), Vector3.one * 0.6, TREE.APPLE_COLOR)
	end
end

local function rock(parent: Instance, base: CFrame, variant: number, scale: number)
	piece(
		parent,
		"Rock",
		base * CFrame.new(0, 1 * scale, 0),
		Vector3.new(3.6, 2, 3) * scale,
		colorOf(GARDEN.ROCK_COLORS, variant)
	)
	piece(
		parent,
		"Rock",
		base * CFrame.new(1.2 * scale, 0.7 * scale, 1.6 * scale) * CFrame.Angles(0, 0.6, 0),
		Vector3.new(2, 1.4, 2) * scale,
		colorOf(GARDEN.ROCK_COLORS, variant + 1)
	)
end

local function mushroom(parent: Instance, base: CFrame, scale: number)
	local size = 1.6 * scale
	piece(
		parent,
		"MushroomStem",
		base * CFrame.new(0, size * 0.6, 0),
		Vector3.new(1, 1.2, 1) * size,
		GARDEN.MUSHROOM_STEM
	)
	piece(
		parent,
		"MushroomCap",
		base * CFrame.new(0, size * 1.6, 0),
		Vector3.new(3, 0.9, 3) * size,
		GARDEN.MUSHROOM_CAP
	)
	piece(
		parent,
		"MushroomCap",
		base * CFrame.new(0, size * 2.3, 0),
		Vector3.new(1.8, 0.6, 1.8) * size,
		GARDEN.MUSHROOM_CAP
	)
	for _, dot in { { 0.9, 0.7 }, { -0.8, -0.9 }, { -1, 0.8 } } do
		piece(
			parent,
			"MushroomDot",
			base * CFrame.new(dot[1] * size, size * 2.08, dot[2] * size),
			Vector3.new(0.5, 0.1, 0.5) * size,
			WHITE
		)
	end
end

local function hay(parent: Instance, base: CFrame)
	-- Bottes rondes couchées (l'axe d'un cylindre Roblox est son axe X) : deux au sol, une par-dessus.
	for _, spot in { { 2, -2.1 }, { 2, 2.1 }, { 5.4, 0 } } do
		local bale =
			piece(parent, "Hay", base * CFrame.new(0, spot[1], spot[2]), Vector3.new(4.4, 4, 4), GARDEN.HAY_COLOR)
		cylinder(bale)
	end
end

function SceneryModels.gardenProp(parent: Instance, prop: Scenery.Prop, top: number)
	local base = CFrame.new(prop.x, top, prop.z) * CFrame.Angles(0, math.rad(prop.yaw), 0)
	if prop.kind == "flowers" then
		flowers(parent, base, prop.variant)
	elseif prop.kind == "bush" then
		bush(parent, base, prop.variant, prop.scale)
	elseif prop.kind == "rock" then
		rock(parent, base, prop.variant, prop.scale)
	elseif prop.kind == "mushroom" then
		mushroom(parent, base, prop.scale)
	elseif prop.kind == "hay" then
		hay(parent, base)
	elseif prop.kind == "parasol" then
		SceneryModels.parasol(parent, base, prop.variant)
	else
		SceneryModels.tree(parent, prop.kind, base, prop.scale, prop.variant / 12)
	end
end

function SceneryModels.parasol(parent: Instance, base: CFrame, variant: number)
	local config = SceneryConfig.BEACH_PROPS
	local color = colorOf(config.PARASOL_COLORS, variant)
	piece(parent, "Pole", base * CFrame.new(0, 4, 0), Vector3.new(0.5, 8, 0.5), WHITE)
	piece(parent, "Canopy", base * CFrame.new(0, 8, 0), Vector3.new(9, 0.7, 9), color)
	piece(parent, "Canopy", base * CFrame.new(0, 8.7, 0), Vector3.new(6, 0.7, 6), WHITE)
	piece(parent, "Canopy", base * CFrame.new(0, 9.4, 0), Vector3.new(3, 0.7, 3), color)
	piece(
		parent,
		"Towel",
		base * CFrame.new(3.5, 0.1, 1),
		Vector3.new(4, 0.2, 7.5),
		colorOf(config.TOWEL_COLORS, variant)
	)
	if variant % 2 == 0 then
		local ball = smooth(piece(parent, "Ball", base * CFrame.new(-3.5, 1.3, -2), Vector3.one * 2.6, WHITE))
		ball.Shape = Enum.PartType.Ball
		ball.Color = Color3.fromRGB(color[1], color[2], color[3])
	end
end

function SceneryModels.lamp(parent: Instance, x: number, z: number, top: number)
	local config = SceneryConfig.LAMP
	local base = CFrame.new(x, top, z)
	piece(parent, "LampFoot", base * CFrame.new(0, 0.5, 0), Vector3.new(2, 1, 2), config.POLE_COLOR)
	piece(
		parent,
		"LampPole",
		base * CFrame.new(0, config.HEIGHT / 2, 0),
		Vector3.new(0.8, config.HEIGHT, 0.8),
		config.POLE_COLOR
	)
	piece(parent, "LampArm", base * CFrame.new(1.4, config.HEIGHT, 0), Vector3.new(3.6, 0.6, 0.6), config.POLE_COLOR)
	local bulb = neon(
		piece(parent, "LampBulb", base * CFrame.new(2.8, config.HEIGHT - 1.2, 0), Vector3.one * 1.8, config.LIGHT_COLOR)
	)
	local light = Instance.new("PointLight")
	light.Color = bulb.Color
	light.Range, light.Brightness = config.RANGE, config.BRIGHTNESS
	light.Parent = bulb
end

return SceneryModels
