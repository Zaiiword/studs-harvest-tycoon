--!strict
-- Habillage des engins de TOUS les joueurs, construit et animé localement (CDC §2 « taille de sa moissonneuse »,
-- §5 ; A52). Le serveur ne réplique qu'une carrosserie physique, cachée ici : les pièces décoratives (roues qui
-- tournent, rabatteurs, néons, fumée, paille…) ne coûtent rien au réseau ni au moteur physique du serveur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local VehicleVisualConfig = require(ReplicatedStorage.Shared.config.VehicleVisualConfig)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local VehicleLooks = require(ReplicatedStorage.Shared.domain.VehicleLooks)
local Perks = require(ReplicatedStorage.Shared.net.Perks)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local VehicleVisualController = {}

type Piece = VehicleVisualConfig.Piece

type Rig = {
	model: Model,
	body: BasePart,
	parts: { BasePart },
	bases: { CFrame }, -- position de chaque pièce dans le repère de la carrosserie
	pieces: { Piece },
	glows: { BasePart },
	beacons: { PointLight },
	exhausts: { ParticleEmitter }, -- fumée et flammes dont le débit suit l'accélérateur
	thrusters: { ParticleEmitter },
	chaff: ParticleEmitter,
	distance: number, -- distance parcourue (roues)
	reelAngle: number,
	cframes: { CFrame }, -- tampon réutilisé pour BulkMoveTo
}

local CONFIG = VehicleVisualConfig
local BODY_NAME = VehicleConfig.PARTS.BODY
local FULL_TURN = 2 * math.pi
local ANCHOR_SIZE = 0.2

local folder: Folder
local rigs: { [Player]: Rig } = {}
local clock = 0

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function range(values: { number }): NumberRange
	return NumberRange.new(values[1], values[2])
end

local function baseOf(piece: Piece): CFrame
	local tilt = piece.tilt or { 0, 0, 0 }
	return CFrame.new(vector(piece.at)) * CFrame.Angles(tilt[1], tilt[2], tilt[3])
end

local function lookOf(player: Player): VehicleLooks.Look
	local tier = player:GetAttribute(PlayerAttributes.TIER)
	local purchased = if typeof(tier) == "number" then tier else 1
	return VehicleLooks.lookOf(purchased, Perks.of(player), Perks.hasPass(player, "Titan"))
end

local function paintPart(part: BasePart, look: VehicleLooks.Look, paint: string)
	local material = CONFIG.MATERIALS[paint]
	if material then
		part.Material = (Enum.Material :: any)[material]
	end
	if paint == "glass" then
		part.Transparency = CONFIG.GLASS_TRANSPARENCY
	elseif paint == "chrome" then
		part.Reflectance = CONFIG.CHROME_REFLECTANCE
	elseif paint == "titan" then
		part.Reflectance = CONFIG.TITAN_REFLECTANCE
	end
	part.Color = Bricks.rgb(VehicleLooks.paint(look, paint))
end

local function addLights(part: BasePart, piece: Piece)
	if piece.light then
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = CONFIG.HEADLIGHT.range
		spot.Brightness = CONFIG.HEADLIGHT.brightness
		spot.Angle = CONFIG.HEADLIGHT.angle
		spot.Color = part.Color
		spot.Parent = part
	end
end

