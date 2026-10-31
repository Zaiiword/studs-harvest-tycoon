--!strict
-- Habillage de la boutique (CDC §9, §10) : chaque offre vendue a sa carte, et la grille reste lisible.
local TestKit = require("../TestKit")
local MonetizationConfig = require("../../src/shared/config/MonetizationConfig")
local UiConfig = require("../../src/shared/config/UiConfig")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SHOP = UiConfig.SHOP
local SHOP_PRODUCTS = { "Bazooka", "Meteor" }

describe("Boutique", function()
	it("donne une icône et un dégradé à chaque Gamepass et produit en vitrine", function()
		local keys = table.clone(SHOP_PRODUCTS)
		for _, pass in MonetizationConfig.GAMEPASSES do
			table.insert(keys, pass.key)
		end
		for _, key in keys do
			local look = SHOP.CARDS[key]
			expect(look ~= nil).toBe(true)
			expect(#look.icon > 0).toBe(true)
			expect(#look.top).toBe(3)
			expect(#look.bottom).toBe(3)
		end
	end)

	it("habille uniquement des offres qui existent", function()
		local known: { [string]: boolean } = {}
		for _, list in { MonetizationConfig.GAMEPASSES, MonetizationConfig.PRODUCTS } :: { any } do
			for _, offer in list do
				known[offer.key] = true
			end
		end
		for key in SHOP.CARDS do
			expect(known[key]).toBe(true)
		end
	end)

	it("garde au moins deux colonnes de cartes, même sur téléphone", function()
		expect(SHOP.MIN_COLUMNS >= 2).toBe(true)
		expect(SHOP.MAX_COLUMNS >= SHOP.MIN_COLUMNS).toBe(true)
	end)

	it("laisse la croix de fermeture assez grande pour un doigt (44 px au moins)", function()
		expect(UiConfig.WINDOW.CLOSE_SIZE >= 44).toBe(true)
	end)
end)
