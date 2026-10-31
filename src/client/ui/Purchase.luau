--!strict
-- Lancement d'un achat Robux côté client (CDC §9). Avec un identifiant renseigné, Roblox affiche sa fenêtre
-- d'achat (le serveur accorde le produit dans ProcessReceipt). Sans identifiant (id = 0) : simulation dans
-- Studio via le panneau de test, message « bientôt disponible » en jeu publié.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MonetizationConfig = require(ReplicatedStorage.Shared.config.MonetizationConfig)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)

local Purchase = {}

local localPlayer = Players.LocalPlayer

local function find(list: { { key: string, id: number } }, key: string): { key: string, id: number }?
	for _, entry in list do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

-- Renvoie un message à afficher si l'achat n'a pas pu être lancé, nil sinon.
local function launch(kind: "pass" | "product", key: string): string?
	local list = if kind == "pass" then MonetizationConfig.GAMEPASSES else MonetizationConfig.PRODUCTS
	local entry = find(list, key)
	if not entry then
		return "Offre inconnue."
	end
	if entry.id > 0 then
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(localPlayer, entry.id)
		else
			MarketplaceService:PromptProductPurchase(localPlayer, entry.id)
		end
		return nil
	end
	if RunService:IsStudio() then
		Remotes.event(Remotes.DEV_COMMAND):FireServer(kind, key) -- simulation, sans Robux
		return nil
	end
	return "Bientôt disponible !"
end

function Purchase.pass(key: string): string?
	return launch("pass", key)
end

function Purchase.product(key: string): string?
	return launch("product", key)
end

return Purchase
