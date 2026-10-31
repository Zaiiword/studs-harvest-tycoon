--!strict
-- Boutique Robux 🛒 (CDC §9) : Gamepasses permanents (marqués « ✔ » une fois possédés) et produits
-- consommables. L'achat passe par la fenêtre officielle de Roblox ; le serveur accorde le produit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.config.MonetizationConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Perks = require(ReplicatedStorage.Shared.net.Perks)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Purchase = require(script.Parent.Parent.ui.Purchase)

local ShopController = {}

local SHOP = UiConfig.SHOP
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local passButtons: { [string]: TextButton } = {}
local message: TextLabel

local function rounded(gui: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

local function newText(parent: Instance, text: string, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Font = FONT
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = parent
	return label
end

-- Une ligne : nom et description à gauche, bouton de prix à droite.
local function addRow(order: number, title: string, description: string): TextButton
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -12, 0, SHOP.ROW_HEIGHT)
	row.BackgroundColor3 = Bricks.rgb(SHOP.ROW_COLOR)
	row.LayoutOrder = order
	rounded(row)
	row.Parent = list
	newText(row, title, UDim2.new(1, -SHOP.BUTTON_WIDTH - 24, 0.5, 0)).Position = UDim2.fromOffset(10, 2)
	local detail = newText(row, description, UDim2.new(1, -SHOP.BUTTON_WIDTH - 24, 0.45, 0))
	detail.Position = UDim2.new(0, 10, 0.5, 0)
	detail.TextColor3 = Bricks.rgb(SHOP.DETAIL_COLOR)
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -8, 0.5, 0)
	button.Size = UDim2.fromOffset(SHOP.BUTTON_WIDTH, SHOP.ROW_HEIGHT - 16)
	button.BackgroundColor3 = Bricks.rgb(SHOP.BUY_COLOR)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = FONT
	button.TextScaled = true
	rounded(button)
	button.Parent = row
	return button
end

local function show(text: string?)
	if text then
		message.Text = text
	end
end

local function refreshPasses()
	for _, pass in MonetizationConfig.GAMEPASSES do
		local isOwned = Perks.hasPass(localPlayer, pass.key)
		passButtons[pass.key].Text = if isOwned then "✔ Possédé" else `{pass.price} R$`
		passButtons[pass.key].Active = not isOwned
	end
end

local function buildList()
	local order = 0
	for _, pass in MonetizationConfig.GAMEPASSES do
		order += 1
		local button = addRow(order, `⭐ {pass.name}`, pass.description)
		button.Activated:Connect(function()
			if not Perks.hasPass(localPlayer, pass.key) then
				show(Purchase.pass(pass.key))
			end
		end)
		passButtons[pass.key] = button
		localPlayer:GetAttributeChangedSignal(PlayerAttributes.PASS_PREFIX .. pass.key):Connect(refreshPasses)
	end
	for _, product in MonetizationConfig.PRODUCTS do
		if product.key == "Bazooka" or product.key == "Meteor" then -- les autres sont contextuels
			order += 1
			local button = addRow(order, `🛍️ {product.name}`, product.description)
			button.Text = `{product.price} R$`
			button.Activated:Connect(function()
				show(Purchase.product(product.key))
			end)
		end
	end
	refreshPasses()
end

function ShopController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Shop"
	screenGui.ResetOnSpawn = false
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(SHOP.WIDTH, SHOP.HEIGHT)
	panel.BackgroundColor3 = Bricks.rgb(UiConfig.BAG_BAR.BACKGROUND)
	panel.Visible = false
	rounded(panel)
	panel.Parent = screenGui
	newText(panel, "🛒 Boutique", UDim2.new(1, -16, 0, 34)).Position = UDim2.fromOffset(10, 4)
	message = newText(panel, "", UDim2.new(1, -16, 0, 22))
	message.Position = UDim2.new(0, 10, 1, -26)
	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(6, 42)
	list.Size = UDim2.new(1, -12, 1, -72)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local toggle = Instance.new("TextButton")
	toggle.Position = UDim2.new(0, 16, 1, -240)
	toggle.Size = UDim2.fromOffset(64, 64)
	toggle.BackgroundColor3 = Bricks.rgb(SHOP.BUY_COLOR)
	toggle.Font = FONT
	toggle.TextScaled = true
	toggle.Text = "🛒"
	rounded(toggle)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		message.Text = ""
	end)
	toggle.Parent = screenGui
end

function ShopController:Start()
	buildList()
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return ShopController
