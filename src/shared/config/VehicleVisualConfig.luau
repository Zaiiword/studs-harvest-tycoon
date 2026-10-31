--!strict
-- Apparence des engins (CDC §2 « taille de sa moissonneuse », §5 ; décision A52). Purement visuel : construit
-- et animé côté client (VehicleVisualController) autour de la carrosserie physique, qui reste invisible.
-- Repère : origine au centre de la carrosserie physique, avant = -Z, haut = +Y, sol à y = -hauteur / 2.
-- Le pilote se tient debout au centre, de y = haut - 0,5 à y = haut + 5,2 : aucune pièce pleine à cet endroit.
local Freeze = require("../util/Freeze")

export type Role = "static" | "wheel" | "reel" | "glow" | "hover"

export type Piece = {
	paint: string, -- clé de la palette du palier
	size: { number },
	at: { number },
	tilt: { number }?, -- radians (x, y, z)
	shape: string?, -- « Cylinder » (axe X), « Ball » ; bloc par défaut
	role: Role?,
	radius: number?, -- roues : rayon au sol, pour une rotation sans glissement
	light: boolean?, -- phare : ajoute un SpotLight vers l'avant
	beacon: boolean?, -- gyrophare : ajoute un PointLight qui pulse avec le néon
}

export type Effect = { kind: "exhaust" | "thruster", at: { number } }

export type Model = { pieces: { Piece }, effects: { Effect } }

local HALF_TURN = math.pi / 2

local function p(paint: string, size: { number }, at: { number }, extra: { [string]: any }?): Piece
	local piece: any = { paint = paint, size = size, at = at }
	for key, value in extra or {} do
		piece[key] = value
	end
	return piece
end

