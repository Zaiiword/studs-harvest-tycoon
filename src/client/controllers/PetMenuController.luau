--!strict
-- Menu des Pets 🐾 (CDC §7.2, §10) dans le style de la boutique : inventaire en grille de cartes avec chaque
-- Pet en 3D, fiche détaillée (équiper / retirer, fusionner 5 identiques) et onglet Œufs (ouvrir les Œufs
-- Légendaires gagnés, chances de chaque œuf, A42). Le menu ne fait que demander : PetService valide tout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Formulas = require(ReplicatedStorage.Shared.domain.Formulas)
local Pets = require(ReplicatedStorage.Shared.domain.Pets)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Grid = require(script.Parent.Parent.ui.Grid)
local HudButton = require(script.Parent.Parent.ui.HudButton)
local PetViewport = require(script.Parent.Parent.ui.PetViewport)
local Style = require(script.Parent.Parent.ui.Style)
local Tabs = require(script.Parent.Parent.ui.Tabs)
local Window = require(script.Parent.Parent.ui.Window)

local PetMenuController = {}

type Candy = { button: TextButton, label: TextLabel, isEnabled: boolean }
type Detail = {
	frame: Frame,
	stage: Frame, -- fond du Pet 3D
	name: TextLabel,
	rarity: Frame,
	rarityText: TextLabel,
	stats: TextLabel,
	equip: Candy,
	unequip: Candy,
	fuse: Candy,
	hint: TextLabel,
}
type EggCard = { stock: TextLabel, open: Candy }

local MENU = UiConfig.PET_MENU
local SHOP = UiConfig.SHOP
local WINDOW = UiConfig.WINDOW
local HUD = UiConfig.HUD_BUTTON
local PAD = MENU.PADDING
local WHITE = { 255, 255, 255 }
local LIGHTEN = 0.35
local SELECTED_THICKNESS = 4
local BADGE_SIZE = 26
local CIRCLE = UDim.new(0.5, 0)

local GREEN = { top = SHOP.BUY_TOP, bottom = SHOP.BUY_BOTTOM, edge = SHOP.BUY_STROKE }
local RED = { top = WINDOW.CLOSE_TOP, bottom = WINDOW.CLOSE_BOTTOM, edge = WINDOW.CLOSE_STROKE }
local PURPLE = { top = MENU.FUSE_TOP, bottom = MENU.FUSE_BOTTOM, edge = MENU.FUSE_STROKE }
local GRAY = { top = SHOP.OWNED_TOP, bottom = SHOP.OWNED_BOTTOM, edge = WINDOW.STROKE_COLOR }

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local window: Window.Window
local header: TextLabel
local grid: ScrollingFrame
local empty: TextLabel
local detail: Detail
local eggCards: { [string]: EggCard } = {}
local cardStrokes: { [string]: UIStroke } = {}
local owned: { [string]: number } = {}
local equipped: { string } = {}
local selected: string? = nil
local view: PetViewport.View? = nil
local spinAngle = 0
local actionRemote: RemoteEvent
local openEggRemote: RemoteEvent

local function mix(rgb: { number }, target: { number }, ratio: number): { number }
	return {
		rgb[1] + (target[1] - rgb[1]) * ratio,
		rgb[2] + (target[2] - rgb[2]) * ratio,
		rgb[3] + (target[3] - rgb[3]) * ratio,
	}
end

local function rarityColors(key: string): ({ number }, { number })
	local rgb = Pets.rarityOf(key).color
	return mix(rgb, WHITE, LIGHTEN), mix(rgb, { 0, 0, 0 }, 1 - MENU.DARKEN)
end

local function rainbow(): ColorSequence
	local keypoints = {}
	for index, rgb in MENU.RAINBOW do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#MENU.RAINBOW - 1), Bricks.rgb(rgb)))
	end
	return ColorSequence.new(keypoints)
end

local function equippedCount(key: string): number
	local count = 0
	for _, equippedKey in equipped do
		count += if equippedKey == key then 1 else 0
	end
	return count
end

