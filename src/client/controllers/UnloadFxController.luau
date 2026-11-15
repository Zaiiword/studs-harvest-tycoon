--!strict
-- Déchargement au silo (A68) : le moment où la récolte devient de l'argent doit se voir et s'entendre. Une gerbe de
-- briques part du joueur et monte dans son silo, un « +250 💰 au silo » s'envole au-dessus de lui, et un son de
-- récompense joue. Le serveur envoie la valeur réellement acceptée par le silo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Style = require(script.Parent.Parent.ui.Style)

local UnloadFxController = {}

type Flight = { part: Part, from: Vector3, to: Vector3, startedAt: number }

local FX = UiConfig.UNLOAD_FX
local PARKED = CFrame.new(0, -1000, 0)

local localPlayer = Players.LocalPlayer
local random = Random.new()
local freeBricks: { Part } = {}
local flights: { Flight } = {}
local sound: Sound? = nil

local function rootPart(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Silo de la base du joueur (TycoonService le nomme « Silo » dans le dossier « Tycoon » de la base).
local function siloTop(): Vector3?
	local index = localPlayer:GetAttribute(PlayerAttributes.BASE_INDEX)
	local map = Workspace:FindFirstChild("Map")
	local base = map and map:FindFirstChild(`Base{index}`, true)
	local tycoon = base and base:FindFirstChild("Tycoon")
	local silo = tycoon and tycoon:FindFirstChild("Silo") :: BasePart?
	if not silo then
		return nil
	end
	return silo.Position + Vector3.new(0, silo.Size.X / 2, 0) -- cylindre couché : sa longueur est sur X
end

local function arc(from: Vector3, to: Vector3, t: number): Vector3
	local control = (from + to) / 2 + Vector3.new(0, FX.ARC_HEIGHT, 0)
	return from:Lerp(control, t):Lerp(control:Lerp(to, t), t)
end

local function animate()
	local now = os.clock()
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for k = #flights, 1, -1 do
		local flight = flights[k]
		local t = (now - flight.startedAt) / FX.FLIGHT_SECONDS
		if t >= 0 then
			table.insert(parts, flight.part)
			if t >= 1 then
				table.insert(cframes, PARKED)
				table.insert(freeBricks, flight.part)
				table.remove(flights, k)
			else
				local spin = CFrame.Angles(t * 6, t * 4, 0)
				table.insert(cframes, CFrame.new(arc(flight.from, flight.to, t)) * spin)
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function launch(value: number, from: Vector3, to: Vector3)
	local count = math.clamp(math.floor(math.sqrt(value) * FX.BRICKS_PER_SQRT), FX.MIN_BRICKS, FX.MAX_BRICKS)
	local now = os.clock()
	for k = 1, count do
		local part = table.remove(freeBricks)
		if not part then
			return
		end
		local jitter = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0, 1), random:NextNumber(-1, 1))
		table.insert(flights, { part = part, from = from + jitter, to = to, startedAt = now + k * FX.STAGGER })
	end
end

-- « +250 💰 au silo » qui s'envole au-dessus du joueur.
local function floatText(position: Vector3, text: string)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(position + Vector3.new(0, FX.TEXT_START, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(FX.TEXT_WIDTH, FX.TEXT_HEIGHT)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Style.label(gui, text, UDim2.fromScale(1, 1))
	label.TextColor3 = Bricks.rgb(FX.TEXT_COLOR)
	anchor.Parent = Workspace
	local info = TweenInfo.new(FX.TEXT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame + Vector3.new(0, FX.TEXT_RISE, 0) }):Play()
	local fade = TweenService:Create(label, info, { TextTransparency = 1 })
	fade.Completed:Once(function()
		anchor:Destroy()
	end)
	fade:Play()
end

local function onUnloaded(value: number)
	local root = rootPart()
	if not root or typeof(value) ~= "number" or value <= 0 then
		return
	end
	local target = siloTop()
	if target then
		launch(value, root.Position, target)
	end
	floatText(root.Position, `+{Format.money(value)} 💰 au silo`)
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

function UnloadFxController:Init()
	local folder = Instance.new("Folder")
	folder.Name = "UnloadBricks"
	for k = 1, FX.MAX_BRICKS * 2 do
		local part = Bricks.decor(`Brick{k}`, Vector3.one * FieldConfig.BRICK_SIZE, FieldConfig.BRICK_COLOR)
		part.CFrame = PARKED
		part.Parent = folder
		table.insert(freeBricks, part)
	end
	folder.Parent = Workspace
	if AssetIds.UNLOAD_SOUND ~= "" then
		local unloadSound = Instance.new("Sound")
		unloadSound.SoundId = AssetIds.UNLOAD_SOUND
		unloadSound.PlaybackSpeed = FX.SOUND_SPEED
		unloadSound.Parent = SoundService
		sound = unloadSound
	end
end

function UnloadFxController:Start()
	Remotes.event(Remotes.UNLOADED).OnClientEvent:Connect(onUnloaded)
	RunService.Heartbeat:Connect(animate)
end

return UnloadFxController
