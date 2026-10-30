--!strict
-- Événements dynamiques (CDC §6 ; décisions A10, A11, A40, A41) : météo, hotspot et boss Météorite.
local Freeze = require("../util/Freeze")

export type WeatherDef = {
	id: string,
	name: string,
	description: string,
	valueMultiplier: number, -- valeur de chaque blé coupé
	vehicleSpeedMultiplier: number,
	knockbackMultiplier: number,
	rainbowBoost: number, -- multiplie la chance Arc-en-ciel à la repousse
}

local CLEAR: WeatherDef = {
	id = "Clear",
	name = "Beau temps",
	description = "",
	valueMultiplier = 1,
	vehicleSpeedMultiplier = 1,
	knockbackMultiplier = 1,
	rainbowBoost = 1,
}

return Freeze.deep({
	-- A10 : un cycle toutes les 6 min, 4 min de beau temps puis 2 min d'un événement tiré au sort.
	WEATHER_CYCLE_SECONDS = 360,
	WEATHER_CLEAR_SECONDS = 240,
	CLEAR = CLEAR,
	WEATHERS = {
		{
			id = "GoldenRain",
			name = "Pluie Dorée",
			description = "Tous les blés valent ×2 !",
			valueMultiplier = 2,
			vehicleSpeedMultiplier = 1,
			knockbackMultiplier = 1,
			rainbowBoost = 1,
		},
		{
			id = "WindStorm",
			name = "Tempête de Vent",
			description = "Véhicules +25 % et chocs amplifiés !",
			valueMultiplier = 1,
			vehicleSpeedMultiplier = 1.25,
			knockbackMultiplier = 1.5,
			rainbowBoost = 1,
		},
		{
			id = "NeonNight",
			name = "Nuit Néon",
			description = "Blés Arc-en-ciel ×5 !",
			valueMultiplier = 1,
			vehicleSpeedMultiplier = 1,
			knockbackMultiplier = 1,
			rainbowBoost = 5,
		},
	} :: { WeatherDef },

	-- A11 : zone de 20 studs à valeur ×3, qui se déplace toutes les 90 s dans le Blé Diamant
	-- (le cœur de notre carte est l'arène du boss, sans blé).
	HOTSPOT = {
		RADIUS = 10,
		VALUE_MULTIPLIER = 3,
		MOVE_SECONDS = 90,
		BAND = "DiamondWheat",
		LATERAL_FILL = 0.8, -- reste à l'écart des murs
		COLOR = { 255, 89, 89 },
		BEAM_HEIGHT = 40,
	},

	-- CDC §6 : Épi Géant de Cristal de 50 000 PV toutes les 12 minutes, au cœur de l'arène.
	METEOR = {
		INTERVAL_SECONDS = 720,
		MAX_HP = 50_000,
		DURATION_SECONDS = 180, -- A40 : il repart s'il n'est pas abattu à temps
		HIT_RADIUS = 14, -- distance au boss (en plus de la hitbox de l'outil) pour le frapper
		-- A40 : dégâts par coupe = puissance de coupe × 1. Une Cyber-Laser seule met ~50 s, quatre engins
		-- moyens ~1 min : le boss reste une affaire collective (CDC §6 « tous les tracteurs ensemble »).
		DAMAGE_PER_CUT_POWER = 1,
		HIT_INTERVAL = 0.15, -- comme la récolte (CDC §4)
		REWARD_TOP = 3,
		REWARD_INCOME_MULTIPLIER = 3, -- CDC §6 : ×3 pendant 5 minutes
		REWARD_SECONDS = 300,
		REWARD_ITEM = "LegendaryEgg", -- ouvert au Sprint 6 (Pets)
		ANNOUNCE_SECONDS = 20, -- le HUD prévient avant l'impact
		HEIGHT = 30,
		WIDTH = 10,
		COLOR = { 128, 230, 255 },
	},
})
