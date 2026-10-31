--!strict
-- Historique d'achats Robux du profil (CDC §11, docs/ANALYSE_CDC.md §4), sans API Roblox.
-- `ProcessReceipt` peut être rappelé plusieurs fois pour un même reçu : on n'accorde un achat qu'une fois,
-- en mémorisant les identifiants de reçus déjà traités (liste bornée, les plus anciens sortent).
local MonetizationConfig = require("../config/MonetizationConfig")

export type Purchases = {
	receipts: { string }, -- identifiants de reçus déjà accordés (du plus ancien au plus récent)
	hasStarterPack: boolean, -- Starter Pack acheté (une fois par compte)
	starterOfferedAt: number, -- 0 : offre jamais déclenchée ; sinon instant de début de l'offre
	hasTurboTractor: boolean, -- Mini-Tracteur Turbo (A12)
}

local Purchases = {}

function Purchases.new(): Purchases
	return { receipts = {}, hasStarterPack = false, starterOfferedAt = 0, hasTurboTractor = false }
end

function Purchases.hasReceipt(purchases: Purchases, receiptId: string): boolean
	return table.find(purchases.receipts, receiptId) ~= nil
end

function Purchases.recordReceipt(purchases: Purchases, receiptId: string)
	if Purchases.hasReceipt(purchases, receiptId) then
		return
	end
	table.insert(purchases.receipts, receiptId)
	while #purchases.receipts > MonetizationConfig.RECEIPT_HISTORY do
		table.remove(purchases.receipts, 1)
	end
end

-- Le Starter Pack est proposé une seule fois : dès 4 min de jeu ou au premier sac plein, pendant 15 min.
function Purchases.shouldOfferStarter(purchases: Purchases, playedSeconds: number, hasFilledBag: boolean): boolean
	if purchases.hasStarterPack or purchases.starterOfferedAt > 0 then
		return false
	end
	return hasFilledBag or playedSeconds >= MonetizationConfig.STARTER.OFFER_AFTER_SECONDS
end

function Purchases.isStarterOfferOpen(purchases: Purchases, now: number): boolean
	local openedAt = purchases.starterOfferedAt
	return not purchases.hasStarterPack
		and openedAt > 0
		and now < openedAt + MonetizationConfig.STARTER.OFFER_DURATION_SECONDS
end

function Purchases.sanitize(raw: any): Purchases
	local purchases = Purchases.new()
	local source = if typeof(raw) == "table" then raw else {}
	if typeof(source.receipts) == "table" then
		for _, id in source.receipts do
			if typeof(id) == "string" and #id <= 128 then
				Purchases.recordReceipt(purchases, id)
			end
		end
	end
	purchases.hasStarterPack = source.hasStarterPack == true
	purchases.hasTurboTractor = source.hasTurboTractor == true
	local offeredAt = source.starterOfferedAt
	purchases.starterOfferedAt = if typeof(offeredAt) == "number"
			and offeredAt == offeredAt
			and offeredAt > 0
		then offeredAt
		else 0
	return purchases
end

return Purchases
