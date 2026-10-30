--!strict
-- Menu des Pets (CDC §7.2, §10) : collection avec bonus, équiper / retirer (3 au plus), fusionner 5 identiques,
-- ouvrir les Œufs Légendaires gagnés contre le boss, et chances de chaque œuf (transparence, A42).
-- Le menu ne fait que demander : le serveur valide tout (PetService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Pets = require(ReplicatedStorage.Shared.domain.Pets)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local PetMenuController = {}

local MENU = UiConfig.PET_MENU
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local actionRemote: RemoteEvent
local openEggRemote: RemoteEvent

local function rounded(gui: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

local function newText(parent: Instance, text: string, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = parent
	return label
end

local function newButton(parent: Instance, text: string, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(MENU.BUTTON_WIDTH, MENU.ROW_HEIGHT - 8)
	button.BackgroundColor3 = Bricks.rgb(MENU.BUTTON_COLOR)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = FONT
	button.TextScaled = true
	button.Text = text
	rounded(button)
	button.Activated:Connect(onClick)
	button.Parent = parent
	return button
end

local function newRow(order: number): Frame
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Bricks.rgb(MENU.ROW_COLOR)
	row.Size = UDim2.new(1, -12, 0, MENU.ROW_HEIGHT)
	row.LayoutOrder = order
	rounded(row)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	row.Parent = list
	return row
end

local function petLabel(key: string, count: number): (string, Color3)
	local species, variant = Pets.parse(key)
	local rarity = Pets.rarityOf(key)
	local variantName = if variant and variant.name ~= "" then ` {variant.name}` else ""
	local name = `{(species :: PetConfig.SpeciesDef).name}{variantName} ×{count} · bonus ×{Pets.bonusOf(key)}`
	return name, Bricks.rgb(rarity.color)
end

local function addPetRow(key: string, count: number, equippedCount: number, order: number)
	local row = newRow(order)
	local text, color = petLabel(key, count)
	local label = newText(row, text, color)
	label.Size = UDim2.new(0, MENU.NAME_WIDTH, 1, -8)
	if equippedCount > 0 then
		newButton(row, `Retirer ({equippedCount})`, function()
			actionRemote:FireServer("unequip", key)
		end)
	end
	if count > equippedCount then
		newButton(row, "Équiper", function()
			actionRemote:FireServer("equip", key)
		end)
	end
	if count >= PetConfig.FUSION_COUNT and Pets.nextVariant(key) then
		newButton(row, `Fusionner {PetConfig.FUSION_COUNT}`, function()
			actionRemote:FireServer("fuse", key)
		end)
	end
end

local function addEggRows(order: number): number
	for _, egg in PetConfig.EGGS do
		if egg.currency == "item" then
			local count = localPlayer:GetAttribute(PlayerAttributes.ITEM_PREFIX .. egg.id)
			if typeof(count) == "number" and count > 0 then
				order += 1
				local row = newRow(order)
				newText(row, `🥚 {egg.name} ×{count}`).Size = UDim2.new(0, MENU.NAME_WIDTH, 1, -8)
				newButton(row, "Ouvrir", function()
					openEggRemote:FireServer(egg.id)
				end)
			end
		end
	end
	return order
end

local function addOddsRows(order: number)
	for _, egg in PetConfig.EGGS do
		order += 1
		local parts = {}
		for _, rarity in PetConfig.RARITIES do
			if egg.odds[rarity.id] then
				table.insert(parts, `{rarity.name} {egg.odds[rarity.id]} %`)
			end
		end
		local row = newRow(order)
		newText(row, `{egg.name} : {table.concat(parts, " · ")}`).Size = UDim2.new(1, -8, 1, -8)
	end
end

local function refresh()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local owned = Pets.decodeOwned(localPlayer:GetAttribute(PlayerAttributes.OWNED_PETS))
	local equipped = Pets.decodeEquipped(localPlayer:GetAttribute(PlayerAttributes.EQUIPPED_PETS))
	local keys: { string } = {}
	for key in owned do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return Pets.bonusOf(a) > Pets.bonusOf(b)
	end)
	local order = addEggRows(0)
	for _, key in keys do
		local equippedCount = 0
		for _, equippedKey in equipped do
			equippedCount += if equippedKey == key then 1 else 0
		end
		order += 1
		addPetRow(key, owned[key], equippedCount, order)
	end
	addOddsRows(order + 1)
end

local function buildPanel()
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(MENU.WIDTH, MENU.HEIGHT)
	panel.BackgroundColor3 = Bricks.rgb(UiConfig.BAG_BAR.BACKGROUND)
	panel.Visible = false
	rounded(panel)
	panel.Parent = screenGui
	local title = newText(panel, `🐾 Mes Pets (équipés : {PetConfig.MAX_EQUIPPED} au plus)`)
	title.Size = UDim2.new(1, -16, 0, MENU.ROW_HEIGHT)
	title.Position = UDim2.fromOffset(8, 4)
	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(6, MENU.ROW_HEIGHT + 8)
	list.Size = UDim2.new(1, -12, 1, -(MENU.ROW_HEIGHT + 14))
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
end

local function buildToggle()
	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(0, 1)
	toggle.Position = UDim2.new(0, MENU.TOGGLE_MARGIN, 1, -MENU.TOGGLE_MARGIN)
	toggle.Size = UDim2.fromOffset(MENU.TOGGLE_SIZE, MENU.TOGGLE_SIZE)
	toggle.BackgroundColor3 = Bricks.rgb(MENU.BUTTON_COLOR)
	toggle.Font = FONT
	toggle.TextScaled = true
	toggle.Text = "🐾"
	rounded(toggle)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refresh()
		end
	end)
	toggle.Parent = screenGui
end

function PetMenuController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetMenu"
	screenGui.ResetOnSpawn = false
	buildPanel()
	buildToggle()
end

function PetMenuController:Start()
	actionRemote = Remotes.event(Remotes.PET_ACTION)
	openEggRemote = Remotes.event(Remotes.OPEN_EGG)
	for _, name in
		{
			PlayerAttributes.OWNED_PETS,
			PlayerAttributes.EQUIPPED_PETS,
			PlayerAttributes.ITEM_PREFIX .. "LegendaryEgg",
		}
	do
		localPlayer:GetAttributeChangedSignal(name):Connect(function()
			if panel.Visible then
				refresh()
			end
		end)
	end
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return PetMenuController
