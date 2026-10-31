--!strict
-- Décorations de la base en briques (A53) : lampadaires, parterres, fontaine, drapeau et arche au nom du
-- joueur, statue dorée, éolienne géante. Purement esthétiques : ni collision ni requêtes physiques, pour ne
-- jamais gêner un engin. L'éolienne réutilise les ailes « MillBlades » que TycoonAnimController fait tourner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local Build = require(script.Parent.Build)
local TycoonModels = require(script.Parent.TycoonModels)

local TycoonDecor = {}

type Builder = (model: Model, origin: CFrame, ownerName: string) -> ()

local DARK = { 27, 42, 53 }
local STONE = { 163, 162, 165 }
local SOIL = { 105, 64, 40 }
local LEAF = { 75, 151, 75 }
local GOLD = { 255, 196, 0 }
local WHITE = { 248, 248, 248 }
local WATER = { 80, 170, 255 }
local WARM_LIGHT = { 255, 220, 150 }
local NEON_PINK = { 255, 60, 160 }
local NEON_CYAN = { 0, 220, 255 }
local RED = { 196, 40, 28 }
local FLOWER_COLORS = { { 255, 80, 80 }, { 255, 210, 40 }, { 190, 90, 255 }, { 255, 140, 200 }, { 255, 255, 255 } }
local LAMP_HEIGHT = 9
local GOLD_REFLECTANCE = 0.35
local SIGN_PIXELS = 25

local function block(model: Model, name: string, cframe: CFrame, size: Vector3, color: { number }): Part
	return Build.block(model, { name = name, cframe = cframe, size = size, color = color })
end

local function glow(part: BasePart, color: { number }, range: number)
	part.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(color[1], color[2], color[3])
	light.Range = range
	light.Parent = part
end

-- Enseigne lumineuse sur les deux grandes faces d'une pièce.
local function sign(part: BasePart, text: string)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local label = Build.sign(part, face, text, WHITE)
		local gui = label.Parent :: SurfaceGui
		gui.PixelsPerStud = SIGN_PIXELS
		gui.LightInfluence = 0
	end
end

local function lamp(model: Model, origin: CFrame, _: string)
	block(model, "Post", origin * CFrame.new(0, LAMP_HEIGHT / 2, 0), Vector3.new(0.6, LAMP_HEIGHT, 0.6), DARK)
	block(model, "Arm", origin * CFrame.new(0, LAMP_HEIGHT, 0), Vector3.new(2.4, 0.4, 0.6), DARK)
	for _, side in { -1, 1 } do
		local bulb = block(
			model,
			"Bulb",
			origin * CFrame.new(side * 1.1, LAMP_HEIGHT - 0.6, 0),
			Vector3.new(0.9, 0.9, 0.9),
			WARM_LIGHT
		)
		glow(bulb, WARM_LIGHT, 18)
	end
end

local function flowers(model: Model, origin: CFrame, _: string)
	block(model, "Border", origin * CFrame.new(0, 0.4, 0), Vector3.new(4, 0.8, 8), STONE)
	block(model, "Soil", origin * CFrame.new(0, 0.85, 0), Vector3.new(3.2, 0.2, 7.2), SOIL)
	for k = 0, 5 do
		for _, x in { -0.8, 0.8 } do
			local z = -3 + k * 1.2
			block(model, "Stem", origin * CFrame.new(x, 1.4, z), Vector3.new(0.2, 1, 0.2), LEAF)
			local color = FLOWER_COLORS[(k + (if x > 0 then 2 else 0)) % #FLOWER_COLORS + 1]
			local petal = block(model, "Petal", origin * CFrame.new(x, 2, z), Vector3.new(0.7, 0.4, 0.7), color)
			petal.Shape = Enum.PartType.Ball
		end
	end
end

local function fountain(model: Model, origin: CFrame, _: string)
	local flat = CFrame.Angles(0, 0, math.pi / 2) -- un cylindre Roblox est couché sur X : on le redresse
	block(model, "Basin", origin * CFrame.new(0, 0.75, 0) * flat, Vector3.new(1.5, 12, 12), STONE).Shape =
		Enum.PartType.Cylinder
	local water = block(model, "Water", origin * CFrame.new(0, 1.4, 0) * flat, Vector3.new(0.2, 10.6, 10.6), WATER)
	water.Shape = Enum.PartType.Cylinder
	water.Material = Enum.Material.Glass
	water.Transparency = 0.25
	block(model, "Pillar", origin * CFrame.new(0, 3, 0) * flat, Vector3.new(4, 1.6, 1.6), STONE).Shape =
		Enum.PartType.Cylinder
	block(model, "Bowl", origin * CFrame.new(0, 5.2, 0) * flat, Vector3.new(0.8, 5, 5), STONE).Shape =
		Enum.PartType.Cylinder
	local spout = block(model, "Spout", origin * CFrame.new(0, 6, 0), Vector3.new(0.8, 0.8, 0.8), WATER)
	glow(spout, WATER, 14)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(WATER[1], WATER[2], WATER[3]), Color3.new(1, 1, 1))
	spray.Size = NumberSequence.new(0.5, 0.1)
	spray.Speed = NumberRange.new(10, 14)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Lifetime = NumberRange.new(0.9, 1.2)
	spray.Rate = 60
	spray.LightEmission = 0.4
	spray.Parent = spout
end

