--!strict
-- Boutique Robux 🛒 (CDC §9, §10) façon jeux Roblox les plus joués : fenêtre en dégradé avec croix rouge,
-- onglets Gamepasses / Objets, grille de cartes colorées (icône flottante, badge, bouton d'achat vert).
-- L'achat passe par la fenêtre officielle de Roblox ; le serveur accorde le produit.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local MonetizationConfig = require(ReplicatedStorage.Shared.config.MonetizationConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Perks = require(ReplicatedStorage.Shared.net.Perks)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Grid = require(script.Parent.Parent.ui.Grid)
local HudButton = require(script.Parent.Parent.ui.HudButton)
local Purchase = require(script.Parent.Parent.ui.Purchase)
local Style = require(script.Parent.Parent.ui.Style)
local Tabs = require(script.Parent.Parent.ui.Tabs)
local Window = require(script.Parent.Parent.ui.Window)

local ShopController = {}

type Offer = { key: string, name: string, description: string, price: number }
type Card = {
	icon: TextLabel,
	buy: TextButton,
	gradient: UIGradient,
	price: TextLabel,
	robux: ImageLabel,
	amount: number, -- prix en Robux
}

local SHOP = UiConfig.SHOP
local WINDOW = UiConfig.WINDOW
local HUD = UiConfig.HUD_BUTTON
local DEFAULT_LOOK = { icon = "⭐", top = WINDOW.TOP, bottom = WINDOW.BOTTOM, badge = nil :: string? }
local SHOP_PRODUCTS = { Bazooka = true, Meteor = true } -- les autres produits sont proposés en contexte
local DESCRIPTION_STROKE = 1.5
local NAME_TEXT_SIZE = 26
local DESCRIPTION_TEXT_SIZE = 17
local PRICE_TEXT_SIZE = 30
local BADGE_ROTATION = -8

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local window: Window.Window
local message: TextLabel
local cards: { [string]: Card } = {}
local hasRobuxIcon = true
local clock = 0

local function lookOf(key: string)
	return SHOP.CARDS[key] or DEFAULT_LOOK
end

local function show(text: string?)
	message.Text = text or ""
	message.Visible = text ~= nil
end

local function setPrice(card: Card)
	card.robux.Visible = hasRobuxIcon
	card.price.Text = if hasRobuxIcon then tostring(card.amount) else `{card.amount} R$`
end

local function addBadge(card: Frame, text: string)
	local badge = Instance.new("Frame")
	badge.Position = UDim2.fromOffset(6, 8)
	badge.Size = UDim2.new(0.5, 0, 0, 26)
	badge.Rotation = BADGE_ROTATION
	badge.BackgroundColor3 = Bricks.rgb(SHOP.BADGE_COLOR)
	badge.ZIndex = 3
	Style.corner(badge, UDim.new(0, 8))
	Style.stroke(badge, UiConfig.STROKE_COLOR, 2)
	local label = Style.label(badge, text, UDim2.new(1, -8, 1, -4))
	label.Position = UDim2.fromOffset(4, 2)
	label.ZIndex = 4
	badge.Parent = card
end

local function addBuyButton(card: Frame): (TextButton, UIGradient, TextLabel, ImageLabel)
	local buy = Style.button(card, { top = SHOP.BUY_TOP, bottom = SHOP.BUY_BOTTOM, edge = SHOP.BUY_STROKE })
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -10)
	buy.Size = UDim2.new(1, -20, 0.18, 0)
	Style.shine(buy)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = buy
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row
	local robux = Instance.new("ImageLabel")
	robux.BackgroundTransparency = 1
	robux.Image = AssetIds.ROBUX_ICON
	robux.Size = UDim2.fromScale(0.7, 0.7)
	robux.SizeConstraint = Enum.SizeConstraint.RelativeYY
	robux.Parent = row
	local price = Style.label(row, "", UDim2.fromScale(0.6, 0.8))
	price.AutomaticSize = Enum.AutomaticSize.X
	price.Size = UDim2.fromScale(0, 0.8)
	price.TextScaled = false
	price.TextSize = PRICE_TEXT_SIZE
	return buy, buy:FindFirstChildOfClass("UIGradient") :: UIGradient, price, robux
end

