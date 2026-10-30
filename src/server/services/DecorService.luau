--!strict
-- Décor du monde (CDC §2, passe visuelle 1) : murs de la tige, portiques de zone, clôtures et enseignes
-- des bases, arbres de la barre, rambardes des ponts. Placement calculé par Decor (pur, testé).
-- Construit dans Start : la carte de MapService existe déjà (tous les Init passent avant les Start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DecorConfig = require(ReplicatedStorage.Shared.config.DecorConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local Decor = require(ReplicatedStorage.Shared.domain.Decor)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Build = require(script.Parent.Parent.builders.Build)
local MapService = require(script.Parent.MapService)

local DecorService = {}

local WALL, FENCE, TREE, GATE = DecorConfig.STEM_WALL, DecorConfig.FENCE, DecorConfig.TREE, DecorConfig.GATE
local CAP_HEIGHT = 1
local signs: { [number]: TextLabel } = {}

local function folder(name: string): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = Workspace:FindFirstChild(MapService.MAP_NAME)
	return created
end

local function buildWalls()
	local parent = folder("Walls")
	local bottom = MapConfig.WATER_TOP
	local height = MapConfig.FLOOR_TOP + WALL.HEIGHT - bottom
	for k, segment in Decor.stemWalls() do
		local from = Vector3.new(segment.x1, bottom, segment.z1)
		local to = Vector3.new(segment.x2, bottom, segment.z2)
		Build.span(
			parent,
			{ name = `Wall{k}`, from = from, to = to, thickness = WALL.THICKNESS, height = height, color = WALL.COLOR }
		)
		local lift = Vector3.new(0, height, 0)
		Build.span(parent, {
			name = `WallCap{k}`,
			from = from + lift,
			to = to + lift,
			thickness = WALL.THICKNESS + 1,
			height = CAP_HEIGHT,
			color = WALL.CAP_COLOR,
		})
	end
end

local function buildGate(parent: Instance, gate: Decor.Gate)
	local color = GATE.COLORS[gate.id]
	local top = MapConfig.FLOOR_TOP
	for _, side in { -1, 1 } do
		Build.block(parent, {
			name = `{gate.id}Pillar`,
			cframe = CFrame.new(gate.x, top + GATE.HEIGHT / 2, side * gate.halfWidth),
			size = Vector3.new(GATE.PILLAR_SIZE, GATE.HEIGHT, GATE.PILLAR_SIZE),
			color = color,
		})
	end
	local beam = Build.block(parent, {
		name = `{gate.id}Beam`,
		cframe = CFrame.new(gate.x, top + GATE.HEIGHT - GATE.BEAM_HEIGHT / 2, 0),
		size = Vector3.new(GATE.PILLAR_SIZE, GATE.BEAM_HEIGHT, gate.halfWidth * 2 + GATE.PILLAR_SIZE),
		color = color,
	})
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		Build.sign(beam, face, GATE.LABELS[gate.id], GATE.SIGN_TEXT_COLOR)
	end
end

local function buildGates()
	local parent = folder("Gates")
	for _, gate in Decor.bandGates() do
		buildGate(parent, gate)
	end
end

local function buildFenceSegment(parent: Instance, base: MapGeometry.Placement, segment: Decor.Segment)
	local x1, z1 = MapGeometry.baseToWorld(base, segment.x1, segment.z1)
	local x2, z2 = MapGeometry.baseToWorld(base, segment.x2, segment.z2)
	local from, to = Vector3.new(x1, MapConfig.DECK_TOP, z1), Vector3.new(x2, MapConfig.DECK_TOP, z2)
	local length = (to - from).Magnitude
	local posts = math.max(1, math.floor(length / FENCE.POST_SPACING))
	for k = 0, posts do
		local position = from:Lerp(to, k / posts)
		Build.block(parent, {
			name = "Post",
			cframe = CFrame.new(position + Vector3.new(0, FENCE.POST_HEIGHT / 2, 0)),
			size = Vector3.new(FENCE.POST_SIZE, FENCE.POST_HEIGHT, FENCE.POST_SIZE),
			color = FENCE.COLOR,
		})
	end
	for _, railHeight in FENCE.RAIL_HEIGHTS do
		local lift = Vector3.new(0, railHeight, 0)
		Build.span(parent, {
			name = "Rail",
			from = from + lift,
			to = to + lift,
			thickness = FENCE.RAIL_THICKNESS,
			height = FENCE.RAIL_THICKNESS,
			color = FENCE.COLOR,
		})
	end
end

-- Enseigne au nom du propriétaire, à côté de l'entrée de la base (DisplayName : déjà filtré par Roblox).
local function buildBaseSign(parent: Instance, base: MapGeometry.Placement)
	local spec = DecorConfig.BASE_SIGN
	local localX = MapConfig.BASE_SIZE / 2 - FENCE.INSET
	local localZ = -(FENCE.GATE_WIDTH / 2 + spec.WIDTH / 2)
	local x, z = MapGeometry.baseToWorld(base, localX, localZ)
	local board = Build.block(parent, {
		name = "Sign",
		cframe = CFrame.new(x, MapConfig.DECK_TOP + spec.POLE_HEIGHT, z) * CFrame.Angles(0, -base.angle, 0),
		size = Vector3.new(1, spec.HEIGHT, spec.WIDTH),
		color = spec.COLOR,
	})
	signs[base.index] = Build.sign(board, Enum.NormalId.Right, "Base libre", { 255, 255, 255 })
end

local function buildBases()
	for _, base in MapGeometry.baseCenters() do
		local floor = MapService.basePart(base.index)
		if floor then
			local parent = Instance.new("Folder")
			parent.Name = "Decor"
			parent.Parent = floor
			for _, segment in Decor.baseFence() do
				buildFenceSegment(parent, base, segment)
			end
			buildBaseSign(parent, base)
		end
	end
end

local function buildTree(parent: Instance, spot: Decor.Spot)
	local top = MapConfig.FLOOR_TOP
	local trunk = TREE.TRUNK_SIZE
	Build.block(parent, {
		name = "Trunk",
		cframe = CFrame.new(spot.x, top + trunk[2] / 2, spot.z),
		size = Vector3.new(trunk[1], trunk[2], trunk[3]),
		color = TREE.TRUNK_COLOR,
	})
	for _, layer in TREE.LEAF_LAYERS do
		Build.block(parent, {
			name = "Leaves",
			cframe = CFrame.new(spot.x, top + layer.y, spot.z),
			size = Vector3.new(layer.size, TREE.LEAF_HEIGHT, layer.size),
			color = TREE.LEAF_COLOR,
		})
	end
end

local function buildTrees()
	local parent = folder("Trees")
	for _, spot in Decor.treeSpots() do
		buildTree(parent, spot)
	end
end

local function buildBridgeRails()
	local parent = folder("BridgeRails")
	local rail = DecorConfig.BRIDGE_RAIL
	for _, bridge in MapGeometry.bridges() do
		for _, side in { -1, 1 } do
			local z = bridge.z + side * (bridge.width / 2 - rail.THICKNESS / 2)
			Build.span(parent, {
				name = "Rail",
				from = Vector3.new(bridge.x - bridge.length / 2, MapConfig.DECK_TOP, z),
				to = Vector3.new(bridge.x + bridge.length / 2, MapConfig.DECK_TOP, z),
				thickness = rail.THICKNESS,
				height = rail.HEIGHT,
				color = rail.COLOR,
			})
		end
	end
end

local function refreshSign(player: Player, isLeaving: boolean)
	local index = player:GetAttribute(PlayerAttributes.BASE_INDEX)
	local sign = typeof(index) == "number" and signs[index]
	if sign then
		sign.Text = if isLeaving then "Base libre" else `Base de {player.DisplayName}`
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(PlayerAttributes.BASE_INDEX):Connect(function()
		refreshSign(player, false)
	end)
	refreshSign(player, false)
end

function DecorService:Start()
	buildWalls()
	buildGates()
	buildBases()
	buildTrees()
	buildBridgeRails()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		refreshSign(player, true)
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return DecorService
