--!strict
-- « Bon retour ! » (A60) : à la connexion, montre ce que l'usine a produit pendant l'absence du joueur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Format = require(ReplicatedStorage.Shared.util.Format)
local RewardPopup = require(script.Parent.Parent.ui.RewardPopup)

local OfflineController = {}

local ICON = "factory"
local HEADING = "BON RETOUR !"
local SECONDS_PER_HOUR, SECONDS_PER_MINUTE = 3600, 60

-- 11 520 s → « 3 h 12 » ; 300 s → « 5 min ».
local function away(seconds: number): string
	local hours = seconds // SECONDS_PER_HOUR
	local minutes = (seconds % SECONDS_PER_HOUR) // SECONDS_PER_MINUTE
	if hours > 0 then
		return string.format("%d h %02d", hours, minutes)
	end
	return `{minutes} min`
end

function OfflineController:Start()
	Remotes.event(Remotes.OFFLINE_EARNINGS).OnClientEvent:Connect(function(seconds: number, earned: number)
		RewardPopup.show(ICON, `+{Format.money(earned)} $ en {away(seconds)} d'absence`, HEADING)
	end)
end

return OfflineController
