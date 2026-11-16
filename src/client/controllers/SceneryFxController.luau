--!strict
-- Vie du paysage (A69), côté client : les nuages dérivent, les montgolfières, les voiliers et les canards tanguent,
-- et du pollen flotte dans le champ autour de la caméra. Purement visuel : le serveur pose les modèles une fois
-- (SceneryService) et chaque client les anime chez lui, sans aucun trafic réseau.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local SceneryConfig = require(ReplicatedStorage.Shared.config.SceneryConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)

local SceneryFxController = {}

type Bobber = { rest: CFrame, height: number, period: number, tilt: number, roam: number, phase: number }

local CLOUD = SceneryConfig.CLOUD
local POLLEN = UiConfig.POLLEN
local TAU = 2 * math.pi
local ROAM_PERIODS = 8 -- un tour de ronde dure 8 balancements

local drifters: { [Model]: CFrame } = {}
local bobbers: { [Model]: Bobber } = {}
local drift = 0
local pollenPart: Part? = nil
local pollen: ParticleEmitter? = nil

local function numberAttribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function addDrifter(instance: Instance)
	if instance:IsA("Model") and instance.PrimaryPart then
		drifters[instance] = instance:GetPivot()
	end
end

local function addBobber(instance: Instance)
	if not instance:IsA("Model") or not instance.PrimaryPart then
		return
	end
	local rest = instance:GetPivot()
	bobbers[instance] = {
		rest = rest,
		height = numberAttribute(instance, SceneryConfig.BOB_HEIGHT),
		period = math.max(numberAttribute(instance, SceneryConfig.BOB_PERIOD), 0.5),
		tilt = math.rad(numberAttribute(instance, SceneryConfig.BOB_TILT)),
		roam = numberAttribute(instance, SceneryConfig.BOB_ROAM),
		phase = (rest.Position.X * 0.37 + rest.Position.Z * 0.11) % TAU, -- chacun son rythme
	}
end

local function watch(tag: string, add: (Instance) -> (), registry: { [Model]: any })
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		registry[instance :: Model] = nil
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
end

local function animateClouds(deltaTime: number)
	local span = CLOUD.MAX_Z - CLOUD.MIN_Z
	drift = (drift + deltaTime * CLOUD.DRIFT_SPEED) % span
	for model, rest in drifters do
		local z = (rest.Position.Z - CLOUD.MIN_Z + drift) % span + CLOUD.MIN_Z
		model:PivotTo(CFrame.new(rest.Position.X, rest.Position.Y, z))
	end
end

local function animateBobbers(now: number)
	for model, bobber in bobbers do
		local swing = now * TAU / bobber.period + bobber.phase
		local lift = Vector3.new(0, math.sin(swing) * bobber.height, 0)
		local roll = CFrame.Angles(math.sin(swing * 0.7) * bobber.tilt, 0, math.cos(swing) * bobber.tilt)
		if bobber.roam > 0 then
			-- Ronde lente autour du point de repos, le nez dans le sens de la marche.
			local turn = swing / ROAM_PERIODS
			local position = bobber.rest.Position + Vector3.new(math.cos(turn), 0, math.sin(turn)) * bobber.roam + lift
			local heading = Vector3.new(-math.sin(turn), 0, math.cos(turn))
			model:PivotTo(CFrame.lookAt(position, position + heading) * roll)
		else
			model:PivotTo((bobber.rest + lift) * roll)
		end
	end
end

-- Un seul émetteur, porté par une pièce invisible qui suit la caméra : le pollen n'existe que là où on regarde.
local function createPollen()
	local part = Instance.new("Part")
	part.Name = "Pollen"
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.Size = Vector3.new(POLLEN.AREA, POLLEN.HEIGHT, POLLEN.AREA)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = POLLEN.TEXTURE
	emitter.Rate = POLLEN.RATE
	emitter.Lifetime = NumberRange.new(POLLEN.LIFETIME * 0.7, POLLEN.LIFETIME)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0.6, 0.25, 0.3)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Size = NumberSequence.new(POLLEN.SIZE)
	emitter.LightEmission = 0.6
	emitter.Color = ColorSequence.new(Color3.fromRGB(POLLEN.COLOR[1], POLLEN.COLOR[2], POLLEN.COLOR[3]))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, POLLEN.TRANSPARENCY),
		NumberSequenceKeypoint.new(0.8, POLLEN.TRANSPARENCY),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	part.Parent = Workspace
	pollenPart, pollen = part, emitter
end

local function followCamera()
	local camera = Workspace.CurrentCamera
	if not camera or not pollenPart or not pollen then
		return
	end
	local position = camera.CFrame.Position + camera.CFrame.LookVector * POLLEN.AHEAD
	pollen.Enabled = position.X > MapConfig.MOAT.maxX -- seulement au-dessus du champ
	pollenPart.CFrame = CFrame.new(position.X, MapConfig.FLOOR_TOP + POLLEN.HEIGHT / 2, position.Z)
end

function SceneryFxController:Start()
	watch(SceneryConfig.DRIFT_TAG, addDrifter, drifters)
	watch(SceneryConfig.BOB_TAG, addBobber, bobbers)
	createPollen()
	RunService.RenderStepped:Connect(function(deltaTime)
		animateClouds(deltaTime)
		animateBobbers(os.clock())
		followCamera()
	end)
end

return SceneryFxController
