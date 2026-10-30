--!strict
-- Validation des commandes du panneau de test (Studio uniquement). Pure : testée sous Lune.
-- Même en Studio, le serveur ne fait pas confiance au client : type, bornes et liste blanche.
local EventConfig = require("../config/EventConfig")
local VehicleConfig = require("../config/VehicleConfig")

export type Command =
	{ kind: "tier", tier: number }
	| { kind: "money" }
	| { kind: "meteor" }
	| { kind: "weather", weather: string }
	| { kind: "items" }

local DevCommands = {}

DevCommands.MONEY_GRANT = 10_000 -- montant fixe : le client ne choisit jamais une somme
DevCommands.ITEMS_GRANT = 3 -- exemplaires de chaque objet de sabotage
DevCommands.GEMS_GRANT = 50

local function isWeather(value: any): boolean
	for _, weather in EventConfig.WEATHERS do
		if weather.id == value then
			return true
		end
	end
	return false
end

function DevCommands.parse(kind: any, value: any): Command?
	if kind == "tier" and typeof(value) == "number" and value == value // 1 and VehicleConfig.TIERS[value] then
		return { kind = "tier", tier = value }
	end
	if kind == "weather" and isWeather(value) then
		return { kind = "weather", weather = value }
	end
	if kind == "money" or kind == "meteor" or kind == "items" then
		return { kind = kind } :: any
	end
	return nil
end

return DevCommands