local function flag(model: Model, origin: CFrame, ownerName: string)
	local height = 22
	block(model, "Pole", origin * CFrame.new(0, height / 2, 0), Vector3.new(0.7, height, 0.7), WHITE).Material =
		Enum.Material.Metal
	local top = block(model, "Top", origin * CFrame.new(0, height + 0.5, 0), Vector3.new(1.4, 1.4, 1.4), GOLD)
	top.Shape = Enum.PartType.Ball
	top.Reflectance = GOLD_REFLECTANCE
	local cloth = block(model, "Cloth", origin * CFrame.new(0, height - 3, -4.5), Vector3.new(0.2, 5, 8.6), RED)
	local label = Build.sign(cloth, Enum.NormalId.Right, `FERME DE\n{string.upper(ownerName)}`, WHITE)
	local mirror = Build.sign(cloth, Enum.NormalId.Left, `FERME DE\n{string.upper(ownerName)}`, WHITE)
	for _, gui in { label.Parent, mirror.Parent } :: { any } do
		gui.PixelsPerStud = SIGN_PIXELS
	end
end

local function statue(model: Model, origin: CFrame, _: string)
	block(model, "Pedestal", origin * CFrame.new(0, 1.5, 0), Vector3.new(6, 3, 6), STONE)
	block(model, "Plinth", origin * CFrame.new(0, 3.2, 0), Vector3.new(5, 0.4, 5), DARK)
	local pieces = {
		{ "LegL", CFrame.new(0, 5.4, -0.6), Vector3.new(1.2, 4, 1.2) },
		{ "LegR", CFrame.new(0, 5.4, 0.6), Vector3.new(1.2, 4, 1.2) },
		{ "Torso", CFrame.new(0, 8.6, 0), Vector3.new(1.4, 2.6, 2.6) },
		{ "ArmL", CFrame.new(0, 8.6, -1.9), Vector3.new(1.2, 2.6, 1.2) },
		{ "ArmR", CFrame.new(0.6, 10.2, 1.9) * CFrame.Angles(0, 0, 0.6), Vector3.new(1.2, 2.6, 1.2) },
		{ "Head", CFrame.new(0, 10.8, 0), Vector3.new(1.8, 1.8, 1.8) },
		{ "HatBrim", CFrame.new(0, 11.8, 0), Vector3.new(3.2, 0.25, 3.2) },
		{ "HatTop", CFrame.new(0, 12.4, 0), Vector3.new(1.9, 1, 1.9) },
		{ "Pitchfork", CFrame.new(1.3, 11, 1.9), Vector3.new(0.3, 7, 0.3) },
	}
	for _, piece in pieces do
		local part = block(model, piece[1], origin * piece[2], piece[3], GOLD)
		part.Material = Enum.Material.Metal
		part.Reflectance = GOLD_REFLECTANCE
	end
end

local function arch(model: Model, origin: CFrame, ownerName: string)
	local height, half = 16, 14
	for _, side in { -1, 1 } do
		block(model, "Pillar", origin * CFrame.new(0, height / 2, side * half), Vector3.new(2, height, 2), DARK)
		local strip = block(
			model,
			"Strip",
			origin * CFrame.new(1.05, height / 2, side * half),
			Vector3.new(0.2, height - 1, 0.6),
			NEON_CYAN
		)
		glow(strip, NEON_CYAN, 12)
	end
	-- Poutre tournée d'un quart de tour : ses faces avant / arrière (l'enseigne) regardent le champ et la base.
	local beamCFrame = origin * CFrame.new(0, height + 1.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local beam = block(model, "Beam", beamCFrame, Vector3.new(half * 2 + 2, 3, 2), DARK)
	local trim = block(model, "Trim", origin * CFrame.new(0, height, 0), Vector3.new(2.2, 0.3, half * 2 + 2), NEON_PINK)
	glow(trim, NEON_PINK, 14)
	sign(beam, `🌾 FERME DE {string.upper(ownerName)} 🌾`)
end

local function windmill(model: Model, origin: CFrame, _: string)
	local levels = { { 8, 10 }, { 6.5, 10 }, { 5, 10 } }
	local y = 0
	for index, level in levels do
		local width, height = level[1], level[2]
		block(
			model,
			`Tower{index}`,
			origin * CFrame.new(0, y + height / 2, 0),
			Vector3.new(width, height, width),
			WHITE
		)
		y += height
	end
	block(model, "Cap", origin * CFrame.new(0, y + 1.5, 0), Vector3.new(6, 3, 6), RED)
	local blades = Instance.new("Model")
	blades.Name = TycoonModels.BLADES_NAME
	local hubCFrame = origin * CFrame.new(3.5, y - 1, 0)
	local hub = block(blades, "Hub", hubCFrame, Vector3.new(1.2, 2.4, 2.4), DARK)
	block(blades, "BladeA", hubCFrame * CFrame.new(0.6, 0, 0), Vector3.new(0.4, 24, 2.2), WHITE)
	block(blades, "BladeB", hubCFrame * CFrame.new(0.6, 0, 0), Vector3.new(0.4, 2.2, 24), WHITE)
	blades.PrimaryPart = hub
	blades.Parent = model
end

local BUILDERS: { [string]: Builder } = {
	Lamps = lamp,
	Flowers = flowers,
	Fountain = fountain,
	Flag = flag,
	Statue = statue,
	Arch = arch,
	Windmill = windmill,
}

-- Construit la décoration à chacun de ses emplacements (`origins`, déjà en coordonnées monde). `parent` peut
-- être nil : l'appelant place le modèle lui-même (après l'avoir horodaté).
function TycoonDecor.build(
	parent: Instance?,
	decor: TycoonConfig.DecorDef,
	origins: { CFrame },
	ownerName: string
): Model
	local model = Instance.new("Model")
	model.Name = `Decor{decor.id}`
	for _, origin in origins do
		BUILDERS[decor.id](model, origin, ownerName)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model.Parent = parent
	return model
end

return TycoonDecor
