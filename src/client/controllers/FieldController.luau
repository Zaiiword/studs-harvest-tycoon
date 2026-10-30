--!strict
-- Rendu local du champ (CDC §4 « règle d'architecture client / serveur ») : les 2 500 brins au maximum sont
-- créés une seule fois puis masqués / réaffichés, jamais répliqués par le serveur. Applique les lots
-- FieldCodec et la prédiction de coupe du joueur local (décision A26).
-- Émet CellCut(index, harvesterSlot, x, z, wasPredicted) pour les briques volantes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local FieldGrid = require(ReplicatedStorage.Shared.domain.FieldGrid)
local Rarity = require(ReplicatedStorage.Shared.domain.Rarity)
local FieldCodec = require(ReplicatedStorage.Shared.net.FieldCodec)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Signal = require(ReplicatedStorage.Packages.Signal)

local FieldController = {}

FieldController.CellCut = Signal.new()

-- Miroir local : la rareté réelle de chaque brin vient du serveur (snapshot puis lots).
local grid = FieldGrid.new(function()
	return 0.5
end)
local stalks: { [number]: Part } = {}
local beams: { [number]: Part } = {}
local predicted: { [number]: number } = {} -- index → instant de la prédiction
local predictedCount = 0
local isSnapshotApplied = false
local queuedBatches: { buffer } = {}
local hue = 0
local folder: Folder

local STALK_SIZE = Vector3.new(FieldConfig.STALK_SIZE[1], FieldConfig.STALK_SIZE[2], FieldConfig.STALK_SIZE[3])

local function setBeam(index: number, cell: FieldGrid.Cell, isVisible: boolean)
	local beam = beams[index]
	if not isVisible then
		if beam then
			beam:Destroy() -- un Arc-en-ciel apparaît 1 fois sur 1 000 : pas besoin de pool
			beams[index] = nil
		end
		return
	end
	if beam then
		return
	end
	local height, width = FieldConfig.RAINBOW_BEAM_HEIGHT, FieldConfig.RAINBOW_BEAM_WIDTH
	beam = Bricks.decor("RainbowBeam", Vector3.new(width, height, width), { 255, 255, 255 })
	beam.Material = Enum.Material.Neon
	beam.Transparency = FieldConfig.RAINBOW_BEAM_TRANSPARENCY
	beam.CFrame = CFrame.new(cell.x, MapConfig.FLOOR_TOP + height / 2, cell.z)
	beam.Parent = folder
	beams[index] = beam
end

local function showStalk(index: number)
	local cell = grid:cell(index)
	local part = stalks[index]
	if not cell or not part then
		return
	end
	local size = STALK_SIZE * Rarity.byId(cell.rarity).sizeMultiplier
	local isRainbow = cell.rarity == Rarity.RAINBOW
	part.Size = size
	part.CFrame = CFrame.new(cell.x, MapConfig.FLOOR_TOP + size.Y / 2, cell.z)
	part.Material = if isRainbow then Enum.Material.Neon else Enum.Material.Plastic
	part.Color = Bricks.rgb(FieldConfig.WHEAT_ZONES[cell.zone].color)
	part.Transparency = 0
	setBeam(index, cell, isRainbow)
end

local function hideStalk(index: number)
	local part = stalks[index]
	local cell = grid:cell(index)
	if part and cell then
		part.Transparency = 1
		setBeam(index, cell, false)
	end
end

local function clearPrediction(index: number): boolean
	if predicted[index] == nil then
		return false
	end
	predicted[index] = nil
	predictedCount -= 1
	return true
end

local function applyEvent(event: FieldCodec.FieldEvent)
	local cell = grid:cell(event.index)
	if not cell then
		return
	end
	local wasPredicted = clearPrediction(event.index)
	if event.kind == FieldCodec.EVENT_CUT then
		grid:setCut(event.index)
		hideStalk(event.index)
		FieldController.CellCut:Fire(event.index, event.data, cell.x, cell.z, wasPredicted)
	else
		grid:setGrown(event.index, event.data)
		showStalk(event.index)
	end
end

local function applyBatch(batch: buffer)
	for _, event in FieldCodec.decodeEvents(batch) do
		applyEvent(event)
	end
end

local function applySnapshot(snapshot: buffer?)
	local grown = if snapshot then FieldCodec.decodeSnapshot(snapshot) else nil
	for _, index in grid:activeIndices() do
		if not grown or grown[index] then
			grid:setGrown(index, if grown then grown[index] else Rarity.NORMAL)
			showStalk(index)
		else
			grid:setCut(index)
		end
	end
	-- Les lots reçus pendant la requête sont rejoués : au pire, un brin reste masqué jusqu'à sa repousse.
	isSnapshotApplied = true
	for _, batch in queuedBatches do
		applyBatch(batch)
	end
	table.clear(queuedBatches)
end

-- Une coupe prédite que le serveur n'a pas confirmée à temps réapparaît (refus ou perte de paquet).
local function expirePredictions(now: number)
	for index, at in predicted do
		if now - at >= FieldConfig.PREDICTION_TIMEOUT then
			clearPrediction(index)
			local cell = grid:cell(index)
			if cell and cell.isGrown then
				showStalk(index)
			end
		end
	end
end

local function animateRainbows(deltaTime: number)
	hue = (hue + deltaTime * FieldConfig.RAINBOW_HUE_SPEED) % 1
	local color = Color3.fromHSV(hue, 1, 1)
	for index, beam in beams do
		beam.Color = color
		stalks[index].Color = color
	end
end

-- Lecture seule : sert à la prédiction (HarvestController).
function FieldController.grid(): FieldGrid.FieldGrid
	return grid
end

function FieldController.isPredicted(index: number): boolean
	return predicted[index] ~= nil
end

function FieldController.predictedCount(): number
	return predictedCount
end

-- Masque tout de suite un brin que le joueur local va couper (« zéro latence », CDC §4).
function FieldController.predictCut(index: number): boolean
	local cell = grid:cell(index)
	if not cell or not cell.isGrown or predicted[index] then
		return false
	end
	predicted[index] = os.clock()
	predictedCount += 1
	hideStalk(index)
	return true
end

function FieldController:Init()
	folder = Instance.new("Folder")
	folder.Name = "Field"
	for _, index in grid:activeIndices() do
		local part = Bricks.decor(`Stalk{index}`, STALK_SIZE, FieldConfig.WHEAT_ZONES.GreenWheat.color)
		part.Transparency = 1 -- invisible jusqu'à l'état initial du serveur
		part.Parent = folder
		stalks[index] = part
	end
	folder.Parent = Workspace
end

function FieldController:Start()
	Remotes.event(Remotes.FIELD_BATCH).OnClientEvent:Connect(function(batch: buffer)
		if isSnapshotApplied then
			applyBatch(batch)
		else
			table.insert(queuedBatches, batch)
		end
	end)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		expirePredictions(os.clock())
		animateRainbows(deltaTime)
	end)
	local ok, snapshot = pcall(function()
		return Remotes.func(Remotes.FIELD_SNAPSHOT):InvokeServer()
	end)
	applySnapshot(if ok and typeof(snapshot) == "buffer" then snapshot else nil)
end

return FieldController
