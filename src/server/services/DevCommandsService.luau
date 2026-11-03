--!strict
-- Panneau de test, actif uniquement dans Roblox Studio (jamais en jeu publié) : palier, argent, boss
-- Météorite, météo et objets de sabotage à la demande. Commandes validées par DevCommands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SabotageConfig = require(ReplicatedStorage.Shared.config.SabotageConfig)
local DevCommands = require(ReplicatedStorage.Shared.net.DevCommands)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local EventService = require(script.Parent.EventService)
local InventoryService = require(script.Parent.InventoryService)
local TycoonService = require(script.Parent.TycoonService)
local MonetizationService = require(script.Parent.MonetizationService)

local DevCommandsService = {}

local limiter = RateLimiter.new(5, 2)

local function grantItems(player: Player)
	for _, item in SabotageConfig.ITEMS do
		InventoryService.add(player, item.id, DevCommands.ITEMS_GRANT)
	end
	for trophy in SabotageConfig.TROPHIES do -- Œufs Légendaires, pour tester l'éclosion
		InventoryService.add(player, trophy, DevCommands.ITEMS_GRANT)
	end
	TycoonService.grantGems(player, DevCommands.GEMS_GRANT)
end

local function onCommand(player: Player, kind: any, value: any)
	local command = DevCommands.parse(kind, value)
	if not command or not limiter:allow(player, os.clock()) then
		return
	end
	if command.kind == "tier" then
		player:SetAttribute(PlayerAttributes.TIER, (command :: any).tier)
	elseif command.kind == "money" then
		TycoonService.grant(player, (command :: any).amount)
	elseif command.kind == "meteor" then
		EventService.summonMeteor()
	elseif command.kind == "weather" then
		EventService.forceWeather((command :: any).weather)
	elseif command.kind == "pass" then
		MonetizationService.togglePass(player, (command :: any).key)
	elseif command.kind == "product" then
		MonetizationService.grantProduct(player, (command :: any).key) -- achat simulé, sans Robux
	else
		grantItems(player)
	end
end

function DevCommandsService:Init()
	if RunService:IsStudio() then
		Remotes.event(Remotes.DEV_COMMAND).OnServerEvent:Connect(onCommand)
	end
end

function DevCommandsService:Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return DevCommandsService
