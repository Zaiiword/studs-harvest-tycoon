--!strict
-- Champ autoritaire (CDC §4, §11) : détient la FieldGrid, fait repousser les brins et diffuse
-- les coupes / repousses par lots binaires toutes les 0,2 s. Ne gère ni l'argent ni les sacs (SRP).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local FieldGrid = require(ReplicatedStorage.Shared.domain.FieldGrid)
local Rarity = require(ReplicatedStorage.Shared.domain.Rarity)
local FieldCodec = require(ReplicatedStorage.Shared.net.FieldCodec)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)

local FieldService = {}

-- Un client ne redemande l'état initial qu'en cas de reconnexion : 3 demandes, puis 1 toutes les 10 s.
local SNAPSHOT_BURST = 3
local SNAPSHOT_REFILL_PER_SECOND = 0.1

local random = Random.new()
local grid: FieldGrid.FieldGrid
local pending: { FieldCodec.FieldEvent } = {}
local batchRemote: RemoteEvent
local snapshotLimiter = RateLimiter.new(SNAPSHOT_BURST, SNAPSHOT_REFILL_PER_SECOND)
local elapsed = 0
local rainbowBoost = 1

local function nextRoll(): number
	return random:NextNumber()
end

local function onSnapshotRequested(player: Player): buffer?
	if not snapshotLimiter:allow(player, os.clock()) then
		return nil
	end
	return FieldCodec.encodeSnapshot(grid:grownRarities())
end

local function flush()
	for _, cell in grid:regrowDue(os.clock(), rainbowBoost) do
		table.insert(pending, { kind = FieldCodec.EVENT_REGROW, index = cell.index, data = cell.rarity })
	end
	if #pending == 0 then
		return
	end
	batchRemote:FireAllClients(FieldCodec.encodeEvents(pending))
	table.clear(pending)
end

local function onHeartbeat(deltaTime: number)
	elapsed += deltaTime
	if elapsed >= FieldConfig.BROADCAST_INTERVAL then
		elapsed = 0
		flush()
	end
end

-- Brins debout dans la boîte de coupe (voir FieldGrid.queryHitbox).
function FieldService.query(hitbox: FieldGrid.Hitbox): { number }
	return grid:queryHitbox(hitbox)
end

-- Inflige des dégâts au nom de la base `harvesterSlot`. Si le brin tombe, la coupe part dans le prochain lot.
function FieldService.cell(index: number): FieldGrid.Cell?
	return grid:cell(index)
end

function FieldService.damage(index: number, power: number, harvesterSlot: number): FieldGrid.CutResult?
	local result = grid:damage(index, power, os.clock())
	if result then
		table.insert(pending, { kind = FieldCodec.EVENT_CUT, index = index, data = harvesterSlot })
	end
	return result
end

-- Blé Arc-en-ciel debout le plus proche (Onde de Choc du Sprint 5).
function FieldService.nearestRainbow(x: number, z: number, range: number): FieldGrid.Cell?
	return grid:nearestOfRarity(x, z, range, Rarity.RAINBOW)
end

-- Multiplicateur de chance Arc-en-ciel (Nuit Néon, Sprint 5).
function FieldService.setRainbowBoost(boost: number)
	rainbowBoost = boost
end

function FieldService:Init()
	grid = FieldGrid.new(nextRoll)
	batchRemote = Remotes.event(Remotes.FIELD_BATCH)
	Remotes.func(Remotes.FIELD_SNAPSHOT).OnServerInvoke = onSnapshotRequested
end

function FieldService:Start()
	RunService.Heartbeat:Connect(onHeartbeat)
	Players.PlayerRemoving:Connect(function(player)
		snapshotLimiter:forget(player)
	end)
end

return FieldService
