--!strict
local TestKit = require("../TestKit")
local IconConfig = require("../../src/shared/config/IconConfig")
local PetConfig = require("../../src/shared/config/PetConfig")
local RetentionConfig = require("../../src/shared/config/RetentionConfig")
local SabotageConfig = require("../../src/shared/config/SabotageConfig")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local UiConfig = require("../../src/shared/config/UiConfig")
local UpgradeConfig = require("../../src/shared/config/UpgradeConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local RewardText = require("../../src/shared/domain/RewardText")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Une icône existe si c'est une sculpture d'IconConfig, ou l'œuf d'un vrai œuf (« egg:BasicEgg »).
local function exists(id: string): boolean
	local prefix = IconConfig.EGG_PREFIX
	if string.sub(id, 1, #prefix) == prefix then
		local eggId = string.sub(id, #prefix + 1)
		for _, egg in PetConfig.EGGS do
			if egg.id == eggId then
				return true
			end
		end
		return false
	end
	return IconConfig.ICONS[id] ~= nil
end

describe("Icônes en briques (A72)", function()
	it("n'a que des pièces de taille positive, à trois dimensions", function()
		for _, pieces in IconConfig.ICONS do
			expect(#pieces > 0).toBe(true)
			for _, piece in pieces do
				expect(#piece.size).toBe(3)
				expect(#piece.offset).toBe(3)
				for _, dimension in piece.size do
					expect(dimension > 0).toBe(true)
				end
			end
		end
	end)
	it("tient dans un cube raisonnable : aucune pièce à plus de 5 studs du centre", function()
		for _, pieces in IconConfig.ICONS do
			for _, piece in pieces do
				expect(math.abs(piece.offset[1]) <= 5 and math.abs(piece.offset[3]) <= 5).toBe(true)
				expect(piece.offset[2] >= -1 and piece.offset[2] <= 5).toBe(true)
			end
		end
	end)
	it("donne une icône à chaque bouton au sol : machines, Garage, Rebirth, ferme", function()
		expect(exists(IconConfig.DEFAULT_BUTTON)).toBe(true)
		for _, icon in IconConfig.BUTTONS do
			expect(exists(icon)).toBe(true)
		end
		for _, list in { TycoonConfig.MACHINES, TycoonConfig.UPPER_MACHINES } do
			for _, machine in list do
				expect(IconConfig.BUTTONS[machine.id] ~= nil).toBe(true)
			end
		end
	end)
	it("donne une icône à chaque palier d'outil ou d'engin", function()
		expect(#IconConfig.TIERS).toBe(#VehicleConfig.TIERS)
		for _, icon in IconConfig.TIERS do
			expect(exists(icon)).toBe(true)
		end
	end)
	it("connaît l'icône de chaque objet, amélioration, offre, quête et succès", function()
		for _, item in SabotageConfig.ITEMS do
			expect(exists(item.icon)).toBe(true)
		end
		for _, upgrade in UpgradeConfig.UPGRADES do
			expect(exists(upgrade.icon)).toBe(true)
		end
		for _, card in UiConfig.SHOP.CARDS do
			expect(exists(card.icon)).toBe(true)
		end
		for _, icon in UiConfig.RETENTION_MENU.QUEST_ICONS do
			expect(exists(icon)).toBe(true)
		end
		for _, achievement in RetentionConfig.ACHIEVEMENTS do
			expect(exists(achievement.icon)).toBe(true)
		end
	end)
	it("connaît l'icône de chaque récompense : cadeaux, connexion, roue, quêtes, codes", function()
		local rewards: { RetentionConfig.Reward } = {}
		for _, gift in RetentionConfig.GIFTS do
			table.insert(rewards, gift.reward)
		end
		for _, reward in RetentionConfig.LOGIN_REWARDS do
			table.insert(rewards, reward)
		end
		for _, segment in RetentionConfig.WHEEL do
			table.insert(rewards, segment.reward)
		end
		for _, quest in RetentionConfig.QUESTS do
			table.insert(rewards, quest.reward)
		end
		for _, code in RetentionConfig.CODES do
			table.insert(rewards, code.reward)
		end
		for _, reward in rewards do
			expect(exists(RewardText.icon(reward))).toBe(true)
		end
	end)
end)
