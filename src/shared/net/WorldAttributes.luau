--!strict
-- Contrat réseau : état global des événements, posé par EventService sur ReplicatedStorage et lu par les
-- clients (HUD, effets météo). Les instants sont en temps serveur (workspace:GetServerTimeNow()).
return table.freeze({
	WEATHER = "Weather", -- id de la météo en cours (« Clear » par défaut)
	WEATHER_ENDS_AT = "WeatherEndsAt",
	HOTSPOT_ENDS_AT = "HotspotEndsAt",
	METEOR_AT = "MeteorAt", -- prochain impact (ou impact en cours)
	BOSS_HP = "BossHp", -- 0 quand aucun boss n'est présent
	BOSS_MAX_HP = "BossMaxHp",
	BOSS_LEAVES_AT = "BossLeavesAt",
	VEHICLE_SPEED_MULTIPLIER = "VehicleSpeedMultiplier", -- Tempête de Vent : 1,25
})
