--!strict
-- Charte « Studs Pop » (CDC §10) appliquée à TOUS les boutons de l'interface, sans toucher à chaque écran :
-- rebond élastique (Spring Tween) et clic sonore à chaque appui. Affiche aussi les notifications du serveur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)

local UiFxController = {}

local JUICE = UiConfig.JUICE
local BOUNCE = TweenInfo.new(JUICE.BOUNCE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local localPlayer = Players.LocalPlayer
local clickSound: Sound? = nil
local toast: TextLabel
local toastToken = 0

-- Le rebond passe par un UIScale : la taille réelle du bouton (et donc les mises en page) ne bouge pas.
local function decorate(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	button.Activated:Connect(function()
		scale.Scale = JUICE.BOUNCE_SCALE
		TweenService:Create(scale, BOUNCE, { Scale = 1 }):Play()
		if clickSound then
			SoundService:PlayLocalSound(clickSound)
		end
	end)
end

local function onDescendantAdded(instance: Instance)
	if instance:IsA("GuiButton") then
		decorate(instance)
	end
end

local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	toast.Visible = true
	task.delay(JUICE.TOAST_SECONDS, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

function UiFxController:Init()
	if AssetIds.UI_CLICK_SOUND ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = AssetIds.UI_CLICK_SOUND
		sound.Parent = SoundService
		clickSound = sound
	end
end

function UiFxController:Start()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.DescendantAdded:Connect(onDescendantAdded)
	for _, instance in playerGui:GetDescendants() do
		onDescendantAdded(instance)
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.ResetOnSpawn = false
	toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 200)
	toast.Size = UDim2.fromOffset(480, 34)
	toast.BackgroundTransparency = 1
	toast.Font = (Enum.Font :: any)[UiConfig.FONT]
	toast.TextScaled = true
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.TextStrokeTransparency = 0
	toast.Visible = false
	toast.Parent = gui
	gui.Parent = playerGui
	Remotes.event(Remotes.NOTIFY).OnClientEvent:Connect(showToast)
end

return UiFxController
