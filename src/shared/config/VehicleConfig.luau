--!strict
-- Paliers outils/véhicules — CDC §5 (tableau des paliers). CutPower : décision A2.

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

for _, tier in TIERS do
	table.freeze(tier)
end

return table.freeze({
	TIERS = table.freeze(TIERS),
	FULL_SPEED_PENALTY = 0.10, -- CDC §4 : -10 % de vitesse quand le sac est plein
	REBIRTH_MASS_BONUS = 0.15, -- CDC §5/§7 (appliqué une seule fois, cf. ANALYSE A15)
	TITAN_MASS_MULTIPLIER = 2.5, -- CDC §9
})
