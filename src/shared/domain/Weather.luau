--!strict
-- Météo dynamique serveur (CDC §6, A10), sans API Roblox : phase du cycle et tirage de l'événement.
local EventConfig = require("../config/EventConfig")

export type Phase = { isEvent: boolean, remaining: number }

local Weather = {}

-- Phase du cycle à `elapsed` secondes depuis son début : beau temps, puis événement.
function Weather.phaseAt(elapsed: number): Phase
	local inCycle = elapsed % EventConfig.WEATHER_CYCLE_SECONDS
	if inCycle < EventConfig.WEATHER_CLEAR_SECONDS then
		return { isEvent = false, remaining = EventConfig.WEATHER_CLEAR_SECONDS - inCycle }
	end
	return { isEvent = true, remaining = EventConfig.WEATHER_CYCLE_SECONDS - inCycle }
end

-- Tire un événement météo au hasard (générateur injecté pour des tests déterministes).
function Weather.pick(rng: () -> number): EventConfig.WeatherDef
	local weathers = EventConfig.WEATHERS
	return weathers[math.clamp(math.floor(rng() * #weathers) + 1, 1, #weathers)]
end

function Weather.byId(id: string): EventConfig.WeatherDef
	for _, weather in EventConfig.WEATHERS do
		if weather.id == id then
			return weather
		end
	end
	return EventConfig.CLEAR
end

return Weather