-- Roue (cylindre d'axe X) avec son moyeu, qui tournent ensemble selon la vitesse.
local function wheel(at: { number }, radius: number, width: number, hubPaint: string): { Piece }
	return {
		p("tire", { width, radius * 2, radius * 2 }, at, { shape = "Cylinder", role = "wheel", radius = radius }),
		p(
			hubPaint,
			{ width + 0.05, radius * 0.8, radius * 0.8 },
			at,
			{ shape = "Cylinder", role = "wheel", radius = radius }
		),
		p("dark", { width + 0.1, radius * 0.25, radius * 1.7 }, at, { role = "wheel", radius = radius }), -- rayon visible
	}
end

-- Paire symétrique gauche / droite.
local function pair(make: (side: number) -> { Piece }): { Piece }
	local pieces = make(-1)
	for _, piece in make(1) do
		table.insert(pieces, piece)
	end
	return pieces
end

local function merge(...: { Piece }): { Piece }
	local all: { Piece } = {}
	for _, list in { ... } do
		for _, piece in list do
			table.insert(all, piece)
		end
	end
	return all
end

-- Tier 3 — Tondeuse Rouge (6 × 4 × 2) : tondeuse autoportée, plateau de coupe, siège, bac de ramassage.
local MOWER: Model = {
	pieces = merge(
		{
			p("main", { 3.2, 1.2, 2.2 }, { 0, 0.2, -1.8 }),
			p("accent", { 3.25, 0.15, 2.25 }, { 0, 0.85, -1.8 }),
			p("main", { 3.6, 1.0, 3.6 }, { 0, 0, 0.9 }), -- plancher sous les pieds du pilote (y = 0,5)
			p("dark", { 4.6, 0.35, 2.4 }, { 0, -0.7, -1.6 }),
			p("accent", { 4.7, 0.2, 0.3 }, { 0, -0.5, -2.85 }),
			p("dark", { 1.6, 0.35, 1.2 }, { 0, 1.2, 1.4 }),
			p("dark", { 1.6, 1.4, 0.3 }, { 0, 1.9, 2.05 }),
			p("chrome", { 0.2, 1.4, 0.2 }, { 0, 1.3, -0.9 }, { tilt = { 0.4, 0, 0 } }),
			p("dark", { 0.15, 1.0, 1.0 }, { 0, 2.0, -1.2 }, { shape = "Cylinder", tilt = { 0.6, 0, HALF_TURN } }),
			p("extra", { 3.0, 1.6, 1.2 }, { 0, 0.6, 3.3 }),
			p("dark", { 3.1, 0.2, 1.25 }, { 0, 1.45, 3.3 }),
			p("chrome", { 1.0, 0.25, 0.25 }, { 1.3, 1.1, -0.9 }, { shape = "Cylinder", tilt = { 0, 0, HALF_TURN } }),
			p("light", { 0.5, 0.35, 0.1 }, { -0.9, 0.3, -2.95 }, { light = true }),
			p("light", { 0.5, 0.35, 0.1 }, { 0.9, 0.3, -2.95 }, { light = true }),
		},
		pair(function(side)
			return wheel({ side * 1.75, -0.55, -2.3 }, 0.45, 0.5, "hub")
		end),
		pair(function(side)
			return wheel({ side * 1.95, -0.2, 1.5 }, 0.8, 0.7, "hub")
		end)
	),
	effects = { { kind = "exhaust", at = { 1.3, 1.7, -0.9 } } },
}

-- Tier 4 — Tracteur Fermier (9 × 6 × 3) : capot à calandre, cabine à arceaux, grandes roues arrière.
local TRACTOR: Model = {
	pieces = merge(
		{
			p("main", { 2.8, 2.2, 4.0 }, { 0, 0.6, -2.6 }),
			p("accent", { 2.9, 0.15, 4.05 }, { 0, 1.72, -2.6 }),
			p("dark", { 2.4, 1.8, 0.2 }, { 0, 0.5, -4.65 }),
			p("chrome", { 2.2, 0.15, 0.22 }, { 0, 0.9, -4.7 }),
			p("chrome", { 2.2, 0.15, 0.22 }, { 0, 0.2, -4.7 }),
			p("main", { 3.2, 1.6, 4.2 }, { 0, -0.1, 1.8 }),
			p("dark", { 3.2, 0.3, 3.4 }, { 0, 0.85, 0.85 }), -- plancher de cabine (pieds du pilote à y = 1)
			p("dark", { 1.4, 0.3, 1.2 }, { 0, 1.7, 1.2 }),
			p("dark", { 1.4, 1.6, 0.3 }, { 0, 2.5, 1.85 }),
			p("dark", { 0.6, 0.6, 0.8 }, { 0, -0.6, 4.3 }),
			p("accent", { 3.8, 0.35, 4.1 }, { 0, 7.2, 0.85 }),
			p("neon", { 0.6, 0.4, 0.6 }, { 0, 7.55, 0.85 }, { role = "glow", beacon = true }),
			p("chrome", { 3.0, 0.4, 0.4 }, { 0.9, 3.2, -3.4 }, { shape = "Cylinder", tilt = { 0, 0, HALF_TURN } }),
			p("dark", { 0.4, 0.5, 0.5 }, { 0.9, 4.75, -3.4 }, { shape = "Cylinder", tilt = { 0, 0, HALF_TURN } }),
			p("light", { 0.6, 0.5, 0.1 }, { -1.0, 1.3, -4.65 }, { light = true }),
			p("light", { 0.6, 0.5, 0.1 }, { 1.0, 1.3, -4.65 }, { light = true }),
		},
		pair(function(side)
			return merge(
				{
					p("main", { 1.6, 0.35, 3.6 }, { side * 2.45, 1.75, 1.8 }),
					p("main", { 0.3, 5.6, 0.3 }, { side * 1.6, 4.3, -0.9 }),
					p("main", { 0.3, 5.6, 0.3 }, { side * 1.6, 4.3, 2.6 }),
				},
				wheel({ side * 2.5, 0.2, 1.8 }, 1.7, 1.4, "accent"),
				wheel({ side * 1.85, -0.55, -3.1 }, 0.95, 0.9, "accent")
			)
		end)
	),
	effects = { { kind = "exhaust", at = { 0.9, 5.1, -3.4 } } },
}

-- Tier 5 — Double Faucheuse Turbo (11 × 8 × 3, coupe 20) : deux rabatteurs rotatifs, aileron, turbo.
local DOUBLE_MOWER: Model = {
	pieces = merge(
		{
			p("main", { 4.4, 2.0, 7 }, { 0, 0.3, 0.8 }),
			p("main", { 3.6, 1.4, 2.4 }, { 0, -0.1, -3.6 }),
			p("accent", { 3.7, 0.2, 2.45 }, { 0, 0.62, -3.6 }),
			p("chrome", { 19, 0.35, 0.35 }, { 0, -0.5, -4.6 }),
			p("accent", { 3.7, 0.3, 0.3 }, { 0, 7.1, -0.6 }),
			p("accent", { 3.7, 0.3, 0.3 }, { 0, 7.1, 2.0 }),
			p("glass", { 3.7, 0.25, 2.9 }, { 0, 7.25, 0.7 }),
			p("accent", { 5.2, 0.25, 1.4 }, { 0, 2.8, 4.3 }),
			p("light", { 0.8, 0.3, 0.1 }, { -1.2, 0.4, -4.85 }, { light = true }),
			p("light", { 0.8, 0.3, 0.1 }, { 1.2, 0.4, -4.85 }, { light = true }),
		},
		pair(function(side)
			return merge(
				{
					p("dark", { 0.4, 1.0, 7 }, { side * 2.4, -0.4, 0.8 }),
					p("accent", { 9, 1.6, 1.6 }, { side * 5, -0.5, -5.6 }, { shape = "Cylinder", role = "reel" }),
					p("dark", { 9.05, 0.2, 2.2 }, { side * 5, -0.5, -5.6 }, { role = "reel" }),
					p("dark", { 9.05, 2.2, 0.2 }, { side * 5, -0.5, -5.6 }, { role = "reel" }),
					p("chrome", { 0.3, 0.3, 1.4 }, { side * 9.6, -0.5, -5.0 }),
					p("main", { 0.3, 5.6, 0.3 }, { side * 1.7, 4.3, -0.6 }),
					p("main", { 0.3, 5.6, 0.3 }, { side * 1.7, 4.3, 2.0 }),
					p("dark", { 0.3, 1.4, 0.3 }, { side * 1.6, 2.0, 4.0 }),
					p(
						"chrome",
						{ 1.6, 0.45, 0.45 },
						{ side * 0.8, 1.5, 4.6 },
						{ shape = "Cylinder", tilt = { 0, HALF_TURN, 0 } }
					),
				},
				wheel({ side * 2.9, -0.2, -3.2 }, 1.3, 1.1, "chrome"),
				wheel({ side * 2.9, -0.2, 3.2 }, 1.3, 1.1, "chrome")
			)
		end)
	),
	effects = { { kind = "thruster", at = { -0.8, 1.5, 5.5 } }, { kind = "thruster", at = { 0.8, 1.5, 5.5 } } },
}

-- Tier 6 — Moissonneuse Dorée XL (14 × 10 × 4, coupe 28) : cabine vitrée, trémie, vis, barre de coupe à rabatteur.
local COMBINE: Model = {
	pieces = merge(
		{
			p("main", { 7, 2.6, 11 }, { 0, 0, 1 }),
			p("dark", { 7.1, 0.6, 11.1 }, { 0, -1, 1 }),
			p("main", { 6.6, 3.2, 5.2 }, { 0, 3.6, 4.2 }),
			p("accent", { 6.8, 0.35, 5.4 }, { 0, 5.3, 4.2 }),
			p("glass", { 4.2, 5.2, 3.6 }, { 0, 4.7, -0.6 }),
			p("accent", { 4.8, 0.4, 4.2 }, { 0, 7.5, -0.6 }),
			p("neon", { 0.7, 0.5, 0.7 }, { 0, 7.95, -0.6 }, { role = "glow", beacon = true }),
			p("chrome", { 7, 0.9, 0.9 }, { 4.6, 5.8, 3.0 }, { shape = "Cylinder", tilt = { 0, 0.35, 0.25 } }),
			p("dark", { 0.9, 1.4, 0.9 }, { 7.8, 6.4, 1.8 }),
			p("main", { 4, 1.8, 3 }, { 0, -0.4, -6.4 }),
			p("accent", { 28, 1.0, 2.6 }, { 0, -1.3, -8.6 }),
			p("extra", { 27, 2.4, 2.4 }, { 0, 0.6, -9.0 }, { shape = "Cylinder", role = "reel" }),
			p("dark", { 27.05, 0.25, 3.0 }, { 0, 0.6, -9.0 }, { role = "reel" }),
			p("dark", { 27.05, 3.0, 0.25 }, { 0, 0.6, -9.0 }, { role = "reel" }),
			p("chrome", { 2.2, 0.5, 0.5 }, { -2.6, 4.3, 6.6 }, { shape = "Cylinder", tilt = { 0, 0, HALF_TURN } }),
			p("chrome", { 0.6, 4, 0.15 }, { -3.6, 0.5, -1.0 }),
			p("light", { 0.8, 0.5, 0.1 }, { -1.6, 7.3, -2.75 }, { light = true }),
			p("light", { 0.8, 0.5, 0.1 }, { 1.6, 7.3, -2.75 }, { light = true }),
		},
		pair(function(side)
			return merge(
				{
					p("accent", { 0.4, 2.2, 2.8 }, { side * 14, -0.8, -8.6 }),
					p("dark", { 0.3, 0.3, 3.4 }, { side * 13.5, 0.6, -7.4 }),
					p("dark", { 0.3, 0.3, 3.4 }, { side * 6, 0.6, -7.4 }),
				},
				wheel({ side * 4.4, 0.2, -3.6 }, 2.2, 1.6, "accent"),
				wheel({ side * 3.9, -0.6, 5.0 }, 1.4, 1.2, "accent")
			)
		end)
	),
	effects = { { kind = "exhaust", at = { -2.6, 5.5, 6.6 } } },
}

-- Tier 7 — Moissonneuse Cyber-Laser (17 × 12 × 4, coupe 38) : coque sombre, néons, dôme, lévitation, laser.
local CYBER: Model = {
	pieces = merge(
		{
			p("main", { 8, 2.4, 13 }, { 0, 0.2, 0.8 }),
			p("main", { 6.5, 1.4, 4 }, { 0, -0.3, -7.4 }),
			p("neon", { 6.6, 0.2, 4.05 }, { 0, 0.42, -7.4 }, { role = "glow" }),
			p("glass", { 7, 7, 7 }, { 0, 4.0, 0 }, { shape = "Ball" }),
			p("chrome", { 0.3, 7.4, 7.4 }, { 0, 1.9, 0 }, { shape = "Cylinder", tilt = { 0, 0, HALF_TURN } }),
			p("laser", { 37, 0.35, 0.35 }, { 0, -1.4, -9.6 }, { role = "glow" }),
			p("laser", { 37, 0.08, 4 }, { 0, -1.6, -8.0 }, { role = "glow" }),
			p("chrome", { 0.15, 2.5, 0.15 }, { 2.6, 3.6, 5.6 }),
			p("neon", { 0.4, 0.4, 0.4 }, { 2.6, 4.9, 5.6 }, { shape = "Ball", role = "glow", beacon = true }),
			p("light", { 1.2, 0.25, 0.1 }, { -2.2, 0.1, -9.42 }, { light = true }),
			p("light", { 1.2, 0.25, 0.1 }, { 2.2, 0.1, -9.42 }, { light = true }),
		},
		pair(function(side)
			return {
				p("main", { 2.6, 2.0, 11 }, { side * 5.3, -0.1, 1.0 }),
				p("neon", { 0.15, 0.3, 10.5 }, { side * 6.65, 0.3, 1.0 }, { role = "glow" }),
				p("neon2", { 2.4, 0.15, 10 }, { side * 5.3, -1.15, 1.0 }, { role = "glow" }),
				p(
					"neon2",
					{ 0.8, 3.2, 3.2 },
					{ side * 5.3, -1.6, -4.2 },
					{ shape = "Cylinder", tilt = { 0, 0, HALF_TURN }, role = "hover" }
				),
				p(
					"neon2",
					{ 0.8, 3.2, 3.2 },
					{ side * 5.3, -1.6, 5.6 },
					{ shape = "Cylinder", tilt = { 0, 0, HALF_TURN }, role = "hover" }
				),
				p("dark", { 0.6, 1.6, 0.6 }, { side * 18.6, -0.8, -9.6 }),
				p("dark", { 12.5, 0.5, 0.5 }, { side * 12.3, -0.9, -9.6 }),
				p(
					"chrome",
					{ 2.4, 1.4, 1.4 },
					{ side * 2.2, 0.6, 7.6 },
					{ shape = "Cylinder", tilt = { 0, HALF_TURN, 0 } }
				),
				p(
					"neon2",
					{ 0.3, 1.1, 1.1 },
					{ side * 2.2, 0.6, 8.85 },
					{ shape = "Cylinder", tilt = { 0, HALF_TURN, 0 }, role = "glow" }
				),
				p("main", { 0.3, 2.2, 2.6 }, { side * 3.6, 2.4, 6.2 }),
				p("neon", { 0.32, 2.2, 0.2 }, { side * 3.6, 2.4, 7.45 }, { role = "glow" }),
			}
		end)
	),
	effects = { { kind = "thruster", at = { -2.2, 0.6, 9.2 } }, { kind = "thruster", at = { 2.2, 0.6, 9.2 } } },
}

local DARK, TIRE, CHROME = { 30, 30, 35 }, { 27, 27, 30 }, { 210, 210, 215 }

return Freeze.deep({
	MODELS = { [3] = MOWER, [4] = TRACTOR, [5] = DOUBLE_MOWER, [6] = COMBINE, [7] = CYBER } :: { [number]: Model },

	-- Couleurs par palier. « glass », « chrome », « neon », « neon2 », « light », « laser » ont aussi un matériau.
	PALETTES = {
		[3] = { main = { 196, 40, 28 }, accent = { 248, 248, 248 }, extra = { 75, 151, 75 }, hub = { 163, 162, 165 } },
		[4] = { main = { 75, 151, 75 }, accent = { 245, 205, 48 }, extra = { 245, 205, 48 }, hub = { 245, 205, 48 } },
		[5] = { main = { 13, 105, 172 }, accent = { 196, 40, 28 }, extra = { 196, 40, 28 }, hub = { 210, 210, 215 } },
		[6] = { main = { 245, 205, 48 }, accent = { 196, 40, 28 }, extra = { 255, 176, 0 }, hub = { 196, 40, 28 } },
		[7] = { main = { 27, 27, 35 }, accent = { 98, 37, 209 }, extra = { 98, 37, 209 }, hub = { 27, 27, 35 } },
	} :: { [number]: { [string]: { number } } },
	-- Mini-Tracteur Turbo du Starter Pack (A12) : le tracteur repeint en rouge et jaune « course ».
	TURBO_PALETTE = {
		main = { 196, 40, 28 },
		accent = { 245, 205, 48 },
		extra = { 245, 205, 48 },
		hub = { 27, 27, 30 },
	},
	-- Couleurs communes à tous les paliers (complètent la palette du palier).
	SHARED_PAINT = {
		dark = DARK,
		tire = TIRE,
		chrome = CHROME,
		glass = { 128, 230, 255 },
		light = { 255, 245, 210 },
		neon = { 255, 140, 0 },
		neon2 = { 0, 255, 255 },
		laser = { 255, 40, 40 },
		titan = { 255, 196, 0 },
	} :: { [string]: { number } },
	NEON_OVERRIDES = { [5] = { light = { 128, 230, 255 } }, [7] = { neon = { 170, 85, 255 }, light = { 0, 255, 255 } } } :: {
		[number]: { [string]: { number } },
	},
	MATERIALS = {
		glass = "Glass",
		chrome = "Metal",
		neon = "Neon",
		neon2 = "Neon",
		light = "Neon",
		laser = "Neon",
		titan = "Metal",
	} :: { [string]: string },
	GLASS_TRANSPARENCY = 0.45,
	CHROME_REFLECTANCE = 0.3,

	-- Animations (côté client).
	REEL_BASE_SPEED = 3, -- rad/s à l'arrêt
	REEL_SPEED_PER_STUD = 0.25, -- rad/s ajoutés par stud/s de vitesse
	GLOW_SPEED = 3, -- pulsation des néons (rad/s)
	GLOW_DEPTH = 0.35, -- transparence maximale atteinte par la pulsation
	HOVER_HEIGHT = 0.35,
	HOVER_SPEED = 2.5,
	RENDER_DISTANCE = 600, -- au-delà, l'engin n'est plus animé (il suit quand même la carrosserie)

	-- Effets (particules et lumières).
	SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds",
	SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds",
	EXHAUST = {
		idleRate = 4, -- bouffées par seconde au ralenti
		ratePerStud = 0.6, -- bouffées ajoutées par stud/s
		lifetime = { 1, 1.6 },
		speed = { 3, 5 },
		size = { 0.6, 2.6 }, -- taille à la naissance, puis en fin de vie
		color = { 90, 90, 95 },
		transparency = { 0.3, 1 },
		spin = { -90, 90 }, -- degrés par seconde
	},
	THRUSTER = {
		idleRate = 30,
		ratePerStud = 3,
		lifetime = { 0.15, 0.3 },
		speed = { 12, 18 },
		size = { 1.1, 0.1 },
		color = { 0, 200, 255 },
		lightRange = 10,
	},
	TURBO_FLAME_COLOR = { 255, 140, 0 }, -- flammes du Mini-Tracteur Turbo (A12)
	CHAFF = {
		rate = 40, -- brins de paille par seconde en fauchant
		minSpeed = 4, -- en dessous, l'engin ne fauche pas assez vite pour projeter de la paille
		lifetime = { 0.6, 1.2 },
		speed = { 8, 14 },
		spread = 50, -- degrés
		size = 0.5,
		color = { 245, 205, 48 },
		gravityRatio = 0.25, -- la paille retombe doucement
	},
	SPAWN_BURST = {
		count = 40, -- briques projetées à l'apparition de l'engin
		brickSize = 0.6,
		speed = 28,
		lifetime = 1.2,
		lift = 1.5, -- part verticale de l'élan (gerbe en cloche)
		colors = { { 245, 205, 48 }, { 196, 40, 28 }, { 13, 105, 172 }, { 75, 151, 75 } },
	},
	HEADLIGHT = { range = 40, brightness = 2, angle = 70 },
	BEACON_LIGHT_RANGE = 12, -- gyrophares et néons pulsants
	TITAN_GUARD = { margin = 2, heightRatio = 0.9, depth = 0.6, gap = 0.4 }, -- pare-buffle généré à l'avant
	TITAN_REFLECTANCE = 0.45,
})
