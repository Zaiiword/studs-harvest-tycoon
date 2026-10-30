--!strict
-- Commandes de test, actives uniquement dans Roblox Studio (jamais en jeu publié) :
--   !tier N  → passe au palier N (1 à 7) pour essayer les engins avant la boutique du Sprint 3.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)

local DevCommandsService = {}

local function onChatted(player: Player, message: string)
	local tier = tonumber(string.match(message, "^!tier%s+(%d+)$"))
	if tier and VehicleConfig.TIERS[tier] then
		player:SetAttribute(PlayerAttributes.TIER, tier)
	end
end

local function watch(player: Player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end

function DevCommandsService:Start()
	if not RunService:IsStudio() then
		return
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return DevCommandsService