local function newCandy(parent: Instance, text: string, onClick: () -> ()): Candy
	local button = Style.button(parent, GREEN)
	Style.shine(button)
	local label = Style.label(button, text, UDim2.new(1, -10, 1, -8))
	label.Position = UDim2.fromOffset(5, 4)
	local candy: Candy = { button = button, label = label, isEnabled = true }
	button.Activated:Connect(function()
		if candy.isEnabled then
			onClick()
		end
	end)
	return candy
end

-- Couleurs et texte d'un bouton ; un bouton désactivé devient gris et n'agit plus.
local function setCandy(
	candy: Candy,
	colors: { top: { number }, bottom: { number }, edge: { number } },
	text: string,
	isEnabled: boolean
)
	local shown = if isEnabled then colors else GRAY
	local gradient = candy.button:FindFirstChildOfClass("UIGradient") :: UIGradient
	gradient.Color = ColorSequence.new(Bricks.rgb(shown.top), Bricks.rgb(shown.bottom))
	candy.label.Text = text
	candy.isEnabled = isEnabled
end

local function badge(parent: Instance, text: string, rgb: { number }, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = position
	frame.Size = UDim2.fromOffset(BADGE_SIZE + 8, BADGE_SIZE)
	frame.BackgroundColor3 = Bricks.rgb(rgb)
	frame.ZIndex = 4
	Style.corner(frame, CIRCLE)
	Style.stroke(frame, UiConfig.STROKE_COLOR, 2)
	local label = Style.label(frame, text, UDim2.new(1, -6, 1, -4))
	label.Position = UDim2.fromOffset(3, 2)
	label.ZIndex = 5
	frame.Parent = parent
	return frame
end

-- Fiche détaillée --------------------------------------------------------------------------------------------

local function selectPet(key: string?)
	selected = key
	for cardKey, stroke in cardStrokes do
		local isSelected = cardKey == key
		stroke.Color = Bricks.rgb(if isSelected then MENU.SELECTED_STROKE else WINDOW.STROKE_COLOR)
		stroke.Thickness = if isSelected then SELECTED_THICKNESS else UiConfig.STROKE_THICKNESS
	end
	if view then
		view.frame:Destroy()
		view = nil
	end
	local hasPet = key ~= nil and (owned[key] or 0) > 0
	for _, gui in
		{ detail.name, detail.rarity, detail.stats, detail.equip.button, detail.unequip.button, detail.fuse.button }
	do
		gui.Visible = hasPet
	end
	detail.hint.Visible = not hasPet
	if not key or not hasPet then
		return
	end
	local species, variant = Pets.parse(key)
	local rarity = Pets.rarityOf(key)
	local variantName = if variant and variant.name ~= "" then ` {variant.name}` else ""
	detail.name.Text = `{(species :: PetConfig.SpeciesDef).name}{variantName}`
	detail.rarity.BackgroundColor3 = Bricks.rgb(rarity.color)
	detail.rarityText.Text = rarity.name
	local count, onPet = owned[key], equippedCount(key)
	detail.stats.Text = `Bonus ×{Pets.bonusOf(key)} · Possédés : {count}`
	local slotsLeft = PetConfig.MAX_EQUIPPED - #equipped
	setCandy(detail.equip, GREEN, "ÉQUIPER", count > onPet and slotsLeft > 0)
	setCandy(detail.unequip, RED, if onPet > 0 then `RETIRER ({onPet})` else "RETIRER", onPet > 0)
	local fused = Pets.nextVariant(key)
	local _, nextVariant = Pets.parse(fused or "")
	local fuseText = if nextVariant
		then `FUSIONNER {math.min(count, PetConfig.FUSION_COUNT)}/{PetConfig.FUSION_COUNT} → {nextVariant.name}`
		else "FUSION MAX ✔"
	setCandy(detail.fuse, PURPLE, fuseText, fused ~= nil and count >= PetConfig.FUSION_COUNT)
	view = PetViewport.new(detail.stage, key)
	if view then
		view.frame.Size = UDim2.fromScale(1, 1)
	end
end

local function buildDetail(parent: Frame)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -PAD, 0, 0)
	frame.Size = UDim2.new(MENU.DETAIL_WIDTH, -PAD, 1, -PAD)
	Style.corner(frame, UDim.new(0, UiConfig.CORNER_RADIUS + 4))
	Style.gradient(frame, WHITE, UiConfig.RETENTION_MENU.QUEST_BOTTOM)
	Style.stroke(frame, WINDOW.STROKE_COLOR, UiConfig.STROKE_THICKNESS)
	frame.Parent = parent
	local stage = Instance.new("Frame")
	stage.Position = UDim2.new(0, PAD, 0, PAD)
	stage.Size = UDim2.new(1, -2 * PAD, 0.4, 0)
	stage.BackgroundColor3 = Bricks.rgb(WINDOW.TOP)
	stage.BackgroundTransparency = 0.6
	Style.corner(stage, UDim.new(0, UiConfig.CORNER_RADIUS))
	stage.Parent = frame
	local name = Style.label(frame, "", UDim2.new(1, -2 * PAD, 0.1, 0))
	name.Position = UDim2.new(0, PAD, 0.43, 0)
	local rarity = Instance.new("Frame")
	rarity.AnchorPoint = Vector2.new(0.5, 0)
	rarity.Position = UDim2.fromScale(0.5, 0.54)
	rarity.Size = UDim2.fromScale(0.7, 0.07)
	Style.corner(rarity, CIRCLE)
	Style.stroke(rarity, UiConfig.STROKE_COLOR, 2)
	rarity.Parent = frame
	local rarityText = Style.label(rarity, "", UDim2.new(1, -8, 1, -4))
	rarityText.Position = UDim2.fromOffset(4, 2)
	local stats = Style.label(frame, "", UDim2.new(1, -2 * PAD, 0.07, 0))
	stats.Position = UDim2.new(0, PAD, 0.63, 0)
	local hint = Style.label(frame, "👈 Choisis un Pet", UDim2.new(1, -2 * PAD, 0.1, 0))
	hint.Position = UDim2.new(0, PAD, 0.6, 0)
	local equip = newCandy(frame, "ÉQUIPER", function()
		actionRemote:FireServer("equip", selected)
	end)
	equip.button.Position = UDim2.new(0, PAD, 0.72, 0)
	equip.button.Size = UDim2.new(0.5, -1.5 * PAD, 0.12, 0)
	local unequip = newCandy(frame, "RETIRER", function()
		actionRemote:FireServer("unequip", selected)
	end)
	unequip.button.Position = UDim2.new(0.5, PAD / 2, 0.72, 0)
	unequip.button.Size = UDim2.new(0.5, -1.5 * PAD, 0.12, 0)
	local fuse = newCandy(frame, "FUSIONNER", function()
		actionRemote:FireServer("fuse", selected)
	end)
	fuse.button.Position = UDim2.new(0, PAD, 0.86, 0)
	fuse.button.Size = UDim2.new(1, -2 * PAD, 0.12, 0)
	detail = {
		frame = frame,
		stage = stage,
		name = name,
		rarity = rarity,
		rarityText = rarityText,
		stats = stats,
		equip = equip,
		unequip = unequip,
		fuse = fuse,
		hint = hint,
	}
