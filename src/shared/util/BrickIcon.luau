--!strict
-- Icône en briques (A72) : construit la sculpture d'IconConfig et la montre en 3D dans un ViewportFrame.
-- Sert au client (HUD, menus, pop-up) comme au serveur (panneaux des boutons au sol). Une icône inconnue donne un
-- cadre vide plutôt qu'une erreur : un oubli de config ne doit jamais casser une fenêtre.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local IconConfig = require("../config/IconConfig")
local PetConfig = require("../config/PetConfig")
local PetVisualConfig = require("../config/PetVisualConfig")
local Bricks = require("./Bricks")
local EggModel = require("./EggModel")

local BrickIcon = {}

BrickIcon.VIEW_NAME = "IconView"
BrickIcon.ID_ATTRIBUTE = "IconId"
-- Icône posée par le serveur (panneaux des boutons au sol) : une Camera n'est jamais répliquée, donc chaque client
-- construit lui-même la sculpture et sa caméra (BrickIconController).
BrickIcon.REMOTE_TAG = "BrickIcon"

local CAMERA = IconConfig.CAMERA
local SMOOTH = Enum.SurfaceType.Smooth
local MIN_VISIBLE_PIXELS = 2

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function addPiece(model: Model, piece: IconConfig.Piece)
	local part = Instance.new("Part")
	part.Name = "Piece"
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.Size = vector(piece.size)
	local rot = piece.rot
	local turn = if rot then CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])) else CFrame.identity
	part.CFrame = CFrame.new(vector(piece.offset)) * turn
	part.Color = Bricks.rgb(piece.color)
	part.Material = if piece.material then (Enum.Material :: any)[piece.material] else Enum.Material.SmoothPlastic
	if piece.shape then
		part.Shape = (Enum.PartType :: any)[piece.shape]
	end
	part.TopSurface = if piece.studs then Enum.SurfaceType.Studs else SMOOTH
	part.BottomSurface, part.LeftSurface, part.RightSurface = SMOOTH, SMOOTH, SMOOTH
	part.FrontSurface, part.BackSurface = SMOOTH, SMOOTH
	part.Parent = model
end

local function eggModel(eggId: string): Model?
	for _, egg in PetConfig.EGGS do
		if egg.id == eggId then
			local size = vector(PetVisualConfig.DISPENSER.EGG_SIZE)
			return EggModel.build(egg.id, egg.color, size, CFrame.new(0, size.Y / 2, 0))
		end
	end
	return nil
end

function BrickIcon.exists(id: string): boolean
	if string.sub(id, 1, #IconConfig.EGG_PREFIX) == IconConfig.EGG_PREFIX then
		return true
	end
	return IconConfig.ICONS[id] ~= nil
end

-- Sculpture de l'icône `id`, origine au sol. nil si l'icône n'existe pas.
function BrickIcon.model(id: string): Model?
	if string.sub(id, 1, #IconConfig.EGG_PREFIX) == IconConfig.EGG_PREFIX then
		return eggModel(string.sub(id, #IconConfig.EGG_PREFIX + 1))
	end
	local pieces = IconConfig.ICONS[id]
	if not pieces then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	for _, piece in pieces do
		addPiece(model, piece)
	end
	return model
end

local function fill(view: ViewportFrame, id: string)
	for _, child in view:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	local model = BrickIcon.model(id)
	if not model then
		return
	end
	model.Parent = view
	local box, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z) * CAMERA.distance
	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA.fov
	-- La face d'une icône regarde -Z : la caméra se place devant, un peu de côté et au-dessus.
	local eye = box.Position + Vector3.new(CAMERA.side, CAMERA.height, -1).Unit * reach
	camera.CFrame = CFrame.lookAt(eye, box.Position)
	camera.Parent = view
	view.CurrentCamera = camera
end

local function newView(holder: Instance): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.Name = BrickIcon.VIEW_NAME
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromScale(1, 1)
	view.BackgroundTransparency = 1
	view.Ambient = Bricks.rgb(IconConfig.AMBIENT)
	view.LightColor = Bricks.rgb(IconConfig.LIGHT)
	view.LightDirection = vector(IconConfig.LIGHT_DIRECTION)
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = view
	view.Parent = holder
	return view
end

-- Cadre transparent de taille `size`, qui contient l'icône (toujours carrée, centrée). Se place comme un label.
-- Côté serveur, le cadre reste vide : un ViewportFrame répliqué n'affiche rien, même rempli par le client.
function BrickIcon.new(parent: Instance, id: string, size: UDim2): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = size
	holder:SetAttribute(BrickIcon.ID_ATTRIBUTE, id)
	if RunService:IsServer() then
		CollectionService:AddTag(holder, BrickIcon.REMOTE_TAG)
	else
		fill(newView(holder), id)
	end
	holder.Parent = parent
	return holder
end

-- Construit, côté client, l'icône d'un cadre posé par le serveur. Un ViewportFrame ne se dessine que lorsque son
-- contenu change : créé hors de l'écran (taille nulle), il resterait vide. On le redessine donc à chaque fois qu'il
-- réapparaît à l'écran.
-- Un ViewportFrame ne s'affiche pas dans un BillboardGui rangé dans le monde, seulement dans le PlayerGui : le panneau
-- y est déplacé, toujours accroché à sa pièce. Le serveur continue de le mettre à jour (même instance) ; il est
-- détruit si sa pièce quitte le monde (achat, streaming).
local function liftBillboard(holder: Instance)
	local gui = holder:FindFirstAncestorOfClass("BillboardGui")
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not gui or not playerGui or gui:IsDescendantOf(playerGui) then
		return
	end
	local anchor = gui.Adornee or gui.Parent
	if not anchor or not anchor:IsA("PVInstance") then
		return
	end
	gui.Adornee = anchor
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	anchor.AncestryChanged:Connect(function()
		if not anchor:IsDescendantOf(game) then
			gui:Destroy()
		end
	end)
end

function BrickIcon.hydrate(holder: Instance)
	local id = holder:GetAttribute(BrickIcon.ID_ATTRIBUTE)
	if typeof(id) ~= "string" or holder:FindFirstChild(BrickIcon.VIEW_NAME) then
		return
	end
	liftBillboard(holder)
	local view = newView(holder)
	fill(view, id)
	local wasVisible = view.AbsoluteSize.X >= MIN_VISIBLE_PIXELS
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local isVisible = view.AbsoluteSize.X >= MIN_VISIBLE_PIXELS
		if isVisible and not wasVisible then
			local current = holder:GetAttribute(BrickIcon.ID_ATTRIBUTE)
			fill(view, if typeof(current) == "string" then current else id)
		end
		wasVisible = isVisible
	end)
end

-- Remplace l'icône d'un cadre créé par BrickIcon.new (bouton à deux états, par exemple).
function BrickIcon.set(holder: Frame, id: string)
	if holder:GetAttribute(BrickIcon.ID_ATTRIBUTE) == id then
		return
	end
	local view = holder:FindFirstChild(BrickIcon.VIEW_NAME)
	if view and view:IsA("ViewportFrame") then
		fill(view, id)
		holder:SetAttribute(BrickIcon.ID_ATTRIBUTE, id)
	end
end

return BrickIcon
