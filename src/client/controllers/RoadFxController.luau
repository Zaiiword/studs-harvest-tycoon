--!strict
-- Sensation de vitesse sur le boulevard (A54) : la caméra s'élargit tant qu'on y court ×3.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)

local RoadFxController = {}

local FX = UiConfig.ROAD_FX
local TWEEN = TweenInfo.new(FX.SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local localPlayer = Players.LocalPlayer
local baseFov: number? = nil

local function onChanged()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	baseFov = baseFov or camera.FieldOfView
	local isOnRoad = localPlayer:GetAttribute(PlayerAttributes.ON_ROAD) == true
	local fov = (baseFov :: number) + (if isOnRoad then FX.FOV_BOOST else 0)
	TweenService:Create(camera, TWEEN, { FieldOfView = fov }):Play()
end

function RoadFxController:Start()
	localPlayer:GetAttributeChangedSignal(PlayerAttributes.ON_ROAD):Connect(onChanged)
end

return RoadFxController
