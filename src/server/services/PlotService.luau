--!strict
-- Attribue une des 8 bases à chaque joueur (CDC §3, décision A20) et l'y fait réapparaître.
-- L'attribut « BaseIndex » du joueur est répliqué : les clients s'en servent pour identifier un récolteur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local MapService = require(script.Parent.MapService)

local PlotService = {}

local owners: { [number]: Player } = {}
local placements = MapGeometry.baseCenters()
local claimOrder = MapGeometry.baseClaimOrder()

local function claimBase(player: Player)
	if PlotService.baseIndexOf(player) then
		return -- déjà servi (PlayerAdded et la boucle de Start peuvent se recouper)
	end
	for _, index in claimOrder do
		if not owners[index] then
			owners[index] = player
			player:SetAttribute(PlayerAttributes.BASE_INDEX, index)
			local floor = MapService.basePart(index)
			local spawn = floor and floor:FindFirstChild(MapService.SPAWN_NAME)
			if spawn and spawn:IsA("SpawnLocation") then
				player.RespawnLocation = spawn
			end
			return
		end
	end
	warn(`[PlotService] aucune base libre pour {player.UserId} : MaxPlayers doit valoir {MapConfig.BASE_COUNT}`)
end

local function releaseBase(player: Player)
	for index, owner in owners do
		if owner == player then
			owners[index] = nil
		end
	end
end

-- Numéro de base du joueur, ou nil s'il n'en a pas.
function PlotService.baseIndexOf(player: Player): number?
	return player:GetAttribute(PlayerAttributes.BASE_INDEX) :: number?
end

function PlotService.basePlacement(player: Player): MapGeometry.Placement?
	local index = PlotService.baseIndexOf(player)
	return index and placements[index]
end

-- Replace le personnage au-dessus du spawn de sa base, sans le tuer : rien n'est perdu (CDC §6).
function PlotService.returnToBase(player: Player)
	local index = PlotService.baseIndexOf(player)
	local floor = index and MapService.basePart(index)
	local spawn = floor and floor:FindFirstChild(MapService.SPAWN_NAME) :: BasePart?
	local character = player.Character
	if spawn and character then
		character:PivotTo(spawn.CFrame + Vector3.new(0, MapConfig.RETURN_DROP_HEIGHT, 0))
	end
end

function PlotService:Start()
	Players.PlayerAdded:Connect(claimBase)
	Players.PlayerRemoving:Connect(releaseBase)
	for _, player in Players:GetPlayers() do
		claimBase(player)
	end
end

return PlotService