end

-- Inventaire -------------------------------------------------------------------------------------------------

local function buildCard(key: string, order: number)
	local top, bottom = rarityColors(key)
	local card = Style.button(grid, { top = top, bottom = bottom, edge = WINDOW.STROKE_COLOR })
	card.LayoutOrder = order
	local _, variant = Pets.parse(key)
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	if variant and variant.id == "Rainbow" then
		(card:FindFirstChildOfClass("UIGradient") :: UIGradient).Color = rainbow()
	end
	Style.shine(card)
	local petView = PetViewport.new(card, key)
	if petView then
		petView.frame.Position = UDim2.fromOffset(4, 4)
		petView.frame.Size = UDim2.new(1, -8, 0.74, -4)
	end
	local species = Pets.parse(key)
	local name = Style.label(card, (species :: PetConfig.SpeciesDef).name, UDim2.new(1, -8, 0.22, 0))
	name.Position = UDim2.new(0, 4, 0.76, 0)
	badge(card, `×{owned[key]}`, UiConfig.WINDOW.STROKE_COLOR, UDim2.new(1, -16, 0, 14))
	local onPet = equippedCount(key)
	if onPet > 0 then
		badge(card, if onPet > 1 then `✔{onPet}` else "✔", MENU.EQUIPPED_COLOR, UDim2.new(0, 16, 0, 14))
	end
	if variant and variant.id == "Gold" then
		stroke.Color = Bricks.rgb(MENU.GOLD_STROKE)
	end
	cardStrokes[key] = stroke
	card.Activated:Connect(function()
		selectPet(key)
	end)
