--!strict
-- Rendu local du champ (CDC §4 « règle d'architecture client / serveur ») : les plantes ne sont jamais
-- répliquées par le serveur. Le client garde un miroir de toute la grille, mais n'affiche que les chunks
-- proches de sa caméra : plantes détaillées tout près, plantes simples plus loin, 2 500 au plus (A32, A39).
-- Applique les lots FieldCodec et la prédiction de coupe du joueur local (décision A26).
-- Émet CellCut(index, harvesterSlot, x, z, wasPredicted) pour les briques volantes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local PlantConfig = require(ReplicatedStorage.Shared.config.PlantConfig)
local Bag = require(ReplicatedStorage.Shared.domain.Bag)
local FieldChunks = require(ReplicatedStorage.Shared.domain.FieldChunks)
local FieldGrid = require(ReplicatedStorage.Shared.domain.FieldGrid)
local Rarity = require(ReplicatedStorage.Shared.domain.Rarity)
local FieldCodec = require(ReplicatedStorage.Shared.net.FieldCodec)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Signal = require(ReplicatedStorage.Packages.Signal)
local PlantRenderer = require(script.Parent.Parent.render.PlantRenderer)

local FieldController = {}

FieldController.CellCut = Signal.new()

type ShownChunk = { chunk: FieldChunks.Chunk, kind: PlantRenderer.Kind }

local RENDER_BUDGET: FieldChunks.RenderBudget = {
	detailRadius = PlantConfig.DETAIL_RADIUS,
	detailBudget = PlantConfig.DETAIL_BUDGET,
	farRadius = FieldConfig.RENDER_RADIUS,
	totalBudget = FieldConfig.MAX_STALKS,
}

-- Miroir local : la rareté réelle de chaque brin vient du serveur (snapshot puis lots).
local grid = FieldGrid.new(function()
	return 0.5
end)
local chunkMap = FieldChunks.build(grid)
local plants: { [number]: PlantRenderer.Plant } = {} -- index → plante affichée
local shownChunks: { [number]: ShownChunk } = {}
local beams: { [number]: Part } = {}
local predicted: { [number]: number } = {} -- index → instant de la prédiction
local predictedPlaces = 0 -- places que prendront ces coupes dans le sac (A55)
local isSnapshotApplied = false
local queuedBatches: { buffer } = {}
local hue = 0
local streamElapsed = math.huge
local folder: Folder

-- Faisceau Arc-en-ciel : visible de toute la carte (CDC §4), donc indépendant des chunks affichés.
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

-- Met une plante affichée en accord avec le miroir (debout, coupée ou coupe prédite).
local function renderPlant(index: number)
	local cell = grid:cell(index)
	local plant = plants[index]
	if not cell or not plant then
		return
	end
	if not cell.isGrown or predicted[index] then
		PlantRenderer.hide(plant)
	else
		PlantRenderer.render(plant, index, cell)
	end
end

local function onCellChanged(index: number)
	local cell = grid:cell(index)
	if cell then
		setBeam(index, cell, cell.isGrown and cell.rarity == Rarity.RAINBOW)
		renderPlant(index)
	end
end

local function releaseChunk(shown: ShownChunk)
	for _, index in shown.chunk.indices do
		local plant = plants[index]
		if plant then
			PlantRenderer.release(plant)
			plants[index] = nil
		end
	end
	shownChunks[shown.chunk.key] = nil
end

local function showChunk(chunk: FieldChunks.Chunk, kind: PlantRenderer.Kind)
	for _, index in chunk.indices do
		local plant = PlantRenderer.acquire(kind)
		if not plant then
			break -- impossible tant que FieldChunks.plan respecte les budgets
		end
		plants[index] = plant
		renderPlant(index)
	end
	shownChunks[chunk.key] = { chunk = chunk, kind = kind }
end

-- Affiche les chunks proches du point suivi par la caméra et recycle les plantes des chunks éloignés ou
-- qui changent de niveau de détail.
local function stream()
	local focus = Workspace.CurrentCamera and Workspace.CurrentCamera.Focus.Position
	if not focus then
		return
	end
	local plan = FieldChunks.plan(chunkMap, focus.X, focus.Z, RENDER_BUDGET)
	local wanted: { [number]: { chunk: FieldChunks.Chunk, kind: PlantRenderer.Kind } } = {}
	for _, chunk in plan.detailed do
		wanted[chunk.key] = { chunk = chunk, kind = "detailed" }
	end
	for _, chunk in plan.simple do
		wanted[chunk.key] = { chunk = chunk, kind = "simple" }
	end
	for key, shown in shownChunks do
		local target = wanted[key]
		if not target or target.kind ~= shown.kind then
			releaseChunk(shown)
		end
	end
	for key, target in wanted do
		if not shownChunks[key] then
			showChunk(target.chunk, target.kind)
		end
	end
end

local function clearPrediction(index: number): boolean
	if predicted[index] == nil then
		return false
	end
	predicted[index] = nil
	local cell = grid:cell(index)
	predictedPlaces -= if cell then Bag.placesOf(cell.zone) else 1
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
		FieldController.CellCut:Fire(event.index, event.data, cell.x, cell.z, wasPredicted)
	else
		grid:setGrown(event.index, event.data)
	end
	onCellChanged(event.index)
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
		else
			grid:setCut(index)
		end
		onCellChanged(index)
	end
	-- Les lots reçus pendant la requête sont rejoués : au pire, une plante reste masquée jusqu'à sa repousse.
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
			renderPlant(index)
		end
	end
end

local function animateRainbows(deltaTime: number)
	hue = (hue + deltaTime * FieldConfig.RAINBOW_HUE_SPEED) % 1
	local color = Color3.fromHSV(hue, 1, 1)
	for index, beam in beams do
		beam.Color = color
		local plant, cell = plants[index], grid:cell(index)
		if plant and cell then
			PlantRenderer.paintEars(plant, cell, color)
		end
	end
end

local function onHeartbeat(deltaTime: number)
	expirePredictions(os.clock())
	animateRainbows(deltaTime)
	streamElapsed += deltaTime
	if isSnapshotApplied and streamElapsed >= FieldConfig.STREAM_INTERVAL then
		streamElapsed = 0
		stream()
	end
end

-- Lecture seule : sert à la prédiction (HarvestController).
function FieldController.grid(): FieldGrid.FieldGrid
	return grid
end

function FieldController.isPredicted(index: number): boolean
	return predicted[index] ~= nil
end

function FieldController.predictedPlaces(): number
	return predictedPlaces
end

-- Masque tout de suite une plante que le joueur local va couper (« zéro latence », CDC §4).
function FieldController.predictCut(index: number): boolean
	local cell = grid:cell(index)
	if not cell or not cell.isGrown or predicted[index] then
		return false
	end
	predicted[index] = os.clock()
	predictedPlaces += Bag.placesOf(cell.zone)
	renderPlant(index)
	return true
end

function FieldController:Init()
	folder = Instance.new("Folder")
	folder.Name = "Field"
	PlantRenderer.init(folder, PlantConfig.DETAIL_BUDGET, FieldConfig.MAX_STALKS)
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
	RunService.Heartbeat:Connect(onHeartbeat)
	local ok, snapshot = pcall(function()
		return Remotes.func(Remotes.FIELD_SNAPSHOT):InvokeServer()
	end)
	applySnapshot(if ok and typeof(snapshot) == "buffer" then snapshot else nil)
end

return FieldController
