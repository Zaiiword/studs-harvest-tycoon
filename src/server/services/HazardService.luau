--!strict
-- Zones dangereuses de la carte : tomber à l'eau (fossé ou bord) renvoie le joueur sur sa base, sans perte de blé
-- (CDC §6 « Protection anti-frustration »). Dépendances : MapService (pièces), PlotService (téléportation).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)

local HazardService = {}

-- Un personnage touche le fond avec plusieurs pièces à la fois : on ne le renvoie qu'une fois.
local returnLimiter = RateLimiter.new(1, 1 / MapConfig.RETURN_COOLDOWN)

local function onWaterTouched(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if player and returnLimiter:allow(player, os.clock()) then
		PlotService.returnToBase(player)
	end
end

function HazardService:Start()
	local water = MapService.water()
	if water then
		water.Touched:Connect(onWaterTouched)
	end
	Players.PlayerRemoving:Connect(function(player)
		returnLimiter:forget(player)
	end)
end

return HazardService
