--!strict
-- Animations locales des usines (CDC §7.1 « le blé tombe sur un tapis roulant ») : les ailes des moulins
-- tournent, et des briques de blé défilent sur le tapis des usines qui produisent (IncomePerSecond > 0).
-- Purement visuel et client : aucune pièce créée ici n'est répliquée.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DecorConfig = require(ReplicatedStorage.Shared.config.DecorConfig)
local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local TycoonAnimController = {}

type Belt = { conveyor: BasePart, bricks: { Part }, baseIndex: number }

local BLADES_NAME = "MillBlades"
local CONVEYOR_NAME = "Conveyor"
local BRICK_LIFT = 0.8

local blades: { [Model]: CFrame } = {} -- modèle → CFrame de repos du moyeu
local belts: { [BasePart]: Belt } = {}
local angle = 0
local scroll = 0

local function baseIndexOf(instance: Instance): number?
	local floor = instance:FindFirstAncestorWhichIsA("BasePart")
	local index = floor and floor:GetAttribute(PlayerAttributes.BASE_INDEX)
	return if typeof(index) == "number" then index else nil
end

local function isProducing(baseIndex: number): boolean
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(PlayerAttributes.BASE_INDEX) == baseIndex then
			local income = player:GetAttribute(PlayerAttributes.INCOME_PER_SECOND)
			return typeof(income) == "number" and income > 0
		end
	end
	return false
end

local function addBelt(conveyor: BasePart)
	local baseIndex = baseIndexOf(conveyor)
	if not baseIndex then
		return
	end
	local count = math.floor(conveyor.Size.Z / DecorConfig.CONVEYOR_BRICK_SPACING)
	local bricks: { Part } = {}
	for k = 1, count do
		local brick = Bricks.decor(`BeltBrick{k}`, Vector3.one * FieldConfig.BRICK_SIZE * 1.5, FieldConfig.BRICK_COLOR)
		brick.Parent = conveyor
		table.insert(bricks, brick)
	end
	belts[conveyor] = { conveyor = conveyor, bricks = bricks, baseIndex = baseIndex }
end

local function onDescendantAdded(instance: Instance)
	if instance:IsA("Model") and instance.Name == BLADES_NAME then
		task.defer(function() -- laisse le temps à PrimaryPart d'être répliqué
			local model = instance :: Model
			if model.PrimaryPart then
				blades[model] = model.PrimaryPart.CFrame
			end
		end)
	elseif instance:IsA("BasePart") and instance.Name == CONVEYOR_NAME then
		addBelt(instance)
	end
end

local function onDescendantRemoving(instance: Instance)
	if instance:IsA("Model") then
		blades[instance] = nil
	elseif instance:IsA("BasePart") then
		belts[instance] = nil
	end
end

local function animateBelt(belt: Belt)
	local conveyor = belt.conveyor
	local isVisible = isProducing(belt.baseIndex)
	local spacing = DecorConfig.CONVEYOR_BRICK_SPACING
	local halfLength = conveyor.Size.Z / 2
	for k, brick in belt.bricks do
		brick.Transparency = if isVisible then 0 else 1
		if isVisible then
			local offset = ((k - 1) * spacing + scroll) % (halfLength * 2) - halfLength
			brick.CFrame = conveyor.CFrame * CFrame.new(0, conveyor.Size.Y / 2 + BRICK_LIFT, offset)
		end
	end
end

local function onRenderStepped(deltaTime: number)
	angle = (angle + deltaTime * DecorConfig.MILL_SPIN_SPEED) % (2 * math.pi)
	scroll += deltaTime * DecorConfig.CONVEYOR_BRICK_SPEED
	for model, rest in blades do
		model:PivotTo(rest * CFrame.Angles(angle, 0, 0)) -- l'axe des ailes est l'axe X du moyeu
	end
	for _, belt in belts do
		animateBelt(belt)
	end
end

function TycoonAnimController:Start()
	local map = Workspace:WaitForChild("Map")
	map.DescendantAdded:Connect(onDescendantAdded)
	map.DescendantRemoving:Connect(onDescendantRemoving)
	for _, instance in map:GetDescendants() do
		onDescendantAdded(instance)
	end
	RunService.RenderStepped:Connect(onRenderStepped)
end

return TycoonAnimController
