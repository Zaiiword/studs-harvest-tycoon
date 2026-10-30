--!strict
-- Validation des commandes du panneau de test (Studio uniquement). Pure : testée sous Lune.
-- Même en Studio, le serveur ne fait pas confiance au client : type, bornes et liste blanche.
local VehicleConfig = require("../config/VehicleConfig")

export type Command = { kind: "tier", tier: number } | { kind: "money" }

local DevCommands = {}

DevCommands.MONEY_GRANT = 10_000 -- montant fixe : le client ne choisit jamais une somme

function DevCommands.parse(kind: any, value: any): Command?
	if kind == "tier" and typeof(value) == "number" and value == value // 1 and VehicleConfig.TIERS[value] then
		return { kind = "tier", tier = value }
	end
	if kind == "money" then
		return { kind = "money" }
	end
	return nil
end

return DevCommands
