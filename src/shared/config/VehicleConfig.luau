--!strict
-- Paliers outils/véhicules — CDC §5 (tableau des paliers). CutPower : décision A2.
local Freeze = require("../util/Freeze")

export type TierDef = {
	id: number,
	name: string,
	price: number,
	hitboxStuds: number,
	speed: number,
	mass: number,
	capacity: number,
	cutPower: number,
	isVehicle: boolean,
}

local TIERS: { TierDef } = {
	{
		id = 1,
		name = "Mains Nues",
		price = 0,
		hitboxStuds = 4,
		speed = 16,
		mass = 10,
		capacity = 25,
		cutPower = 1,
		isVehicle = false,
	},
	{
		id = 2,
		name = "Faux en Briques",
		price = 150,
		hitboxStuds = 7,
		speed = 18,
		mass = 15,
		capacity = 60,
		cutPower = 2,
		isVehicle = false,
	},
	{
		id = 3,
		name = "Tondeuse Rouge",
		price = 1_200,
		hitboxStuds = 10,
		speed = 24,
		mass = 35,
		capacity = 180,
		cutPower = 5,
		isVehicle = true,
	},
	{
		id = 4,
		name = "Tracteur Fermier",
		price = 12_500,
		hitboxStuds = 15,
		speed = 30,
		mass = 80,
		capacity = 600,
		cutPower = 12,
		isVehicle = true,
	},
	{
		id = 5,
		name = "Double Faucheuse Turbo",
		price = 85_000,
		hitboxStuds = 20,
		speed = 35,
		mass = 135,
		capacity = 2_000,
		cutPower = 30,
		isVehicle = true,
	},
	{
		id = 6,
		name = "Moissonneuse Dorée XL",
		price = 450_000,
		hitboxStuds = 28,
		speed = 40,
		mass = 220,
		capacity = 8_500,
		cutPower = 70,
		isVehicle = true,
	},
	{
		id = 7,
		name = "Moissonneuse Cyber-Laser",
		price = 3_500_000,
		hitboxStuds = 38,
		speed = 46,
		mass = 350,
		capacity = 35_000,
		cutPower = 150,
		isVehicle = true,
	},
}

-- Carrosserie des engins (paliers 3 à 7) : la taille grandit avec le palier (CDC §2 « lisibilité »).
export type BodyDef = {
	length: number,
	width: number,
	height: number,
	color: { number },
	accent: { number }, -- pare-chocs, barre de coupe, néons
	hasBigRearWheels: boolean, -- silhouette de tracteur
	hasHeader: boolean, -- barre de coupe frontale (moissonneuses)
	hasNeon: boolean,
}

local BODIES: { [number]: BodyDef } = {
	[3] = { -- Tondeuse Rouge
		length = 6,
		width = 4,
		height = 2,
		color = { 196, 40, 28 },
		accent = { 248, 248, 248 },
		hasBigRearWheels = false,
		hasHeader = false,
		hasNeon = false,
	},
	[4] = { -- Tracteur Fermier
		length = 9,
		width = 6,
		height = 3,
		color = { 75, 151, 75 },
		accent = { 245, 205, 48 },
		hasBigRearWheels = true,
		hasHeader = false,
		hasNeon = false,
	},
	[5] = { -- Double Faucheuse Turbo
		length = 11,
		width = 8,
		height = 3,
		color = { 13, 105, 172 },
		accent = { 196, 40, 28 },
		hasBigRearWheels = true,
		hasHeader = true,
		hasNeon = false,
	},
	[6] = { -- Moissonneuse Dorée XL
		length = 14,
		width = 10,
		height = 4,
		color = { 245, 205, 48 },
		accent = { 196, 40, 28 },
		hasBigRearWheels = false,
		hasHeader = true,
		hasNeon = false,
	},
	[7] = { -- Moissonneuse Cyber-Laser
		length = 17,
		width = 12,
		height = 4,
		color = { 27, 42, 53 },
		accent = { 98, 37, 209 },
		hasBigRearWheels = false,
		hasHeader = true,
		hasNeon = true,
	},
}

return Freeze.deep({
	TIERS = TIERS,
	BODIES = BODIES,
	FULL_SPEED_PENALTY = 0.10, -- CDC §4 : -10 % de vitesse quand le sac est plein
	FOOT_SPEED = 18, -- A54 : vitesse à pied d'un joueur qui possède un engin, hors du champ
	RIDE_CHECK_INTERVAL = 0.25, -- A54 : secondes entre deux vérifications « dans le champ ? »
	REBIRTH_MASS_BONUS = 0.15, -- CDC §5/§7 (appliqué une seule fois, cf. ANALYSE A15)
	TITAN_MASS_MULTIPLIER = 2.5, -- CDC §9

	-- Contrôleur d'arcade (CDC §5) : cap qui pivote vers la direction voulue, adhérence avant forte et
	-- adhérence latérale faible pour un dérapage fluide. Unités : rad/s et 1/s (constantes de lissage).
	HANDLING = {
		TURN_RATE = 3.2,
		GRIP = 4,
		LATERAL_GRIP = 2.2,
		INPUT_DEADZONE = 0.05,
		ALIGN_RESPONSIVENESS = 40,
		SEAT_HEIGHT = 1.5, -- le pilote est soudé 1,5 stud au-dessus de la carrosserie
		FRICTION = 0.05, -- la carrosserie glisse : c'est LinearVelocity qui la déplace
	},
	-- Noms des pièces de l'engin, partagés entre VehicleService (serveur) et VehicleController (client).
	PARTS = {
		BODY = "Vehicle",
		MOVER = "Mover", -- LinearVelocity
		ALIGNER = "Aligner", -- AlignOrientation
	},
	SPEED_TOLERANCE = 1.5, -- au-delà de 150 % de la vitesse du palier, le serveur journalise (anti-triche)
	SPEED_CHECK_INTERVAL = 1, -- secondes
})
