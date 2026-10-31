--!strict
-- Flèches de guidage au sol (A53), comme dans les grands tycoons : des chevrons lumineux défilent du joueur
-- vers son prochain objectif (décharger quand le sac est plein, sinon le bouton abordable le moins cher),
-- en passant par les ponts, et une grosse flèche rebondit au-dessus de la cible. Un bouton ➡️ du HUD les
-- active ou les masque. Purement local : la cible est choisie par Guide à partir des attributs des boutons.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Guide = require(ReplicatedStorage.Shared.domain.Guide)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local HudButton = require(script.Parent.Parent.ui.HudButton)
local Style = require(script.Parent.Parent.ui.Style)

local GuideController = {}

type Chevron = { left: Part, right: Part }

local GUIDE = UiConfig.GUIDE
local HUD = UiConfig.HUD_BUTTON
local CHEVRON = GUIDE.CHEVRON
local OFF = UiConfig.SHOP

local localPlayer = Players.LocalPlayer
local folder: Folder
local chevrons: { Chevron } = {}
local marker: Part
local markerGui: BillboardGui
local markerArrow: TextLabel
local hud: HudButton.HudButton
local rayParams = RaycastParams.new()
local isEnabled = true
local target: Guide.Target? = nil
local clock, sinceRefresh = 0, math.huge

local function numberAttribute(name: string): number?
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

local function isMine(instance: Instance): boolean
	return instance:GetAttribute("OwnerId") == localPlayer.UserId
end

local function situation(): Guide.Situation
	local buttons: { Guide.Button } = {}
	for _, pad in CollectionService:GetTagged(TycoonConfig.PAD_TAG) do
		local price = pad:GetAttribute("Price")
		if pad:IsA("BasePart") and isMine(pad) and typeof(price) == "number" then
			local id = pad:GetAttribute("ButtonId")
			table.insert(buttons, { id = tostring(id), price = price, x = pad.Position.X, z = pad.Position.Z })
		end
	end
	local unload: Guide.Point? = nil
	for _, pad in CollectionService:GetTagged(TycoonConfig.UNLOAD_TAG) do
		if pad:IsA("BasePart") and isMine(pad) then
			unload = { x = pad.Position.X, z = pad.Position.Z }
		end
	end
	local count, capacity = numberAttribute(PlayerAttributes.BAG_COUNT), numberAttribute(PlayerAttributes.BAG_CAPACITY)
	return {
		money = numberAttribute(PlayerAttributes.MONEY) or 0,
		isBagFull = count ~= nil and capacity ~= nil and count >= capacity,
		unload = unload,
		buttons = buttons,
	}
end

-- Chevron « ^ » couché au sol : deux baguettes néon qui se rejoignent vers l'avant.
local function newChevron(): Chevron
	local function arm(): Part
		local part =
			Bricks.decor("Arrow", Vector3.new(CHEVRON.width, CHEVRON.thickness, CHEVRON.length), GUIDE.BUTTON_COLOR)
		part.Material = Enum.Material.Neon
		part.Transparency = 1
		part.Parent = folder
		return part
	end
	return { left = arm(), right = arm() }
end

local function buildMarker()
	marker = Bricks.decor("GuideMarker", Vector3.one * 0.2, GUIDE.BUTTON_COLOR)
	marker.Transparency = 1
	marker.Parent = folder
	markerGui = Instance.new("BillboardGui")
	markerGui.Size = UDim2.fromOffset(GUIDE.MARKER_SIZE, GUIDE.MARKER_SIZE)
	markerGui.AlwaysOnTop = true
	markerGui.LightInfluence = 0
	markerGui.Enabled = false
	markerGui.Parent = marker
	markerArrow = Style.label(markerGui, "▼", UDim2.fromScale(1, 1))
end

local function groundAt(x: number, z: number, aroundY: number): number
	local origin = Vector3.new(x, aroundY + GUIDE.RAY_HEIGHT, z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -GUIDE.RAY_HEIGHT * 3, 0), rayParams)
	return if hit then hit.Position.Y else aroundY
end

local function hideAll()
	for _, chevron in chevrons do
		chevron.left.Transparency, chevron.right.Transparency = 1, 1
	end
	markerGui.Enabled = false
end

