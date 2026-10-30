--!strict
-- Pets qui suivent leur maître en sautillant (CDC §7.2, module « PetFollowerClient » du §12).
-- Chaque client construit localement les Pets de TOUS les joueurs à partir de l'attribut « EquippedPets » :
-- aucune pièce de Pet n'est répliquée par le serveur, et le mouvement ne coûte rien au réseau.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local PetVisualConfig = require(ReplicatedStorage.Shared.config.PetVisualConfig)
local Pets = require(ReplicatedStorage.Shared.domain.Pets)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local PetModels = require(script.Parent.Parent.render.PetModels)

local PetFollowerController = {}

type Follower = { model: Model, key: string, cframe: CFrame, isRainbow: boolean }

local FOLLOW = PetConfig.FOLLOW

local folder: Folder
local followers: { [Player]: { Follower } } = {}
local clock = 0

local function clear(player: Player)
	for _, follower in followers[player] or {} do
		follower.model:Destroy()
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local list: { Follower } = {}
	for _, key in Pets.decodeEquipped(player:GetAttribute(PlayerAttributes.EQUIPPED_PETS)) do
		local model = PetModels.build(key, FOLLOW.SIZE / 2)
		if model then
			model.Parent = folder
			local _, variant = Pets.parse(key)
			local isRainbow = variant ~= nil and variant.id == "Rainbow"
			table.insert(list, { model = model, key = key, cframe = CFrame.new(), isRainbow = isRainbow })
		end
	end
	followers[player] = list
end

-- Place de chaque Pet derrière le joueur, en arc de cercle, avec un petit saut périodique.
local function targetFor(root: BasePart, slot: number, count: number): CFrame
	local spread = (slot - (count + 1) / 2) * FOLLOW.SPREAD
	local hop = math.abs(math.sin(clock * FOLLOW.HOP_SPEED + slot)) * FOLLOW.HOP_HEIGHT
	local behind = root.CFrame * CFrame.new(spread, 0, FOLLOW.DISTANCE)
	local ground = behind.Position.Y - root.Size.Y / 2 - 2 -- environ le niveau des pieds
	return CFrame.lookAlong(Vector3.new(behind.X, ground + hop, behind.Z), root.CFrame.LookVector)
end

local function animate(deltaTime: number)
	clock += deltaTime
	local alpha = 1 - math.exp(-FOLLOW.SMOOTHING * deltaTime)
	local rainbow = Color3.fromHSV((clock * PetVisualConfig.RAINBOW_HUE_SPEED) % 1, 1, 1)
	for player, list in followers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for slot, follower in list do
			if root then
				follower.cframe = follower.cframe:Lerp(targetFor(root, slot, #list), alpha)
				follower.model:PivotTo(follower.cframe)
			end
			if follower.isRainbow then
				for _, part in follower.model:GetChildren() do
					if part:IsA("BasePart") and part:GetAttribute(PetModels.MAIN_ATTRIBUTE) then
						part.Color = rainbow
					end
				end
			end
		end
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(PlayerAttributes.EQUIPPED_PETS):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function PetFollowerController:Init()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = Workspace
end

function PetFollowerController:Start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.RenderStepped:Connect(animate)
end

return PetFollowerController