end

local function sortedKeys(): { string }
	local keys: { string } = {}
	for key in owned do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local onA, onB = equippedCount(a) > 0, equippedCount(b) > 0
		if onA ~= onB then
			return onA -- les Pets équipés d'abord
		end
		return Pets.bonusOf(a) > Pets.bonusOf(b)
	end)
	return keys
end

local function refreshPets()
	owned = Pets.decodeOwned(localPlayer:GetAttribute(PlayerAttributes.OWNED_PETS))
	equipped = Pets.decodeEquipped(localPlayer:GetAttribute(PlayerAttributes.EQUIPPED_PETS))
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	table.clear(cardStrokes)
	local keys = sortedKeys()
	for order, key in keys do
		buildCard(key, order)
	end
	empty.Visible = #keys == 0
	local bonuses = {}
	for _, key in equipped do
		table.insert(bonuses, Pets.bonusOf(key))
	end
	local factor = math.floor(Formulas.petFactor(bonuses) * 100 + 0.5) / 100
	header.Text = `Équipés : {#equipped} / {PetConfig.MAX_EQUIPPED}  ·  Bonus total ×{factor}`
	local keep = if selected and owned[selected] then selected else keys[1]
	selectPet(keep)
end

local function buildPetsPage(): Frame
	local page = Instance.new("Frame")
	page.BackgroundTransparency = 1
	header = Style.label(page, "", UDim2.new(1 - MENU.DETAIL_WIDTH, -2 * PAD, 0, MENU.HEADER_HEIGHT))
	header.Position = UDim2.fromOffset(PAD, 0)
	grid = Grid.page({
		minWidth = MENU.CARD_MIN_WIDTH,
		height = MENU.CARD_HEIGHT,
		minColumns = MENU.MIN_COLUMNS,
		maxColumns = MENU.MAX_COLUMNS,
		padding = PAD,
	})
	grid.Position = UDim2.fromOffset(0, MENU.HEADER_HEIGHT)
	grid.Size = UDim2.new(1 - MENU.DETAIL_WIDTH, 0, 1, -MENU.HEADER_HEIGHT)
	grid.Parent = page
	empty =
		Style.label(page, "Pas encore de Pet !\nVa aux distributeurs d'œufs 🥚", UDim2.new(0.6, -2 * PAD, 0.3, 0))
	empty.Position = UDim2.new(0, PAD, 0.3, 0)
	buildDetail(page)
	return page
end

-- Œufs ---------------------------------------------------------------------------------------------------------

local function priceText(egg: PetConfig.EggDef): string
	if egg.currency == "money" then
		return `{Format.money(egg.price)} $`
	elseif egg.currency == "gems" then
		return `{egg.price} 💎`
	end
	return "Gagné contre le boss"
end

local function buildOdds(card: Frame, egg: PetConfig.EggDef)
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, PAD, 0.4, 0)
	list.Size = UDim2.new(1, -2 * PAD, 0.42, 0)
	list.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for order, rarity in PetConfig.RARITIES do
		local chance = egg.odds[rarity.id]
		if chance then
			local row = Instance.new("Frame")
			row.LayoutOrder = order
			row.Size = UDim2.new(1, 0, 0, MENU.EGG_ODDS_ROW)
			row.BackgroundColor3 = Bricks.rgb(rarity.color)
			Style.corner(row, CIRCLE)
			Style.stroke(row, UiConfig.STROKE_COLOR, 2)
			local name = Style.label(row, rarity.name, UDim2.new(0.7, -8, 1, -4))
			name.Position = UDim2.fromOffset(8, 2)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local percent = Style.label(row, `{chance} %`, UDim2.new(0.3, -8, 1, -4))
			percent.Position = UDim2.new(0.7, 0, 0, 2)
			percent.TextXAlignment = Enum.TextXAlignment.Right
			row.Parent = list
		end
	end
