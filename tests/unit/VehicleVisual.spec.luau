--!strict
-- Habillage des engins (A52) : modèles complets et cohérents avec la carrosserie et la coupe de chaque palier.
local TestKit = require("../TestKit")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local VehicleVisualConfig = require("../../src/shared/config/VehicleVisualConfig")
local VehicleLooks = require("../../src/shared/domain/VehicleLooks")
local Loadout = require("../../src/shared/domain/Loadout")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local ROLES = { static = true, wheel = true, reel = true, glow = true, hover = true }
local SHAPES = { Cylinder = true, Ball = true }
local VEHICLE_TIERS = { 3, 4, 5, 6, 7 }
local DRIVER_HALF_WIDTH = 0.5 -- demi-épaisseur du torse du pilote
local DRIVER_FEET_DEPTH = 0.5 -- les pieds s'enfoncent de 0,5 sous le dessus de la carrosserie
local DRIVER_HEIGHT = 5 -- hauteur du pilote au-dessus de ses pieds
local SEE_THROUGH = { glass = true, light = true, neon = true, neon2 = true, laser = true }

local function lookFor(tierId: number): VehicleLooks.Look
	return { tierId = tierId, hasTurbo = false, hasTitan = false }
end

-- Vrai si le bloc (sans rotation) de la pièce occupe l'espace du pilote, debout au centre.
local function hitsDriver(piece: VehicleVisualConfig.Piece, top: number): boolean
	if piece.tilt or SEE_THROUGH[piece.paint] then
		return false
	end
	local feet = top - DRIVER_FEET_DEPTH
	local function overlaps(center: number, size: number, low: number, high: number): boolean
		return center + size / 2 > low and center - size / 2 < high
	end
	return overlaps(piece.at[1], piece.size[1], -DRIVER_HALF_WIDTH, DRIVER_HALF_WIDTH)
		and overlaps(piece.at[3], piece.size[3], -DRIVER_HALF_WIDTH, DRIVER_HALF_WIDTH)
		and overlaps(piece.at[2], piece.size[2], feet + DRIVER_HALF_WIDTH, feet + DRIVER_HEIGHT)
end

describe("VehicleVisualConfig", function()
	it("habille chaque engin des paliers 3 à 7, et seulement eux", function()
		for _, tierId in VEHICLE_TIERS do
			expect(VehicleLooks.hasModel(lookFor(tierId))).toBe(true)
			expect(#VehicleVisualConfig.MODELS[tierId].pieces > 15).toBe(true)
		end
		expect(VehicleLooks.hasModel(lookFor(1))).toBe(false)
		expect(VehicleLooks.hasModel(lookFor(2))).toBe(false)
	end)

	it("ne contient que des pièces valides (taille, rôle, forme, peinture connue)", function()
		for _, tierId in VEHICLE_TIERS do
			for _, piece in VehicleVisualConfig.MODELS[tierId].pieces do
				expect(#piece.size).toBe(3)
				expect(#piece.at).toBe(3)
				for _, value in piece.size do
					expect(value > 0).toBe(true)
				end
				expect(ROLES[piece.role or "static"]).toBe(true)
				expect(piece.shape == nil or SHAPES[piece.shape] == true).toBe(true)
				expect(#VehicleLooks.paint(lookFor(tierId), piece.paint)).toBe(3)
			end
		end
	end)

	it("donne un rayon à chaque roue, qui touche le sol de la carrosserie", function()
		for _, tierId in VEHICLE_TIERS do
			local ground = -VehicleConfig.BODIES[tierId].height / 2
			for _, piece in VehicleVisualConfig.MODELS[tierId].pieces do
				if piece.role == "wheel" and piece.shape == "Cylinder" and piece.paint == "tire" then
					expect(piece.radius).toBeCloseTo(piece.size[2] / 2)
					expect(piece.at[2] - (piece.radius :: number)).toBeCloseTo(ground, 1e-6)
				end
			end
		end
	end)

	it("ne place aucune pièce opaque dans le corps du pilote", function()
		for _, tierId in VEHICLE_TIERS do
			local top = VehicleConfig.BODIES[tierId].height / 2
			for _, piece in VehicleVisualConfig.MODELS[tierId].pieces do
				expect(hitsDriver(piece, top)).toBe(false)
			end
		end
	end)

	it("montre une coupe aussi large que la hitbox du palier (lisibilité de la progression, CDC §2)", function()
		for _, tierId in { 5, 6, 7 } do
			local width = 0
			for _, piece in VehicleVisualConfig.MODELS[tierId].pieces do
				width = math.max(width, 2 * (math.abs(piece.at[1]) + piece.size[1] / 2))
			end
			local hitbox = VehicleConfig.TIERS[tierId].hitboxStuds
			expect(math.abs(width - hitbox) <= 2).toBe(true)
		end
	end)

	it("place des effets connus sur chaque engin", function()
		for _, tierId in VEHICLE_TIERS do
			local effects = VehicleVisualConfig.MODELS[tierId].effects
			expect(#effects > 0).toBe(true)
			for _, effect in effects do
				expect(effect.kind == "exhaust" or effect.kind == "thruster").toBe(true)
			end
		end
	end)
end)

describe("VehicleLooks", function()
	it("affiche l'engin du palier effectif, Turbo compris (A12)", function()
		local perks = table.clone(Loadout.NO_PERKS)
		perks.hasTurboTractor = true
		local look = VehicleLooks.lookOf(3, perks, false)
		expect(look.tierId).toBe(4)
		expect(look.hasTurbo).toBe(true)
		expect(VehicleLooks.paint(look, "main")).toBe(VehicleVisualConfig.TURBO_PALETTE.main)
	end)

	it("abandonne la livrée Turbo une fois le Tier 4 acheté au Garage", function()
		local perks = table.clone(Loadout.NO_PERKS)
		perks.hasTurboTractor = true
		local look = VehicleLooks.lookOf(4, perks, false)
		expect(look.hasTurbo).toBe(false)
		expect(VehicleLooks.paint(look, "main")).toBe(VehicleVisualConfig.PALETTES[4].main)
	end)

	it("ajoute le pare-buffle Titan doré devant la pièce la plus avancée", function()
		for _, tierId in VEHICLE_TIERS do
			local plain = VehicleLooks.piecesFor(lookFor(tierId))
			local titan = VehicleLooks.piecesFor({ tierId = tierId, hasTurbo = false, hasTitan = true })
			expect(#titan).toBe(#plain + 1)
			local guard = titan[#titan]
			expect(guard.paint).toBe("titan")
			expect(guard.at[3] + guard.size[3] / 2 < VehicleLooks.frontZ(tierId)).toBe(true)
			expect(guard.size[1]).toBe(VehicleConfig.BODIES[tierId].width + VehicleVisualConfig.TITAN_GUARD.margin)
		end
	end)

	it("projette la paille sur toute la largeur de coupe, à l'avant", function()
		local at, width = VehicleLooks.chaffBar(lookFor(6))
		expect(width).toBe(VehicleConfig.TIERS[6].hitboxStuds)
		expect(at[3]).toBe(VehicleLooks.frontZ(6))
		expect(at[3] < -VehicleConfig.BODIES[6].length / 2).toBe(true)
	end)

	it("ne modifie pas le modèle partagé en ajoutant le Titan", function()
		local before = #VehicleVisualConfig.MODELS[5].pieces
		VehicleLooks.piecesFor({ tierId = 5, hasTurbo = false, hasTitan = true })
		expect(#VehicleVisualConfig.MODELS[5].pieces).toBe(before)
	end)
end)
