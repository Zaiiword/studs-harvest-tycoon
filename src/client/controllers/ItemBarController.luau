--!strict
-- Barre d'objets de sabotage à droite de l'écran (CDC §6, §10) : un bouton par objet avec sa quantité
-- (touches 1 à 4 au clavier), et un bouton d'achat en gemmes dessous. Le serveur décide de tout ;
-- ses réponses (« Aucune cible… ») s'affichent dans un message éphémère.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SabotageConfig = require(ReplicatedStorage.Shared.config.SabotageConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local ItemBarController = {}

local ITEM_BAR = UiConfig.ITEM_BAR
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local toast: TextLabel
local toastToken = 0
local countLabels: { [string]: TextLabel } = {}

local function rounded(gui: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

local function newTextButton(parent: Instance, size: UDim2, text: string, color: { number }): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = Bricks.rgb(color)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = FONT
	button.TextScaled = true
	button.Text = text
	rounded(button)
	button.Parent = parent
	return button
end

local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	toast.Visible = true
	task.delay(ITEM_BAR.TOAST_SECONDS, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

local function refreshCount(itemId: string)
	local count = localPlayer:GetAttribute(PlayerAttributes.ITEM_PREFIX .. itemId)
	countLabels[itemId].Text = `×{if typeof(count) == "number" then count else 0}`
end

local function buildSlot(column: Frame, item: SabotageConfig.ItemDef, index: number, remotes: { [string]: RemoteEvent })
	local slot = Instance.new("Frame")
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(ITEM_BAR.BUTTON_SIZE, ITEM_BAR.BUTTON_SIZE + ITEM_BAR.BUY_HEIGHT + 4)
	slot.LayoutOrder = index
	slot.Parent = column
	local size = UDim2.fromOffset(ITEM_BAR.BUTTON_SIZE, ITEM_BAR.BUTTON_SIZE)
	local use = newTextButton(slot, size, `{item.icon}`, ITEM_BAR.COLOR)
	use.Activated:Connect(function()
		remotes.use:FireServer(item.id)
	end)
	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.AnchorPoint = Vector2.new(1, 1)
	count.Position = UDim2.fromScale(1, 1)
	count.Size = UDim2.fromScale(0.6, 0.35)
	count.Font = FONT
	count.TextScaled = true
	count.TextColor3 = Color3.new(1, 1, 1)
	count.TextStrokeTransparency = 0
	count.Parent = use
	countLabels[item.id] = count
	local price = if item.gemPrice then `+ {item.gemPrice} 💎` else "Robux"
	local buy =
		newTextButton(slot, UDim2.fromOffset(ITEM_BAR.BUTTON_SIZE, ITEM_BAR.BUY_HEIGHT), price, ITEM_BAR.BUY_COLOR)
	buy.Position = UDim2.fromOffset(0, ITEM_BAR.BUTTON_SIZE + 4)
	buy.Activated:Connect(function()
		remotes.buy:FireServer(item.id)
	end)
	localPlayer:GetAttributeChangedSignal(PlayerAttributes.ITEM_PREFIX .. item.id):Connect(function()
		refreshCount(item.id)
	end)
	refreshCount(item.id)
end

local function buildBar(remotes: { [string]: RemoteEvent })
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(1, 0.5)
	column.Position = UDim2.new(1, -ITEM_BAR.RIGHT_MARGIN, 0.5, 0)
	column.AutomaticSize = Enum.AutomaticSize.XY
	column.Parent = screenGui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ITEM_BAR.PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column
	for index, item in SabotageConfig.ITEMS do
		buildSlot(column, item, index, remotes)
	end
end

local function buildToast()
	toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -80)
	toast.Size = UDim2.fromOffset(420, 32)
	toast.BackgroundTransparency = 1
	toast.Font = FONT
	toast.TextScaled = true
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.TextStrokeTransparency = 0
	toast.Visible = false
	toast.Parent = screenGui
end

function ItemBarController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ItemBar"
	screenGui.ResetOnSpawn = false
	buildToast()
end

function ItemBarController:Start()
	local remotes = { use = Remotes.event(Remotes.USE_ITEM), buy = Remotes.event(Remotes.BUY_ITEM) }
	buildBar(remotes)
	Remotes.event(Remotes.ITEM_FEEDBACK).OnClientEvent:Connect(showToast)
	UserInputService.InputBegan:Connect(function(input: InputObject, isProcessed: boolean)
		if isProcessed then
			return
		end
		for index, keyName in ITEM_BAR.KEYS do
			local item = SabotageConfig.ITEMS[index]
			if item and input.KeyCode == (Enum.KeyCode :: any)[keyName] then
				remotes.use:FireServer(item.id)
			end
		end
	end)
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return ItemBarController
