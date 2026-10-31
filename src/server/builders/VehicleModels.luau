--!strict
-- Habillage des engins en briques (CDC §2 « taille de sa moissonneuse »), soudé à la carrosserie physique.
-- Toutes les pièces sont décoratives (sans masse ni collision) : la physique reste celle de la carrosserie.
-- Repère de la carrosserie : avant = -Z, haut = +Y.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local Build = require(script.Parent.Build)

local VehicleModels = {}

local TIRE_COLOR = { 27, 42, 53 }
local GLASS_COLOR = { 128, 230, 255 }
local GLASS_TRANSPARENCY = 0.35
local WHEEL_WIDTH = 1.2
local REAR_WHEEL_SCALE = 1.5
local NEON_THICKNESS = 0.3
local TITAN_COLOR = { 255, 196, 0 }

local function addWheels(body: Part, def: VehicleConfig.BodyDef)
	local radius = def.height * 0.6
	for _, z in { -1, 1 } do
		local wheelRadius = if z > 0 and def.hasBigRearWheels then radius * REAR_WHEEL_SCALE else radius
		for _, x in { -1, 1 } do
			local wheel = Build.attached(body, {
				name = "Wheel",
				cframe = CFrame.new(
					x * (def.width / 2 + WHEEL_WIDTH / 2),
					-def.height / 2 + wheelRadius * 0.8,
					z * (def.length / 2 - radius)
				),
				size = Vector3.new(WHEEL_WIDTH, wheelRadius * 2, wheelRadius * 2),
				color = TIRE_COLOR,
			})
			wheel.Shape = Enum.PartType.Cylinder -- l'axe d'un cylindre Roblox est X : roue en travers
		end
	end
end

local function addCabin(body: Part, def: VehicleConfig.BodyDef)
	local size = Vector3.new(def.width * 0.7, def.height * 1.2, def.length * 0.35)
	local cabin = Build.attached(body, {
		name = "Cabin",
		cframe = CFrame.new(0, def.height / 2 + size.Y / 2, def.length * 0.2),
		size = size,
		color = GLASS_COLOR,
	})
	cabin.Transparency = GLASS_TRANSPARENCY
end

local function addBumper(body: Part, def: VehicleConfig.BodyDef)
	Build.attached(body, {
		name = "Bumper",
		cframe = CFrame.new(0, -def.height / 4, -(def.length / 2 + 0.5)),
		size = Vector3.new(def.width + 1, def.height / 2, 1),
		color = def.accent,
	})
end

-- Barre de coupe : sa largeur montre la hitbox du palier (lisibilité de la progression, CDC §2).
local function addHeader(body: Part, def: VehicleConfig.BodyDef, hitbox: number)
	Build.attached(body, {
		name = "Header",
		cframe = CFrame.new(0, -def.height / 2 + 0.6, -(def.length / 2 + 2)),
		size = Vector3.new(hitbox, 1.2, 2.5),
		color = def.accent,
	})
end

-- Pare-buffle doré et brillant, plus large que l'engin.
local function addTitanGuard(body: Part, def: VehicleConfig.BodyDef)
	local guard = Build.attached(body, {
		name = "TitanGuard",
		cframe = CFrame.new(0, 0, -(def.length / 2 + 1.4)),
		size = Vector3.new(def.width + 2, def.height, 0.8),
		color = TITAN_COLOR,
	})
	guard.Material = Enum.Material.Metal
	guard.Reflectance = 0.4
end

local function addNeon(body: Part, def: VehicleConfig.BodyDef)
	for _, x in { -1, 1 } do
		local stripe = Build.attached(body, {
			name = "Neon",
			cframe = CFrame.new(x * (def.width / 2 + NEON_THICKNESS / 2), 0, 0),
			size = Vector3.new(NEON_THICKNESS, NEON_THICKNESS * 2, def.length * 0.9),
			color = def.accent,
		})
		stripe.Material = Enum.Material.Neon
	end
end

-- `hasTitan` : Gamepass Pare-Chocs Lourd Titan, pare-buffle doré à l'avant (CDC §9).
function VehicleModels.decorate(body: Part, tier: VehicleConfig.TierDef, def: VehicleConfig.BodyDef, hasTitan: boolean)
	addWheels(body, def)
	addCabin(body, def)
	addBumper(body, def)
	if hasTitan then
		addTitanGuard(body, def)
	end
	if def.hasHeader then
		addHeader(body, def, tier.hitboxStuds)
	end
	if def.hasNeon then
		addNeon(body, def)
	end
end

return VehicleModels
