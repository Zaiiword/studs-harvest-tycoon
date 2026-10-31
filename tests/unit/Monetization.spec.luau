--!strict
local TestKit = require("../TestKit")
local MonetizationConfig = require("../../src/shared/config/MonetizationConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Loadout = require("../../src/shared/domain/Loadout")
local Purchases = require("../../src/shared/domain/Purchases")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function perks(overrides: { [string]: boolean }): Loadout.Perks
	local result = table.clone(Loadout.NO_PERKS) :: any
	for key, value in overrides do
		result[key] = value
	end
	return result
end

describe("Loadout", function()
	it("sans avantage, renvoie le palier acheté tel quel", function()
		local tier = Loadout.effectiveTier(3, Loadout.NO_PERKS)
		expect(tier.hitboxStuds).toBe(VehicleConfig.TIERS[3].hitboxStuds)
		expect(tier.capacity).toBe(VehicleConfig.TIERS[3].capacity)
	end)
	it("Aimant : hitbox +35 % et vitesse +20 % (CDC §9)", function()
		local tier = Loadout.effectiveTier(1, perks({ hasMagnet = true }))
		expect(tier.hitboxStuds).toBeCloseTo(4 * 1.35)
		expect(tier.speed).toBeCloseTo(16 * 1.2)
	end)
	it("Remorque Infinie : capacité illimitée (A16)", function()
		expect(Loadout.effectiveTier(2, perks({ hasInfiniteTrailer = true })).capacity).toBe(math.huge)
	end)
	it("Mini-Tracteur Turbo : stats du Tier 4 et +10 % de vitesse sous le Tier 4 (A12)", function()
		local tier = Loadout.effectiveTier(1, perks({ hasTurboTractor = true }))
		expect(tier.id).toBe(4)
		expect(tier.isVehicle).toBe(true)
		expect(tier.speed).toBeCloseTo(VehicleConfig.TIERS[4].speed * 1.1)
	end)
	it("le Turbo ne remplace pas un palier plus élevé acheté au Garage", function()
		expect(Loadout.effectiveTier(6, perks({ hasTurboTractor = true })).id).toBe(6)
	end)
	it("ne modifie jamais la config gelée", function()
		Loadout.effectiveTier(1, perks({ hasMagnet = true, hasInfiniteTrailer = true }))
		expect(VehicleConfig.TIERS[1].capacity).toBe(25)
	end)
end)

describe("Purchases", function()
	it("n'accorde un reçu qu'une fois (ProcessReceipt idempotent)", function()
		local purchases = Purchases.new()
		expect(Purchases.hasReceipt(purchases, "r1")).toBe(false)
		Purchases.recordReceipt(purchases, "r1")
		Purchases.recordReceipt(purchases, "r1")
		expect(#purchases.receipts).toBe(1)
		expect(Purchases.hasReceipt(purchases, "r1")).toBe(true)
	end)
	it("borne l'historique en oubliant les plus anciens", function()
		local purchases = Purchases.new()
		for k = 1, MonetizationConfig.RECEIPT_HISTORY + 5 do
			Purchases.recordReceipt(purchases, `r{k}`)
		end
		expect(#purchases.receipts).toBe(MonetizationConfig.RECEIPT_HISTORY)
		expect(Purchases.hasReceipt(purchases, "r1")).toBe(false)
	end)
	it("propose le Starter Pack après 4 min ou au premier sac plein, une seule fois (A50)", function()
		local purchases = Purchases.new()
		expect(Purchases.shouldOfferStarter(purchases, 100, false)).toBe(false)
		expect(Purchases.shouldOfferStarter(purchases, 100, true)).toBe(true)
		expect(Purchases.shouldOfferStarter(purchases, 240, false)).toBe(true)
		purchases.starterOfferedAt = 1000
		expect(Purchases.shouldOfferStarter(purchases, 999, true)).toBe(false)
	end)
	it("garde l'offre ouverte 15 minutes, et la ferme une fois achetée", function()
		local purchases = Purchases.new()
		purchases.starterOfferedAt = 1000
		expect(Purchases.isStarterOfferOpen(purchases, 1000 + 899)).toBe(true)
		expect(Purchases.isStarterOfferOpen(purchases, 1000 + 900)).toBe(false)
		purchases.hasStarterPack = true
		expect(Purchases.isStarterOfferOpen(purchases, 1001)).toBe(false)
	end)
	it("nettoie un historique corrompu", function()
		local purchases = Purchases.sanitize({ receipts = { "ok", 42, string.rep("x", 500) }, hasStarterPack = "oui" })
		expect(#purchases.receipts).toBe(1)
		expect(purchases.hasStarterPack).toBe(false)
	end)
end)
