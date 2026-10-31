--!strict
-- Arrivée animée de ce qu'on achète à l'usine (A53) : les briques d'une machine ou d'une décoration neuve
-- tombent du ciel en rebondissant, une à une, dans une gerbe d'étincelles. Purement local : le serveur ne fait
-- qu'horodater le modèle (attribut BuiltAt) ; un joueur qui arrive plus tard voit le modèle déjà en place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)

local BuildFxController = {}

local FX = UiConfig.BUILD_FX
local DROP = TweenInfo.new(FX.SECONDS, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
local BLADES_NAME = "MillBlades" -- ailes animées en continu par TycoonAnimController : on n'y touche pas
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARKLE_COLORS = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 255, 255))
local CLEANUP_SECONDS = 2

local localPlayer = Players.LocalPlayer
local sound: Sound? = nil

local function isMine(model: Model): boolean
	local floor = model:FindFirstAncestorWhichIsA("BasePart")
	local index = floor and floor:GetAttribute(PlayerAttributes.BASE_INDEX)
	return index ~= nil and index == localPlayer:GetAttribute(PlayerAttributes.BASE_INDEX)
end

local function sparkle(position: Vector3)
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = SPARKLE_COLORS
	emitter.LightEmission = 1
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Size = NumberSequence.new(1.2, 0)
	emitter.Enabled = false
	emitter.Parent = holder
	holder.Parent = Workspace
	emitter:Emit(FX.SPARKLES)
	task.delay(CLEANUP_SECONDS, holder.Destroy, holder)
end

local function animate(model: Model)
	local parts: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not part:FindFirstAncestor(BLADES_NAME) then
			table.insert(parts, part)
		end
	end
	for index, part in parts do
		local final = part.CFrame
		part.CFrame = final + Vector3.new(0, FX.DROP, 0)
		part.LocalTransparencyModifier = 1
		task.delay(math.min(index * FX.STAGGER, FX.MAX_STAGGER), function()
			part.LocalTransparencyModifier = 0
			TweenService:Create(part, DROP, { CFrame = final }):Play()
		end)
	end
	sparkle(model:GetPivot().Position)
	if sound and isMine(model) then
		SoundService:PlayLocalSound(sound)
	end
end

local function onDescendantAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local builtAt = instance:GetAttribute(TycoonConfig.BUILD_ANIM_ATTRIBUTE)
	if typeof(builtAt) == "number" and Workspace:GetServerTimeNow() - builtAt < FX.FRESH_SECONDS then
		task.defer(animate, instance) -- laisse arriver toutes les briques du modèle
	end
end

function BuildFxController:Start()
	if AssetIds.REWARD_SOUND ~= "" then
		local reward = Instance.new("Sound")
		reward.SoundId = AssetIds.REWARD_SOUND
		reward.Parent = SoundService
		sound = reward
	end
	Workspace.DescendantAdded:Connect(onDescendantAdded)
end

return BuildFxController
