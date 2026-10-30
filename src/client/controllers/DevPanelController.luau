--!strict
-- Panneau de test à gauche de l'écran, uniquement dans Roblox Studio : boutons de palier 1 à 7 et « +10 K $ ».
-- Affiche le palier actuel pour vérifier que le serveur l'a bien appliqué.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local DevCommands = require(ReplicatedStorage.Shared.net.DevCommands)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)

local DevPanelController = {}

local PANEL = UiConfig.DEV_PANEL
local localPlayer = Players.LocalPlayer

local function newButton(parent: Instance, text: string, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(PANEL.BUTTON_WIDTH, PANEL.BUTTON_HEIGHT)
	button.BackgroundColor3 = Bricks.rgb(PANEL.COLOR)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = (Enum.Font :: any)[UiConfig.FONT]
	button.TextScaled = true
	button.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = button
	button.Activated:Connect(onClick)
	button.Parent = parent
	return button
end

local function buildPanel(remote: RemoteEvent): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, PANEL.LEFT_MARGIN, 0.5, 0)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, PANEL.PADDING)
	layout.Parent = frame
	local status = newButton(frame, "Palier ?", function() end)
	for tier = 1, #VehicleConfig.TIERS do
		newButton(frame, `T{tier}`, function()
			remote:FireServer("tier", tier)
		end)
	end
	newButton(frame, `+{Format.money(DevCommands.MONEY_GRANT)} $`, function()
		remote:FireServer("money")
	end)
	local function showTier()
		status.Text = `Palier {localPlayer:GetAttribute(PlayerAttributes.TIER) or 1}`
	end
	localPlayer:GetAttributeChangedSignal(PlayerAttributes.TIER):Connect(showTier)
	showTier()
	return gui
end

function DevPanelController:Start()
	if not RunService:IsStudio() then
		return
	end
	local gui = buildPanel(Remotes.event(Remotes.DEV_COMMAND))
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return DevPanelController