local function buildCard(page: ScrollingFrame, order: number, offer: Offer): Card
	local look = lookOf(offer.key)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	Style.corner(card, UDim.new(0, UiConfig.CORNER_RADIUS + 4))
	Style.gradient(card, look.top, look.bottom)
	Style.stroke(card, WINDOW.STROKE_COLOR, UiConfig.STROKE_THICKNESS)
	Style.shine(card)
	local icon = Style.label(card, look.icon, UDim2.fromScale(1, 0.34))
	icon.Position = UDim2.fromScale(0, 0.06)
	local name = Style.label(card, offer.name, UDim2.new(1, -16, 0.17, 0))
	name.Position = UDim2.new(0, 8, 0.41, 0)
	Style.maxTextSize(name, NAME_TEXT_SIZE)
	local description = Style.label(card, offer.description, UDim2.new(1, -16, 0.2, 0))
	description.Position = UDim2.new(0, 8, 0.59, 0)
	description.TextTransparency = 0.05;
	(description:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = DESCRIPTION_STROKE
	Style.maxTextSize(description, DESCRIPTION_TEXT_SIZE)
	if look.badge then
		addBadge(card, look.badge)
	end
	local buy, gradient, price, robux = addBuyButton(card)
	card.Parent = page
	local built: Card =
		{ icon = icon, buy = buy, gradient = gradient, price = price, robux = robux, amount = offer.price }
	setPrice(built)
	return built
end

local function refreshPasses()
	for _, pass in MonetizationConfig.GAMEPASSES do
		local card = cards[pass.key]
		local isOwned = Perks.hasPass(localPlayer, pass.key)
		local top = if isOwned then SHOP.OWNED_TOP else SHOP.BUY_TOP
		local bottom = if isOwned then SHOP.OWNED_BOTTOM else SHOP.BUY_BOTTOM
		card.gradient.Color = ColorSequence.new(Bricks.rgb(top), Bricks.rgb(bottom))
		card.buy.Active = not isOwned
		if isOwned then
			card.robux.Visible = false
			card.price.Text = "✔ POSSÉDÉ"
		else
			setPrice(card)
		end
	end
end

local function gridPage(): ScrollingFrame
	return Grid.page({
		minWidth = SHOP.CARD_MIN_WIDTH,
		height = SHOP.CARD_HEIGHT,
		minColumns = SHOP.MIN_COLUMNS,
		maxColumns = SHOP.MAX_COLUMNS,
		padding = SHOP.CARD_PADDING,
	})
end

local function buildPasses(page: ScrollingFrame)
	for order, pass in MonetizationConfig.GAMEPASSES do
		local card = buildCard(page, order, pass)
		card.buy.Activated:Connect(function()
			if not Perks.hasPass(localPlayer, pass.key) then
				show(Purchase.pass(pass.key))
			end
		end)
		cards[pass.key] = card
		localPlayer:GetAttributeChangedSignal(PlayerAttributes.PASS_PREFIX .. pass.key):Connect(refreshPasses)
	end
	refreshPasses()
end

local function buildProducts(page: ScrollingFrame)
	for order, product in MonetizationConfig.PRODUCTS do
		if SHOP_PRODUCTS[product.key] then
			local card = buildCard(page, order, product)
			card.buy.Activated:Connect(function()
				show(Purchase.product(product.key))
			end)
			cards[product.key] = card
		end
	end
end

local function buildMessage()
	message = Style.label(window.body, "", UDim2.new(1, -24, 0, 30))
	message.AnchorPoint = Vector2.new(0.5, 1)
	message.Position = UDim2.new(0.5, 0, 1, -8)
	message.BackgroundTransparency = 0.3
	message.BackgroundColor3 = Bricks.rgb(WINDOW.STROKE_COLOR)
	message.ZIndex = 5
	message.Visible = false
	Style.corner(message, UDim.new(0, UiConfig.CORNER_RADIUS))
end

local function animate(deltaTime: number)
	clock += deltaTime
	if not window.isOpen then
		return
	end
	local bob = SHOP.ICON_BOB
	for _, card in cards do
		card.icon.Position = UDim2.new(0, 0, 0.06, math.sin(clock * bob.speed) * bob.height)
	end
end

-- Repli sur « R$ » si l'icône Robux du client n'existe pas (ou plus) sur cette plateforme.
local function checkRobuxIcon()
	ContentProvider:PreloadAsync({ AssetIds.ROBUX_ICON }, function(_, status)
		if status ~= Enum.AssetFetchStatus.Success then
			hasRobuxIcon = false
			for _, card in cards do
				setPrice(card)
			end
			refreshPasses()
		end
	end)
end

function ShopController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Shop"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true -- le fond assombri couvre tout l'écran
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	window = Window.new(screenGui, "Shop", "🛒 BOUTIQUE")
	window.onOpen = function()
		show(nil)
	end
	-- Gros bouton 🛒 du HUD, qui frétille en permanence pour attirer l'œil.
	local hud = HudButton.new(screenGui, {
		icon = "🛒",
		caption = "BOUTIQUE",
		top = HUD.SHOP_TOP,
		bottom = HUD.SHOP_BOTTOM_COLOR,
		fromBottom = HUD.SHOP_BOTTOM,
	})
	hud.wiggles = true
	hud.button.Activated:Connect(function()
		window:toggle()
	end)
end

function ShopController:Start()
	local tabs = Tabs.new(window.body)
	local passes, products = gridPage(), gridPage()
	tabs:add("⭐ GAMEPASSES", passes)
	tabs:add("💥 OBJETS", products)
	buildPasses(passes)
	buildProducts(products)
	tabs:select(1)
	buildMessage()
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(animate)
	task.spawn(checkRobuxIcon)
end

return ShopController
