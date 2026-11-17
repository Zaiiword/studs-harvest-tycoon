--!strict
-- Nouvel outil (A68) : acheter la Faux ou la Tondeuse est le plus grand moment des premières minutes, il mérite une
-- fête. Quand le palier monte en cours de partie, une pop-up montre le nouvel outil et ce qu'il change (sac, coupe,
-- vitesse) ; pour un engin, elle rappelle qu'il apparaît à l'entrée du champ (A54). Rien au chargement du profil ni
-- au Rebirth (le palier redescend).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconConfig = require(ReplicatedStorage.Shared.config.IconConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Format = require(ReplicatedStorage.Shared.util.Format)
local RewardPopup = require(script.Parent.Parent.ui.RewardPopup)

local TierUpController = {}

local localPlayer = Players.LocalPlayer
local lastTier: number? = nil

local function describe(tier: VehicleConfig.TierDef, previous: VehicleConfig.TierDef): string
	local cut = tier.cutPower / previous.cutPower
	local text = `{tier.name}\nSac {Format.money(tier.capacity)} · Coupe ×{math.floor(cut * 10 + 0.5) / 10}`
	if tier.isVehicle then
		return text .. "\nIl t'attend à l'entrée du champ !"
	end
	return text
end

local function onTierChanged()
	local value = localPlayer:GetAttribute(PlayerAttributes.TIER)
	if typeof(value) ~= "number" then
		return
	end
	local previous = lastTier
	lastTier = value
	if not previous or value <= previous or localPlayer:GetAttribute(PlayerAttributes.IS_DATA_LOADED) ~= true then
		return
	end
	local tier, before = VehicleConfig.TIERS[value], VehicleConfig.TIERS[previous]
	if tier and before then
		RewardPopup.show(IconConfig.TIERS[value] or "star", describe(tier, before), "NOUVEL OUTIL !")
	end
end

function TierUpController:Start()
	local value = localPlayer:GetAttribute(PlayerAttributes.TIER)
	lastTier = if typeof(value) == "number" then value else nil
	localPlayer:GetAttributeChangedSignal(PlayerAttributes.TIER):Connect(onTierChanged)
end

return TierUpController
