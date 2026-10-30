--!strict
-- Usine Tycoon de chaque joueur (CDC §7.1, §8, Sprint 3) : construit l'usine sur sa base, encaisse le revenu
-- chaque seconde, vend machines, niveaux de tapis et paliers (Garage) via des boutons au sol.
-- Le client ne fait que marcher : c'est le serveur qui détecte qu'il se tient sur un bouton (aucun Remote).
-- Dépendances : Tycoon (règles pures), MapService / PlotService (base), VehicleService (palier actuel).
-- La sauvegarde arrive au Sprint 4 (DataService) : pour l'instant l'usine repart de zéro à chaque session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Bag = require(ReplicatedStorage.Shared.domain.Bag)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local Tycoon = require(ReplicatedStorage.Shared.domain.Tycoon)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)
local VehicleService = require(script.Parent.VehicleService)
local TycoonModels = require(script.Parent.Parent.builders.TycoonModels)

local TycoonService = {}

type Entry = {
	state: Tycoon.State,
	base: MapGeometry.Placement,
	folder: Folder,
	pads: { [string]: Part },
	silo: Part,
	siloRoof: Part,
	currentPad: string?, -- un bouton n'achète qu'à l'arrivée dessus, pas en boucle
	lastPurchaseAt: number,
}

type BlockSpec = {
	name: string,
	spot: TycoonConfig.Spot,
	size: Vector3,
	color: { number },
}

local LAYOUT = TycoonConfig.LAYOUT
local COLORS = TycoonConfig.COLORS
local LABEL = TycoonConfig.LABEL

local entries: { [Player]: Entry } = {}
local incomeElapsed, padElapsed = 0, 0

local function attachLabel(part: BasePart, text: string)
	local gui = part:FindFirstChildOfClass("BillboardGui") or Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(LABEL.WIDTH, LABEL.HEIGHT)
	gui.StudsOffset = Vector3.new(0, LABEL.HEIGHT_ABOVE, 0)
	gui.MaxDistance = LABEL.MAX_DISTANCE
	local label = gui:FindFirstChildOfClass("TextLabel") or Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = (Enum.Font :: any)[UiConfig.FONT]
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

-- Brique ancrée posée sur la base, centrée sur le point local de `spec.spot`.
local function placeBlock(entry: Entry, spec: BlockSpec): Part
	local x, z = MapGeometry.baseToWorld(entry.base, spec.spot.x, spec.spot.z)
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Anchored = true
	part.Size = spec.size
	part.CFrame = CFrame.new(x, MapConfig.DECK_TOP + spec.size.Y / 2, z) * CFrame.Angles(0, -entry.base.angle, 0)
	Bricks.style(part, spec.color)
	part.Parent = entry.folder
	return part
end

local function refreshPads(player: Player, entry: Entry)
	local tier = VehicleService.tierOf(player).id
	for buttonId, pad in entry.pads do
		local offer = Tycoon.offer(entry.state, buttonId, tier)
		local price = offer.price
		local color = if not price
			then COLORS.PAD_SOLD_OUT
			elseif entry.state.money >= price then COLORS.PAD_AFFORDABLE
			else COLORS.PAD_TOO_EXPENSIVE
		pad.Color = Bricks.rgb(color)
		attachLabel(pad, if price then `{offer.label}\n{Format.money(price)} $` else `{offer.label}\n✔`)
	end
end

