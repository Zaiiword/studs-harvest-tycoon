--!strict
-- Bousculade PvP (CDC §5 « Knockback serveur », §6 « Protection anti-frustration », décisions A29 à A31).
local Freeze = require("../util/Freeze")

return Freeze.deep({
	DETECTION_INTERVAL = 0.1, -- vérification de proximité à 10 Hz (docs/ANALYSE_CDC.md §5)
	MIN_IMPACT_SPEED = 8, -- en dessous (studs/s), deux véhicules se frôlent sans s'éjecter
	PAIR_COOLDOWN = 1, -- secondes avant qu'une même paire puisse se rebousculer
	CONTACT_MARGIN = 1, -- tolérance de contact (studs) en plus des rayons, pour compenser la latence

	DIZZY_SECONDS = 0.8, -- CDC §6 : effet de tournis
	IMMUNITY_SECONDS = 15, -- CDC §6 : bulle d'immunité aux chocs
	DIZZY_SPIN_SPEED = 4 * math.pi, -- rad/s pendant le tournis

	-- A30 : la « Force d'Éjection » du CDC devient une vitesse d'éjection (studs/s), bornée.
	LAUNCH_SCALE = 0.5,
	MIN_LAUNCH_SPEED = 30,
	MAX_LAUNCH_SPEED = 140,
	VERTICAL_RATIO = 0.45, -- part verticale de l'éjection (effet comique, sort de la zone)
	BUMPER_BONUS = 1, -- « BonusPareChocs » par défaut ; boosts éventuels plus tard (Sprint 8)

	-- A29 : « Zone sécurisée débutant » (CDC §3, anneau 1) et barre des bases : pas de bousculade.
	SAFE_ZONES = { GreenWheat = true, Plaza = true } :: { [string]: boolean },
	ON_FOOT_RADIUS = 1.5, -- rayon de contact d'un joueur à pied

	BUBBLE_COLOR = { 4, 175, 236 },
	BUBBLE_TRANSPARENCY = 0.75,
	BUBBLE_PADDING = 2, -- la bulle dépasse le véhicule de 2 studs
})
