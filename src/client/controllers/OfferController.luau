--!strict
-- Offres contextuelles (CDC §10) : bouton « Se venger ! Éjecter [Pseudo] (39 R$) » pendant 6 s après une
-- éjection (A14), et offre Starter Pack de 15 minutes (une fois par compte, A50).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MonetizationConfig = require(ReplicatedStorage.Shared.config.MonetizationConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Purchase = require(script.Parent.Parent.ui.Purchase)

local OfferController = {}

local SHOP = UiConfig.SHOP
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font
local REFRESH_INTERVAL = 0.2

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local revengeButton: TextButton
local starterCard: Frame
local starterTimer: TextLabel
local isStarterDismissed = false
local elapsed = 0

local function priceOf(key: string): number
	for _, product in MonetizationConfig.PRODUCTS do
		if product.key == key then
			return product.price
		end
	end
	return 0
end

local function styled(gui: GuiObject, color: { number })
	gui.BackgroundColor3 = Bricks.rgb(color)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

local function newButton(parent: Instance, text: string, color: { number }): TextButton
	local button = Instance.new("TextButton")
	button.Font = FONT
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	styled(button, color)
	button.Parent = parent
	return button
end

local function buildRevenge()
	revengeButton = newButton(screenGui, "", SHOP.REVENGE_COLOR)
	revengeButton.AnchorPoint = Vector2.new(1, 0.5)
	revengeButton.Position = UDim2.new(1, -96, 0.75, 0)
	revengeButton.Size = UDim2.fromOffset(300, 56)
	revengeButton.Visible = false
	revengeButton.Activated:Connect(function()
		Purchase.product("Revenge")
		revengeButton.Visible = false
	end)
end

local function buildStarter()
	starterCard = Instance.new("Frame")
	starterCard.AnchorPoint = Vector2.new(0.5, 0.5)
	starterCard.Position = UDim2.fromScale(0.5, 0.5)
	starterCard.Size = UDim2.fromOffset(420, 220)
	starterCard.Visible = false
	styled(starterCard, UiConfig.BAG_BAR.BACKGROUND)
	starterCard.Parent = screenGui
	local title = newButton(starterCard, "🎉 STARTER PACK : offre unique !", SHOP.BUY_COLOR)
	title.Size, title.Position, title.Active = UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 8), false
	local content =
		newButton(starterCard, "🚜 Mini-Tracteur Turbo\n🐾 1 Pet Épique\n💰 10 000 $", SHOP.ROW_COLOR)
	content.Size, content.Position, content.Active = UDim2.new(1, -16, 0, 90), UDim2.fromOffset(8, 54), false
	local buy = newButton(starterCard, `{priceOf("StarterPack")} R$`, SHOP.BUY_COLOR)
	buy.Size, buy.Position = UDim2.fromOffset(180, 44), UDim2.fromOffset(8, 160)
	buy.Activated:Connect(function()
		Purchase.product("StarterPack")
	end)
	local close = newButton(starterCard, "Plus tard", SHOP.ROW_COLOR)
	close.Size, close.Position = UDim2.fromOffset(110, 44), UDim2.fromOffset(196, 160)
	close.Activated:Connect(function()
		isStarterDismissed = true
		starterCard.Visible = false
	end)
	starterTimer = Instance.new("TextLabel")
	starterTimer.BackgroundTransparency = 1
	starterTimer.Size, starterTimer.Position = UDim2.fromOffset(96, 44), UDim2.fromOffset(314, 160)
	starterTimer.Font = FONT
	starterTimer.TextScaled = true
	starterTimer.TextColor3 = Color3.new(1, 1, 1)
	starterTimer.Parent = starterCard
end

local function numberAttribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	local revengeLeft = numberAttribute(PlayerAttributes.REVENGE_UNTIL) - now
	revengeButton.Visible = revengeLeft > 0
	if revengeLeft > 0 then
		local target = localPlayer:GetAttribute(PlayerAttributes.REVENGE_TARGET) or "?"
		revengeButton.Text = `💥 Se venger ! Éjecter {target} ({priceOf("Revenge")} R$)`
	end
	local offerLeft = numberAttribute(PlayerAttributes.STARTER_OFFER_UNTIL) - now
	starterCard.Visible = offerLeft > 0 and not isStarterDismissed
	starterTimer.Text = Format.duration(offerLeft)
end

function OfferController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Offers"
	screenGui.ResetOnSpawn = false
	buildRevenge()
	buildStarter()
end

function OfferController:Start()
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			refresh()
		end
	end)
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return OfferController
