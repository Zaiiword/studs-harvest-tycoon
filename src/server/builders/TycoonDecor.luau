--!strict
-- Pose un élément de la ferme Lego (A56) : FarmBlueprint décrit les briques, on les instancie ici. Les briques
-- « solides » (murs, planchers, escalier) ont une collision ; le reste du décor se traverse. Les sous-modèles
-- (ailes de l'éolienne) sont animés par TycoonAnimController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FarmConfig = require(ReplicatedStorage.Shared.config.FarmConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local FarmBlueprint = require(ReplicatedStorage.Shared.domain.FarmBlueprint)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Build = require(script.Parent.Build)

local TycoonDecor = {}

local WHITE = { 248, 248, 248 }
local SIGN_PIXELS = 25
local WATER_SPRAY = {
	color = ColorSequence.new(Color3.fromRGB(80, 170, 255), Color3.new(1, 1, 1)),
	size = NumberSequence.new(0.5, 0.1),
	speed = NumberRange.new(10, 14),
	spread = Vector2.new(18, 18),
	gravity = Vector3.new(0, -30, 0),
	lifetime = NumberRange.new(0.9, 1.2),
	rate = 60,
}

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function addSpray(part: BasePart)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = WATER_SPRAY.color
	spray.Size = WATER_SPRAY.size
	spray.Speed = WATER_SPRAY.speed
	spray.SpreadAngle = WATER_SPRAY.spread
	spray.Acceleration = WATER_SPRAY.gravity
	spray.Lifetime = WATER_SPRAY.lifetime
	spray.Rate = WATER_SPRAY.rate
	spray.LightEmission = 0.4
	spray.Parent = part
end

local function addSigns(part: BasePart, signs: { FarmBlueprint.Sign }, ownerName: string)
	for _, sign in signs do
		local text = string.gsub(sign.text, "{owner}", string.upper(ownerName))
		local label = Build.sign(part, (Enum.NormalId :: any)[sign.face], text, WHITE)
		local gui = label.Parent :: SurfaceGui
		gui.PixelsPerStud = SIGN_PIXELS
		gui.LightInfluence = 0
	end
end

local function dress(part: Part, piece: FarmBlueprint.Piece, ownerName: string)
	if piece.shape then
		part.Shape = (Enum.PartType :: any)[piece.shape]
	end
	if piece.material then
		part.Material = (Enum.Material :: any)[piece.material]
	end
	part.Transparency = piece.transparency or 0
	part.Reflectance = piece.reflectance or 0
	if piece.isSmooth then
		for _, face in Enum.NormalId:GetEnumItems() do
			(part :: any)[`{face.Name}Surface`] = Enum.SurfaceType.Smooth -- pas de tenons sur le verre ni l'eau
		end
	end
	if piece.light then
		local light = Instance.new("PointLight")
		light.Color = Bricks.rgb(piece.color)
		light.Range = piece.light
		light.Brightness = FarmConfig.LIGHT.BRIGHTNESS
		light.Parent = part
	end
	if piece.signs then
		addSigns(part, piece.signs, ownerName)
	end
	if piece.hasSpray then
		addSpray(part)
	end
end

local function place(parent: Instance, piece: FarmBlueprint.Piece, origin: CFrame, ownerName: string): Part
	local tilt = piece.tilt or { 0, 0, 0 }
	local part = Build.block(parent, {
		name = piece.name,
		cframe = origin * CFrame.new(vector(piece.at)) * CFrame.Angles(tilt[1], tilt[2], tilt[3]),
		size = vector(piece.size),
		color = piece.color,
	})
	part.CanCollide = piece.isSolid == true
	part.CanQuery = piece.isSolid == true
	part.CanTouch = false
	dress(part, piece, ownerName)
	return part
end

-- Construit l'élément du plan ; `origin` : centre de la base au niveau du pont. Le modèle n'a pas encore de parent :
-- l'appelant le place après l'avoir horodaté, pour que le client reçoive l'attribut avec le modèle.
function TycoonDecor.build(decor: TycoonConfig.DecorDef, origin: CFrame, ownerName: string): Model
	local model = Instance.new("Model")
	model.Name = `Decor{decor.id}`
	local groups: { [string]: Model } = {}
	for _, piece in FarmBlueprint.pieces(decor.id) do
		local parent: Instance = model
		if piece.group then
			local group = groups[piece.group] or Instance.new("Model")
			group.Name = piece.group
			group.Parent = model
			groups[piece.group] = group
			parent = group
		end
		local part = place(parent, piece, origin, ownerName)
		if piece.isHub then
			(parent :: Model).PrimaryPart = part
		end
	end
	if decor.fadesInside then
		model:SetAttribute(TycoonConfig.FADE_ATTRIBUTE, true)
	end
	return model
end

return TycoonDecor