-- Pose chaque chevron (pointe vers la cible) ; ceux qui ne servent pas sont masqués.
local function placeChevrons(list: { Guide.Chevron }, footY: number, color: Color3)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local half = CHEVRON.length / 2
	local spreadX, spreadZ = math.sin(CHEVRON.angle) * half, math.cos(CHEVRON.angle) * half
	for index, chevron in chevrons do
		local spot = list[index]
		chevron.left.Transparency = if spot then 0 else 1
		chevron.right.Transparency = chevron.left.Transparency
		chevron.left.Color, chevron.right.Color = color, color
		if spot then
			local y = groundAt(spot.x, spot.z, footY) + GUIDE.LIFT
			local tip =
				CFrame.lookAt(Vector3.new(spot.x, y, spot.z), Vector3.new(spot.x + spot.dirX, y, spot.z + spot.dirZ))
			table.insert(parts, chevron.left)
			table.insert(cframes, tip * CFrame.new(-spreadX, 0, spreadZ) * CFrame.Angles(0, -CHEVRON.angle, 0))
			table.insert(parts, chevron.right)
			table.insert(cframes, tip * CFrame.new(spreadX, 0, spreadZ) * CFrame.Angles(0, CHEVRON.angle, 0))
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function update(deltaTime: number)
	clock += deltaTime
	sinceRefresh += deltaTime
	if sinceRefresh >= GUIDE.REFRESH_SECONDS then
		sinceRefresh = 0
		target = if isEnabled then Guide.target(situation()) else nil
	end
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local goal = target
	if not root or not goal then
		hideAll()
		return
	end
	local from = { x = root.Position.X, z = root.Position.Z }
	local distance = math.sqrt((goal.point.x - from.x) ^ 2 + (goal.point.z - from.z) ^ 2)
	if distance < GUIDE.ARRIVED_DISTANCE then
		hideAll()
		return
	end
	local rgb = if goal.kind == "unload" then GUIDE.UNLOAD_COLOR else GUIDE.BUTTON_COLOR
	local color = Bricks.rgb(rgb)
	local spec = {
		spacing = GUIDE.SPACING,
		start = GUIDE.START,
		maxLength = GUIDE.MAX_LENGTH,
		phase = (clock * GUIDE.SPEED) % GUIDE.SPACING,
	}
	rayParams.FilterDescendantsInstances = { folder, character :: Model }
	placeChevrons(Guide.chevrons(Guide.route(from, goal.point), spec), root.Position.Y, color)
	local bob = math.abs(math.sin(clock * GUIDE.MARKER_BOB.speed)) * GUIDE.MARKER_BOB.height
	local groundY = groundAt(goal.point.x, goal.point.z, root.Position.Y)
	marker.CFrame = CFrame.new(goal.point.x, groundY + GUIDE.MARKER_HEIGHT + bob, goal.point.z)
	markerArrow.TextColor3 = color
	markerGui.Enabled = true
end

local function paintToggle()
	local gradient = hud.button:FindFirstChildOfClass("UIGradient") :: UIGradient
	local top = if isEnabled then HUD.GUIDE_ON_TOP else OFF.OWNED_TOP
	local bottom = if isEnabled then HUD.GUIDE_ON_BOTTOM else OFF.OWNED_BOTTOM
	gradient.Color = ColorSequence.new(Bricks.rgb(top), Bricks.rgb(bottom))
	hud.icon.Text = if isEnabled then "➡️" else "🚫"
	hud.caption.Text = if isEnabled then "FLÈCHES" else "FLÈCHES OFF"
end

function GuideController:Init()
	folder = Instance.new("Folder")
	folder.Name = "Guide"
	folder.Parent = Workspace
	for _ = 1, GUIDE.POOL do
		table.insert(chevrons, newChevron())
	end
	buildMarker()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
end

function GuideController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Guide"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	hud = HudButton.new(gui, {
		icon = "➡️",
		caption = "FLÈCHES",
		top = HUD.GUIDE_ON_TOP,
		bottom = HUD.GUIDE_ON_BOTTOM,
		fromBottom = HUD.GUIDE_BOTTOM,
	})
	hud.button.Activated:Connect(function()
		isEnabled = not isEnabled
		sinceRefresh = math.huge -- applique le changement tout de suite
		paintToggle()
	end)
	paintToggle()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return GuideController