end

local function buildEggCard(page: ScrollingFrame, order: number, egg: PetConfig.EggDef)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	Style.corner(card, UDim.new(0, UiConfig.CORNER_RADIUS + 4))
	Style.gradient(card, mix(egg.color, WHITE, LIGHTEN), mix(egg.color, { 0, 0, 0 }, 1 - MENU.DARKEN))
	Style.stroke(card, WINDOW.STROKE_COLOR, UiConfig.STROKE_THICKNESS)
	Style.shine(card)
	card.Parent = page
	Style.label(card, "🥚", UDim2.fromScale(1, 0.18)).Position = UDim2.fromScale(0, 0.02)
	local name = Style.label(card, egg.name, UDim2.new(1, -16, 0.1, 0))
	name.Position = UDim2.new(0, 8, 0.2, 0)
	local stock = Style.label(card, priceText(egg), UDim2.new(1, -16, 0.08, 0))
	stock.Position = UDim2.new(0, 8, 0.3, 0)
	buildOdds(card, egg)
	local open = newCandy(card, "AU DISTRIBUTEUR", function()
		openEggRemote:FireServer(egg.id)
	end)
	open.button.AnchorPoint = Vector2.new(0.5, 1)
	open.button.Position = UDim2.new(0.5, 0, 1, -PAD)
	open.button.Size = UDim2.new(1, -2 * PAD, 0.13, 0)
	setCandy(open, GREEN, "AU DISTRIBUTEUR", false)
	eggCards[egg.id] = { stock = stock, open = open }
end

local function refreshEggs()
	for _, egg in PetConfig.EGGS do
		if egg.currency == "item" then
			local count = localPlayer:GetAttribute(PlayerAttributes.ITEM_PREFIX .. egg.id)
			local stock = if typeof(count) == "number" then count else 0
			local card = eggCards[egg.id]
			card.stock.Text = `En stock : ×{stock}`
			setCandy(card.open, GREEN, if stock > 0 then "OUVRIR !" else "AUCUN ŒUF", stock > 0)
		end
	end
end

local function buildEggsPage(): ScrollingFrame
	local page = Grid.page({
		minWidth = MENU.EGG_CARD_MIN_WIDTH,
		height = MENU.EGG_CARD_HEIGHT,
		minColumns = 2,
		maxColumns = #PetConfig.EGGS,
		padding = PAD,
	})
	for order, egg in PetConfig.EGGS do
		buildEggCard(page, order, egg)
	end
	return page
end

local function refresh()
	refreshPets()
	refreshEggs()
end

local function animate(deltaTime: number)
	if window.isOpen and view then
		spinAngle = (spinAngle + MENU.SPIN_SPEED * deltaTime) % (2 * math.pi)
		PetViewport.turn(view, spinAngle)
	end
end

function PetMenuController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetMenu"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true -- le fond assombri couvre tout l'écran
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	window = Window.new(screenGui, "Pets", "🐾 MES PETS")
	window.onOpen = refresh
	local tabs = Tabs.new(window.body)
	tabs:add("🐾 PETS", buildPetsPage())
	tabs:add("🥚 ŒUFS", buildEggsPage())
	tabs:select(1)
	local hud = HudButton.new(screenGui, {
		icon = "🐾",
		caption = "PETS",
		top = HUD.PETS_TOP,
		bottom = HUD.PETS_BOTTOM_COLOR,
		fromBottom = HUD.PETS_BOTTOM,
	})
	hud.button.Activated:Connect(function()
		window:toggle()
	end)
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
			if window.isOpen then
				refresh()
			end
		end)
	end
	RunService.RenderStepped:Connect(animate)
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return PetMenuController
