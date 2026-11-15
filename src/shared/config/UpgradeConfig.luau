--!strict
-- Améliorations permanentes payées en gemmes (A65) : le débouché des gemmes gagnées aux Rebirths, aux succès, à la
-- connexion et aux quêtes. Conservées au Rebirth. Chaque niveau ajoute `perLevel` au multiplicateur de son effet.
local Freeze = require("../util/Freeze")

export type Effect = "bag" | "cut" | "income"
export type UpgradeDef = {
	id: string,
	name: string,
	icon: string,
	description: string,
	effect: Effect,
	perLevel: number,
	prices: { number }, -- prix en gemmes de chaque niveau ; leur nombre est le niveau maximal
}

return Freeze.deep({
	UPGRADES = {
		{
			id = "Bag",
			name = "Sac XXL",
			icon = "🎒",
			description = "+10 % de places / niveau",
			effect = "bag",
			perLevel = 0.1,
			prices = { 10, 25, 50, 100, 200 },
		},
		{
			id = "Blades",
			name = "Lames Affûtées",
			icon = "⚔️",
			description = "+15 % de coupe / niveau",
			effect = "cut",
			perLevel = 0.15,
			prices = { 10, 25, 50, 100, 200 },
		},
		{
			id = "Accountant",
			name = "Comptable Génial",
			icon = "📈",
			description = "+10 % de revenus / niveau",
			effect = "income",
			perLevel = 0.1,
			prices = { 15, 35, 75, 150, 300 },
		},
	} :: { UpgradeDef },
})
