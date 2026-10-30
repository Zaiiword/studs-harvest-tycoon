--!strict
-- Panneau de test, actif uniquement dans Roblox Studio (jamais en jeu publié) : changer de palier pour
-- essayer les engins, se créditer de l'argent pour tester les achats. Commandes validées par DevCommands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DevCommands = require(ReplicatedStorage.Shared.net.DevCommands)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local TycoonService = require(script.Parent.TycoonService)

local DevCommandsService = {}

local limiter = RateLimiter.new(5, 2)

local function onCommand(player: Player, kind: any, value: any)
	local command = DevCommands.parse(kind, value)
	if not command or not limiter:allow(player, os.clock()) then
		return
	end
	if command.kind == "tier" then
		player:SetAttribute(PlayerAttributes.TIER, command.tier)
	else
		TycoonService.grant(player, DevCommands.MONEY_GRANT)
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