-- Hauteur « vertigineuse » du silo selon son remplissage (CDC §2 : la richesse se voit de loin).
local function refreshSilo(entry: Entry)
	local spec = LAYOUT.SILO
	local fill = entry.state.silo / TycoonConfig.SILO_CAPACITY
	local height = spec.minHeight + (spec.maxHeight - spec.minHeight) * math.sqrt(fill)
	local x, z = MapGeometry.baseToWorld(entry.base, spec.x, spec.z)
	entry.silo.Size = Vector3.new(height, spec.radius * 2, spec.radius * 2)
	entry.silo.CFrame = CFrame.new(x, MapConfig.DECK_TOP + height / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	entry.siloRoof.CFrame = CFrame.new(x, MapConfig.DECK_TOP + height, z)
end

local function buildMachine(entry: Entry, machineId: string)
	for _, machine in TycoonConfig.MACHINES do
		if machine.id == machineId then
			local spot = LAYOUT.MACHINES[machine.id]
			local x, z = MapGeometry.baseToWorld(entry.base, spot.x, spot.z)
			local origin = CFrame.new(x, MapConfig.DECK_TOP, z) * CFrame.Angles(0, -entry.base.angle, 0)
			local main = TycoonModels.machine(entry.folder, machine, origin)
			attachLabel(main, `{machine.name}\n×{machine.multiplier}`)
		end
	end
end

local function publish(player: Player, entry: Entry)
	local state = entry.state
	player:SetAttribute(PlayerAttributes.MONEY, math.floor(state.money))
	player:SetAttribute(PlayerAttributes.INCOME_PER_SECOND, Tycoon.incomePerSecond(state, Tycoon.NO_BONUS))
	player:SetAttribute(PlayerAttributes.SILO_VALUE, math.floor(state.silo))
	player:SetAttribute(PlayerAttributes.SILO_CAPACITY, TycoonConfig.SILO_CAPACITY)
	player:SetAttribute(PlayerAttributes.CONVEYOR_RATE, Tycoon.conveyorRate(state))
	refreshPads(player, entry)
	refreshSilo(entry)
end

local function buildFactory(entry: Entry)
	local padSize = Vector3.new(LAYOUT.PAD_SIZE, LAYOUT.PAD_THICKNESS, LAYOUT.PAD_SIZE)
	for buttonId, spot in LAYOUT.PADS do
		entry.pads[buttonId] =
			placeBlock(entry, { name = `Pad{buttonId}`, spot = spot, size = padSize, color = COLORS.PAD_TOO_EXPENSIVE })
	end
	local unload = LAYOUT.UNLOAD_PAD
	local unloadPad = placeBlock(entry, {
		name = "UnloadPad",
		spot = unload,
		size = Vector3.new(unload.size, LAYOUT.PAD_THICKNESS, unload.size),
		color = COLORS.UNLOAD_PAD,
	})
	attachLabel(unloadPad, "DÉCHARGER ICI")
	local conveyor = LAYOUT.CONVEYOR
	placeBlock(entry, {
		name = "Conveyor",
		spot = { x = conveyor.x, z = (conveyor.fromZ + conveyor.toZ) / 2 },
		size = Vector3.new(conveyor.width, conveyor.height, conveyor.toZ - conveyor.fromZ),
		color = COLORS.CONVEYOR,
	})
	entry.silo = placeBlock(entry, { name = "Silo", spot = LAYOUT.SILO, size = Vector3.one, color = COLORS.SILO })
	entry.silo.Shape = Enum.PartType.Cylinder
	entry.siloRoof = TycoonModels.siloRoof(entry.folder, LAYOUT.SILO.radius)
end

local function claimFactory(player: Player)
	local base = PlotService.basePlacement(player)
	local index = PlotService.baseIndexOf(player)
	local floor = index and MapService.basePart(index)
	if entries[player] or not base or not floor then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Tycoon"
	folder.Parent = floor
	local entry: Entry = {
		state = Tycoon.new(),
		base = base,
		folder = folder,
		pads = {},
		silo = nil :: any, -- posés par buildFactory
		siloRoof = nil :: any,
		lastPurchaseAt = -math.huge,
	}
	buildFactory(entry)
	entries[player] = entry
	publish(player, entry)
end

local function tryPurchase(player: Player, entry: Entry, buttonId: string)
	local now = os.clock()
	if now - entry.lastPurchaseAt < TycoonConfig.PURCHASE_COOLDOWN then
		return
	end
	local result = Tycoon.buy(entry.state, buttonId, VehicleService.tierOf(player).id)
	if not result.isPurchased then
		return
	end
	entry.lastPurchaseAt = now
	if result.newTier then
		player:SetAttribute(PlayerAttributes.TIER, result.newTier)
	elseif entry.state.machines[buttonId] then
		buildMachine(entry, buttonId)
	end
	publish(player, entry)
end

local function padUnder(entry: Entry, position: Vector3): string?
	local localX, localZ = MapGeometry.worldToBase(entry.base, position.X, position.Z)
	for buttonId, spot in LAYOUT.PADS do
		if MapGeometry.isOnSquare(localX, localZ, spot.x, spot.z, LAYOUT.PAD_SIZE) then
			return buttonId
		end
	end
	return nil
end

local function checkPads()
	for player, entry in entries do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local buttonId = root and padUnder(entry, root.Position)
		if buttonId and buttonId ~= entry.currentPad then
			tryPurchase(player, entry, buttonId)
		end
		entry.currentPad = buttonId
	end
end

local function payIncome()
	for player, entry in entries do
		Tycoon.tick(entry.state, TycoonConfig.INCOME_INTERVAL, Tycoon.NO_BONUS)
		publish(player, entry)
	end
end

-- Vrai si le joueur se tient sur la grille de déchargement de sa propre base (CDC §7.1).
function TycoonService.isOnUnloadPad(player: Player, position: Vector3): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	local pad = LAYOUT.UNLOAD_PAD
	local localX, localZ = MapGeometry.worldToBase(entry.base, position.X, position.Z)
	return MapGeometry.isOnSquare(localX, localZ, pad.x, pad.z, pad.size)
end

-- Vide le sac dans le silo, dans la limite de sa capacité. Renvoie la valeur déposée.
function TycoonService.unload(player: Player, bag: Bag.Bag): number
	local entry = entries[player]
	if not entry then
		return 0
	end
	local _, value = Bag.withdraw(bag, TycoonConfig.SILO_CAPACITY - entry.state.silo)
	local accepted = Tycoon.deposit(entry.state, value)
	publish(player, entry)
	return accepted
end

-- Crédit direct (panneau de test en Studio ; récompenses aux sprints suivants).
function TycoonService.grant(player: Player, amount: number)
	local entry = entries[player]
	if entry and amount > 0 then
		entry.state.money += amount
		publish(player, entry)
	end
end

local function onPlayerRemoving(player: Player)
	local entry = entries[player]
	if entry then
		entry.folder:Destroy()
		entries[player] = nil
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(PlayerAttributes.BASE_INDEX):Connect(function()
		claimFactory(player)
	end)
	player:GetAttributeChangedSignal(PlayerAttributes.TIER):Connect(function()
		local entry = entries[player]
		if entry then
			refreshPads(player, entry)
		end
	end)
	claimFactory(player)
end

function TycoonService:Start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.Heartbeat:Connect(function(deltaTime: number)
		incomeElapsed += deltaTime
		padElapsed += deltaTime
		if padElapsed >= TycoonConfig.PAD_CHECK_INTERVAL then
			padElapsed = 0
			checkPads()
		end
		if incomeElapsed >= TycoonConfig.INCOME_INTERVAL then
			incomeElapsed -= TycoonConfig.INCOME_INTERVAL
			payIncome()
		end
	end)
end

return TycoonService