local function newEmitter(parent: Instance, texture: string, color: { number }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(Bricks.rgb(color))
	emitter.Parent = parent
	return emitter
end

local function sizeSequence(values: { number }): NumberSequence
	return NumberSequence.new(values[1], values[2])
end

-- Flammes : jet court et lumineux, vers le haut pour un pot d'échappement, vers l'arrière (+Z) pour un réacteur.
local function newFlame(attachment: Attachment, color: { number }, direction: Enum.NormalId): ParticleEmitter
	local spec = CONFIG.THRUSTER
	local flame = newEmitter(attachment, CONFIG.SPARK_TEXTURE, color)
	flame.EmissionDirection = direction
	flame.Lifetime = range(spec.lifetime)
	flame.Speed = range(spec.speed)
	flame.Size = sizeSequence(spec.size)
	flame.LightEmission = 1
	flame.Rate = spec.idleRate
	return flame
end

local function addExhaust(rig: Rig, attachment: Attachment, look: VehicleLooks.Look)
	local spec = CONFIG.EXHAUST
	local smoke = newEmitter(attachment, CONFIG.SMOKE_TEXTURE, spec.color)
	smoke.Lifetime = range(spec.lifetime)
	smoke.Speed = range(spec.speed)
	smoke.Size = sizeSequence(spec.size)
	smoke.Transparency = NumberSequence.new(spec.transparency[1], spec.transparency[2])
	smoke.RotSpeed = range(spec.spin)
	smoke.Rate = spec.idleRate
	table.insert(rig.exhausts, smoke)
	if look.hasTurbo then
		table.insert(rig.thrusters, newFlame(attachment, CONFIG.TURBO_FLAME_COLOR, Enum.NormalId.Top))
	end
end

local function addThruster(rig: Rig, attachment: Attachment, look: VehicleLooks.Look)
	local color = if look.hasTurbo then CONFIG.TURBO_FLAME_COLOR else CONFIG.THRUSTER.color
	table.insert(rig.thrusters, newFlame(attachment, color, Enum.NormalId.Back))
	local glow = Instance.new("PointLight")
	glow.Color = Bricks.rgb(color)
	glow.Range = CONFIG.THRUSTER.lightRange
	glow.Parent = attachment
end

local function addChaff(rig: Rig, look: VehicleLooks.Look): ParticleEmitter
	local at, width = VehicleLooks.chaffBar(look)
	local bar = Bricks.decor("ChaffBar", Vector3.new(width, ANCHOR_SIZE, ANCHOR_SIZE), CONFIG.CHAFF.color)
	bar.Transparency = 1
	bar.Parent = rig.model
	table.insert(rig.parts, bar)
	table.insert(rig.bases, CFrame.new(vector(at)))
	table.insert(rig.pieces, { paint = "dark", size = { width }, at = at })
	local spec = CONFIG.CHAFF
	local chaff = newEmitter(bar, CONFIG.SPARK_TEXTURE, spec.color)
	chaff.Shape = Enum.ParticleEmitterShape.Box
	chaff.EmissionDirection = Enum.NormalId.Top
	chaff.Lifetime = range(spec.lifetime)
	chaff.Speed = range(spec.speed)
	chaff.SpreadAngle = Vector2.new(spec.spread, spec.spread)
	chaff.Size = NumberSequence.new(spec.size)
	chaff.Acceleration = Vector3.new(0, -Workspace.Gravity * spec.gravityRatio, 0)
	chaff.Rate = spec.rate
	chaff.Enabled = false
	return chaff
end

local function addEffects(rig: Rig, anchor: BasePart, look: VehicleLooks.Look)
	for _, effect in CONFIG.MODELS[look.tierId].effects do
		local attachment = Instance.new("Attachment")
		attachment.Position = vector(effect.at)
		attachment.Parent = anchor
		if effect.kind == "exhaust" then
			addExhaust(rig, attachment, look)
		else
			addThruster(rig, attachment, look)
		end
	end
	rig.chaff = addChaff(rig, look)
end

local function addPiece(rig: Rig, piece: Piece, look: VehicleLooks.Look)
	local part = Bricks.decor(piece.role or "Piece", vector(piece.size), VehicleLooks.paint(look, piece.paint))
	if piece.shape then
		part.Shape = (Enum.PartType :: any)[piece.shape]
	end
	paintPart(part, look, piece.paint)
	addLights(part, piece)
	if piece.role == "glow" then
		table.insert(rig.glows, part)
	end
	if piece.beacon then
		local light = Instance.new("PointLight")
		light.Color = part.Color
		light.Range = CONFIG.BEACON_LIGHT_RANGE
		light.Parent = part
		table.insert(rig.beacons, light)
	end
	part.Parent = rig.model
	table.insert(rig.parts, part)
	table.insert(rig.bases, baseOf(piece))
	table.insert(rig.pieces, piece)
end

-- Gerbe de briques colorées à l'apparition de l'engin (achat au Garage, réapparition).
local function burst(origin: Vector3)
	local spec = CONFIG.SPAWN_BURST
	for k = 1, spec.count do
		local color = spec.colors[(k % #spec.colors) + 1]
		local brick = Bricks.decor("Burst", Vector3.one * spec.brickSize, color)
		brick.Anchored = false
		brick.CFrame = CFrame.new(origin)
		local angle = k / spec.count * FULL_TURN
		brick.AssemblyLinearVelocity = Vector3.new(math.cos(angle), spec.lift, math.sin(angle)).Unit * spec.speed
		brick.AssemblyAngularVelocity = Vector3.new(math.random(), math.random(), math.random()) * spec.speed
		brick.Parent = folder
		task.delay(spec.lifetime, brick.Destroy, brick)
	end
end

local function unbuild(player: Player)
	local rig = rigs[player]
	if rig then
		rig.model:Destroy()
		rigs[player] = nil
	end
end

local function build(player: Player, body: BasePart)
	unbuild(player)
	local look = lookOf(player)
	if not VehicleLooks.hasModel(look) then
		return -- Tiers 1 et 2 : à pied, pas d'engin
	end
	local model = Instance.new("Model")
	model.Name = player.Name
	local anchor = Bricks.decor("Anchor", Vector3.one * ANCHOR_SIZE, CONFIG.SHARED_PAINT.dark)
	anchor.Transparency = 1
	anchor.Parent = model
	model.PrimaryPart = anchor
	local rig: Rig = {
		model = model,
		body = body,
		parts = { anchor },
		bases = { CFrame.identity },
		pieces = { { paint = "dark", size = { ANCHOR_SIZE }, at = { 0, 0, 0 } } },
		glows = {},
		beacons = {},
		exhausts = {},
		thrusters = {},
		chaff = nil :: any,
		distance = 0,
		reelAngle = 0,
		cframes = {},
	}
	for _, piece in VehicleLooks.piecesFor(look) do
		addPiece(rig, piece, look)
	end
	addEffects(rig, anchor, look)
	model.Parent = folder
	body.Transparency = 1 -- local : la carrosserie physique reste là, seul son aspect est remplacé
	rigs[player] = rig
	burst(body.Position)
end

local function isInField(position: Vector3): boolean
	return position.X >= MapConfig.STEM.minX and MapGeometry.zoneAt(position.X, position.Z) ~= nil
end

local function updateEffects(rig: Rig, speed: number, isNear: boolean)
	for _, smoke in rig.exhausts do
		smoke.Rate = CONFIG.EXHAUST.idleRate + speed * CONFIG.EXHAUST.ratePerStud
		smoke.Enabled = isNear
	end
	for _, flame in rig.thrusters do
		flame.Rate = CONFIG.THRUSTER.idleRate + speed * CONFIG.THRUSTER.ratePerStud
		flame.Enabled = isNear
	end
	rig.chaff.Enabled = isNear and speed > CONFIG.CHAFF.minSpeed and isInField(rig.body.Position)
	local pulse = (math.sin(clock * CONFIG.GLOW_SPEED) + 1) / 2
	for _, glow in rig.glows do
		glow.Transparency = pulse * CONFIG.GLOW_DEPTH
	end
	for _, light in rig.beacons do
		light.Brightness = 1 - pulse * CONFIG.GLOW_DEPTH
	end
end

-- Pose de chaque pièce : roues et rabatteurs tournent, pods de lévitation flottent.
local function pose(rig: Rig, index: number, origin: CFrame): CFrame
	local piece = rig.pieces[index]
	local base = rig.bases[index]
	if piece.role == "wheel" then
		local radius = piece.radius or 1
		return origin * base * CFrame.Angles(-(rig.distance / radius) % FULL_TURN, 0, 0)
	elseif piece.role == "reel" then
		return origin * base * CFrame.Angles(rig.reelAngle, 0, 0)
	elseif piece.role == "hover" then
		return origin * CFrame.new(0, math.sin(clock * CONFIG.HOVER_SPEED + index) * CONFIG.HOVER_HEIGHT, 0) * base
	end
	return origin * base
end

local function animateRig(rig: Rig, deltaTime: number, cameraPosition: Vector3)
	local origin = rig.body.CFrame
	local velocity = rig.body.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local isNear = (origin.Position - cameraPosition).Magnitude < CONFIG.RENDER_DISTANCE
	if isNear then
		rig.distance += velocity:Dot(origin.LookVector) * deltaTime -- en marche arrière, les roues reculent
		rig.reelAngle = (rig.reelAngle + (CONFIG.REEL_BASE_SPEED + speed * CONFIG.REEL_SPEED_PER_STUD) * deltaTime)
			% FULL_TURN
	end
	for index in rig.parts do
		rig.cframes[index] = pose(rig, index, origin)
	end
	Workspace:BulkMoveTo(rig.parts, rig.cframes, Enum.BulkMoveMode.FireCFrameChanged)
	updateEffects(rig, speed, isNear)
end

local function animate(deltaTime: number)
	clock += deltaTime
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for player, rig in rigs do
		if rig.body.Parent then
			animateRig(rig, deltaTime, cameraPosition)
		else
			unbuild(player)
		end
	end
end

local function watchCharacter(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == BODY_NAME and child:IsA("BasePart") then
			build(player, child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		local rig = rigs[player]
		if rig and rig.body == child then
			unbuild(player)
		end
	end)
	local body = character:FindFirstChild(BODY_NAME)
	if body and body:IsA("BasePart") then
		build(player, body)
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	end
	-- Le Titan ne change que l'habillage : le serveur ne reconstruit pas la carrosserie, on le fait ici.
	player:GetAttributeChangedSignal(PlayerAttributes.PASS_PREFIX .. "Titan"):Connect(function()
		local rig = rigs[player]
		if rig then
			build(player, rig.body)
		end
	end)
end

function VehicleVisualController:Init()
	folder = Instance.new("Folder")
	folder.Name = "VehicleVisuals"
	folder.Parent = Workspace
end

function VehicleVisualController:Start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(unbuild)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.RenderStepped:Connect(animate)
end

return VehicleVisualController
