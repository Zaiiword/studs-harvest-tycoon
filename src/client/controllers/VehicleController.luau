--!strict
-- Pilotage arcade de l'engin du joueur local (CDC §5, Sprint 2). Le client possède physiquement son
-- personnage : il intègre VehicleMotion à chaque image et met à jour LinearVelocity / AlignOrientation.
-- Les commandes passent par le ControlModule de Roblox (clavier, manette et joystick tactile) et sont
-- relatives à la caméra. Pendant un tournis, le serveur a repris la main : on ne touche à rien.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local VehicleMotion = require(ReplicatedStorage.Shared.domain.VehicleMotion)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local WorldAttributes = require(ReplicatedStorage.Shared.net.WorldAttributes)

local VehicleController = {}

local HANDLING = VehicleConfig.HANDLING
local PARTS = VehicleConfig.PARTS

local localPlayer = Players.LocalPlayer
local controls: any = nil
local heading: number? = nil -- nil : à resynchroniser sur l'orientation réelle de l'engin

local function numberAttribute(name: string, default: number): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function isDizzy(): boolean
	return Workspace:GetServerTimeNow() < numberAttribute(PlayerAttributes.DIZZY_UNTIL, -math.huge)
end

local function weatherSpeed(): number
	local multiplier = ReplicatedStorage:GetAttribute(WorldAttributes.VEHICLE_SPEED_MULTIPLIER)
	return if typeof(multiplier) == "number" then multiplier else 1
end

local function flatten(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return if flat.Magnitude > 1e-6 then flat.Unit else Vector3.zero
end

-- Direction voulue en coordonnées monde, relative à la caméra. Source principale : Humanoid.MoveDirection,
-- que les scripts de contrôle Roblox mettent à jour sur PC, mobile et manette. Secours : le ControlModule.
local function desiredDirection(humanoid: Humanoid?): Vector3
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		return humanoid.MoveDirection
	end
	local camera = Workspace.CurrentCamera
	if not controls or not camera then
		return Vector3.zero
	end
	local move: Vector3 = controls:GetMoveVector()
	return flatten(camera.CFrame.RightVector) * move.X - flatten(camera.CFrame.LookVector) * move.Z
end

local function motionParams(): VehicleMotion.MotionParams
	local tier = VehicleConfig.TIERS[numberAttribute(PlayerAttributes.TIER, 1)] or VehicleConfig.TIERS[1]
	local capacity = numberAttribute(PlayerAttributes.BAG_CAPACITY, math.huge)
	local isFull = numberAttribute(PlayerAttributes.BAG_COUNT, 0) >= capacity
	local penalty = if isFull then VehicleConfig.FULL_SPEED_PENALTY else 0 -- CDC §4 : -10 % quand PLEIN
	return {
		maxSpeed = tier.speed * (1 - penalty) * weatherSpeed(), -- Tempête de Vent : +25 % (CDC §6)
		turnRate = HANDLING.TURN_RATE,
		grip = HANDLING.GRIP,
		lateralGrip = HANDLING.LATERAL_GRIP,
		deadzone = HANDLING.INPUT_DEADZONE,
	}
end

local function drive(deltaTime: number)
	local character = localPlayer.Character
	local body = character and character:FindFirstChild(PARTS.BODY)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mover = body and body:FindFirstChild(PARTS.MOVER) :: LinearVelocity?
	local aligner = body and body:FindFirstChild(PARTS.ALIGNER) :: AlignOrientation?
	if not root or not mover or not aligner or isDizzy() then
		heading = nil
		return
	end
	local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid and not humanoid.PlatformStand then
		humanoid.PlatformStand = true -- au cas où la réplication serveur arrive après le montage
	end
	if heading == nil then
		local look = root.CFrame.LookVector
		heading = math.atan2(look.Z, look.X)
	end
	local direction = desiredDirection(humanoid)
	local velocity = root.AssemblyLinearVelocity
	local state = VehicleMotion.step(
		{ heading = heading :: number, vx = velocity.X, vz = velocity.Z },
		{ dirX = direction.X, dirZ = direction.Z },
		motionParams(),
		deltaTime
	)
	heading = state.heading
	mover.PlaneVelocity = Vector2.new(state.vx, state.vz)
	aligner.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(math.cos(state.heading), 0, math.sin(state.heading)))
end

function VehicleController:Start()
	RunService.Heartbeat:Connect(drive)
	local ok, result = pcall(function()
		local playerModule = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		return (require :: any)(playerModule):GetControls()
	end)
	if ok then
		controls = result
	else
		warn(`[VehicleController] ControlModule indisponible, seul Humanoid.MoveDirection sera utilisé : {result}`)
	end
end

return VehicleController
