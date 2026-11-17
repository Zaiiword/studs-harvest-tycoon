--!strict
-- Améliorations permanentes en gemmes (A65) : achat validé par le serveur (prix, niveau maximal, gemmes), effets
-- publiés en attributs que lisent la récolte (sac, coupe) et l'usine (revenus). Conservées au Rebirth.
-- DataService restaure (restore), capture (snapshot) et libère (release) les niveaux de chaque joueur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(ReplicatedStorage.Shared.domain.Upgrades)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local TycoonService = require(script.Parent.TycoonService)

local UpgradeService = {}

local levelsOf: { [Player]: Upgrades.Levels } = {}
local limiter = RateLimiter.new(5, 2)
local notify: RemoteEvent

local function publish(player: Player)
	local levels = levelsOf[player] or {}
	player:SetAttribute(PlayerAttributes.UPGRADES, Upgrades.encode(levels))
	player:SetAttribute(PlayerAttributes.BAG_UPGRADE, Upgrades.multiplier(levels, "bag"))
	player:SetAttribute(PlayerAttributes.CUT_UPGRADE, Upgrades.multiplier(levels, "cut"))
	player:SetAttribute(PlayerAttributes.INCOME_UPGRADE, Upgrades.multiplier(levels, "income"))
end

local function onBuy(player: Player, rawId: any)
	local levels = levelsOf[player]
	local def = Upgrades.get(rawId)
	if not levels or not def or not limiter:allow(player, os.clock()) then
		return
	end
	local price = Upgrades.price(levels, def.id)
	if not price then
		return
	end
	if not TycoonService.spendGems(player, price) then
		notify:FireClient(player, `Il te faut {price} gemmes pour {def.name}.`)
		return
	end
	levels[def.id] = (levels[def.id] or 0) + 1
	publish(player)
	notify:FireClient(player, `{def.name} niveau {levels[def.id]} !`)
end

function UpgradeService.restore(player: Player, levels: Upgrades.Levels)
	levelsOf[player] = Upgrades.sanitize(levels)
	publish(player)
end

function UpgradeService.snapshot(player: Player): Upgrades.Levels
	return table.clone(levelsOf[player] or {})
end

function UpgradeService.release(player: Player)
	levelsOf[player] = nil
	limiter:forget(player)
end

function UpgradeService:Init()
	notify = Remotes.event(Remotes.NOTIFY)
	Remotes.event(Remotes.BUY_UPGRADE).OnServerEvent:Connect(onBuy)
end

function UpgradeService:Start()
	-- Avant le chargement du profil, le joueur n'a aucune amélioration (attributs à 1).
	local function initial(player: Player)
		if not levelsOf[player] then
			levelsOf[player] = {}
			publish(player)
		end
	end
	Players.PlayerAdded:Connect(initial)
	for _, player in Players:GetPlayers() do
		initial(player)
	end
end

return UpgradeService
