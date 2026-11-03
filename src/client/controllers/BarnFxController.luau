--!strict
-- Quand on entre dans une grange, son toit s'efface pour le joueur local (A56) : sinon la caméra, au-dessus du
-- joueur, ne verrait que les tuiles. Purement local : personne d'autre n'est concerné.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FarmConfig = require(ReplicatedStorage.Shared.config.FarmConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)

local BarnFxController = {}

type Roof = { base: MapGeometry.Placement, isFaded: boolean }

local BARN = FarmConfig.BARN
local CHECK_INTERVAL = 0.2
local FADED = 0.85 -- le toit reste deviné, pour qu'on sache qu'il est là

local localPlayer = Players.LocalPlayer
local bases = MapGeometry.baseCenters()
local roofs: { [Model]: Roof } = {}
local elapsed = 0

local function register(model: Model)
	local floor = model:FindFirstAncestorWhichIsA("BasePart")
	local index = floor and floor:GetAttribute(PlayerAttributes.BASE_INDEX)
	local base = typeof(index) == "number" and bases[index]
	if base then
		roofs[model] = { base = base, isFaded = false }
	end
end

local function setFaded(model: Model, roof: Roof, isFaded: boolean)
	roof.isFaded = isFaded
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if isFaded then FADED else 0
		end
	end
end

local function refresh()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for model, roof in roofs do
		local isInside = false
		if root then
			local localX, localZ = MapGeometry.worldToBase(roof.base, root.Position.X, root.Position.Z)
			isInside = localX >= BARN.BACK_X and localX <= BARN.FRONT_X and math.abs(localZ) <= BARN.HALF_Z
		end
		if isInside ~= roof.isFaded then
			setFaded(model, roof, isInside)
		end
	end
end

local function onDescendantAdded(instance: Instance)
	if instance:IsA("Model") and instance:GetAttribute(TycoonConfig.FADE_ATTRIBUTE) then
		register(instance)
	end
end

function BarnFxController:Start()
	local map = Workspace:WaitForChild("Map")
	map.DescendantAdded:Connect(onDescendantAdded)
	map.DescendantRemoving:Connect(function(instance)
		if instance:IsA("Model") then
			roofs[instance] = nil
		end
	end)
	for _, instance in map:GetDescendants() do
		onDescendantAdded(instance)
	end
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= CHECK_INTERVAL then
			elapsed = 0
			refresh()
		end
	end)
end

return BarnFxController
