--!strict
-- Rendu local du champ (CDC §4 « règle d'architecture client / serveur ») : les brins ne sont jamais répliqués
-- par le serveur. Le client garde un miroir de toute la grille, mais n'affiche que les chunks proches de la
-- caméra avec un pool fixe de 2 500 pièces au plus (décision A32). Applique les lots FieldCodec et la
-- prédiction de coupe du joueur local (décision A26).
-- Émet CellCut(index, harvesterSlot, x, z, wasPredicted) pour les briques volantes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local Decor = require(ReplicatedStorage.Shared.domain.Decor)
local FieldChunks = require(ReplicatedStorage.Shared.domain.FieldChunks)
local FieldGrid = require(ReplicatedStorage.Shared.domain.FieldGrid)
local Rarity = require(ReplicatedStorage.Shared.domain.Rarity)
local FieldCodec = require(ReplicatedStorage.Shared.net.FieldCodec)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Signal = require(ReplicatedStorage.Packages.Signal)

local FieldController = {}

FieldController.CellCut = Signal.new()

-- Un brin affiché : une tige fine et un épi (A36).
type Plant = { stem: Part, ear: Part }

local PARKED = CFrame.new(0, -1000, 0)
local PLANT = FieldConfig.PLANT
local STEM_SIZE = Vector3.new(PLANT.STEM[1], PLANT.STEM[2], PLANT.STEM[3])
local EAR_SIZE = Vector3.new(PLANT.EAR[1], PLANT.EAR[2], PLANT.EAR[3])

-- Miroir local : la rareté réelle de chaque brin vient du serveur (snapshot puis lots).
local grid = FieldGrid.new(function()
	return 0.5
end)
local chunkMap = FieldChunks.build(grid)
local freePlants: { Plant } = {}
local stalks: { [number]: Plant } = {} -- index → brin affiché, seulement pour les chunks affichés
local shownChunks: { [number]: FieldChunks.Chunk } = {}
local beams: { [number]: Part } = {}
local predicted: { [number]: number } = {} -- index → instant de la prédiction
local predictedCount = 0
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

local function shaded(rgb: { number }, shade: number): Color3
	local color = Bricks.rgb(rgb)
	return Color3.new(math.min(1, color.R * shade), math.min(1, color.G * shade), math.min(1, color.B * shade))
end

local function setVisible(plant: Plant, isVisible: boolean)
	local transparency = if isVisible then 0 else 1
	plant.stem.Transparency = transparency
	plant.ear.Transparency = transparency
end

-- Met un brin affiché en accord avec le miroir (debout, coupé ou coupe prédite). La tige penche un peu,
-- l'épi la prolonge : chaque brin a sa hauteur, son orientation et sa teinte (A35, A36).
local function renderStalk(index: number)
	local cell = grid:cell(index)
	local plant = stalks[index]
	if not cell or not plant then
		return
	end
	if not cell.isGrown or predicted[index] then
		setVisible(plant, false)
		return
	end
	local variation = Decor.stalkVariation(index)
	local scale = Rarity.byId(cell.rarity).sizeMultiplier
	local stemSize = STEM_SIZE * scale * Vector3.new(1, variation.heightScale, 1)
	local earSize = EAR_SIZE * scale
	local zone = FieldConfig.WHEAT_ZONES[cell.zone]
	local foot = CFrame.new(cell.x, MapConfig.FLOOR_TOP, cell.z)
		* CFrame.Angles(0, variation.yaw, 0)
		* CFrame.Angles(variation.lean, 0, 0)
	plant.stem.Size, plant.ear.Size = stemSize, earSize
	plant.stem.CFrame = foot * CFrame.new(0, stemSize.Y / 2, 0)
	plant.ear.CFrame = foot * CFrame.new(0, stemSize.Y + earSize.Y / 2, 0)
	plant.stem.Color = shaded(zone.stemColor, variation.shade)
	plant.ear.Color = shaded(zone.color, variation.shade)
	plant.ear.Material = if cell.rarity == Rarity.RAINBOW then Enum.Material.Neon else Enum.Material.Plastic
	setVisible(plant, true)
end

local function onCellChanged(index: number)
	local cell = grid:cell(index)
	if cell then
		setBeam(index, cell, cell.isGrown and cell.rarity == Rarity.RAINBOW)
		renderStalk(index)
	end
end

local function releaseChunk(chunk: FieldChunks.Chunk)
	for _, index in chunk.indices do
		local plant = stalks[index]
		if plant then
			setVisible(plant, false)
			plant.stem.CFrame, plant.ear.CFrame = PARKED, PARKED
			table.insert(freePlants, plant)
			stalks[index] = nil
		end
	end
	shownChunks[chunk.key] = nil
end

local function showChunk(chunk: FieldChunks.Chunk)
	for _, index in chunk.indices do
		local plant = table.remove(freePlants)
		if not plant then
			return -- impossible tant que FieldChunks.visible respecte le budget
		end
		stalks[index] = plant
		renderStalk(index)
	end
	shownChunks[chunk.key] = chunk
end

-- Affiche les chunks proches du point suivi par la caméra et recycle les pièces des chunks éloignés.
local function stream()
	local focus = Workspace.CurrentCamera and Workspace.CurrentCamera.Focus.Position
	if not focus then
		return
	end
	local visible = FieldChunks.visible(chunkMap, focus.X, focus.Z, FieldConfig.RENDER_RADIUS, FieldConfig.MAX_STALKS)
	local wanted: { [number]: FieldChunks.Chunk } = {}
	for _, chunk in visible do
		wanted[chunk.key] = chunk
	end
	for key, chunk in shownChunks do
		if not wanted[key] then
			releaseChunk(chunk)
		end
	end
	for key, chunk in wanted do
		if not shownChunks[key] then
			showChunk(chunk)
		end
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
			renderStalk(index)
		end
	end
end

local function animateRainbows(deltaTime: number)
	hue = (hue + deltaTime * FieldConfig.RAINBOW_HUE_SPEED) % 1
	local color = Color3.fromHSV(hue, 1, 1)
	for index, beam in beams do
		beam.Color = color
		local plant = stalks[index]
		if plant then
			plant.ear.Color = color
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
	renderStalk(index)
	return true
end

function FieldController:Init()
	folder = Instance.new("Folder")
	folder.Name = "Field"
	local zone = FieldConfig.WHEAT_ZONES.GreenWheat
	for k = 1, FieldConfig.MAX_STALKS do
		local plant = {
			stem = Bricks.decor(`Stem{k}`, STEM_SIZE, zone.stemColor),
			ear = Bricks.decor(`Ear{k}`, EAR_SIZE, zone.color),
		}
		for _, part in { plant.stem, plant.ear } do
			part.Transparency = 1
			part.CFrame = PARKED
			part.Parent = folder
		end
		table.insert(freePlants, plant)
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
	RunService.Heartbeat:Connect(onHeartbeat)
	local ok, snapshot = pcall(function()
		return Remotes.func(Remotes.FIELD_SNAPSHOT):InvokeServer()
	end)
	applySnapshot(if ok and typeof(snapshot) == "buffer" then snapshot else nil)
end

return FieldController
