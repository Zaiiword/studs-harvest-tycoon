--!strict
-- Contrat réseau : noms des Remotes (docs/CLEAN_CODE.md §1.1). Le serveur les crée, le client les attend.
-- Aucun Remote ne transporte de montant d'argent ; la récolte n'a besoin d'aucune requête client (décision A26).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

Remotes.FIELD_BATCH = "FieldBatch" -- serveur → clients : lot d'événements FieldCodec toutes les 0,2 s
Remotes.FIELD_SNAPSHOT = "FieldSnapshot" -- client → serveur (RemoteFunction) : état initial du champ
Remotes.DEV_COMMAND = "DevCommand" -- client → serveur : panneau de test, ignoré hors de Studio
Remotes.USE_ITEM = "UseItem" -- client → serveur : (itemId) utiliser un objet de sabotage
Remotes.BUY_ITEM = "BuyItem" -- client → serveur : (itemId) acheter un objet avec des gemmes
Remotes.ITEM_FEEDBACK = "ItemFeedback" -- serveur → client : (message) résultat d'une action d'objet
Remotes.PET_ACTION = "PetAction" -- client → serveur : (action, clé) équiper / retirer / fusionner
Remotes.OPEN_EGG = "OpenEgg" -- client → serveur : (eggId) ouvrir un œuf gagné (Œuf Légendaire)
Remotes.HATCH_RESULT = "HatchResult" -- serveur → client : (eggId, clé) Pet obtenu
Remotes.PET_ANNOUNCE = "PetAnnounce" -- serveur → clients : (nom affiché, clé) Secret Mythique obtenu
Remotes.CLAIM_GIFT = "ClaimGift" -- client → serveur : (index) réclamer un cadeau de temps de jeu
Remotes.SPIN_WHEEL = "SpinWheel" -- client → serveur : tourner la Roue de la Fortune
Remotes.WHEEL_RESULT = "WheelResult" -- serveur → client : (index de case) résultat de la roue
Remotes.CLAIM_QUEST = "ClaimQuest" -- client → serveur : (id) réclamer une quête du jour
Remotes.TELEPORT_HOME = "TeleportHome" -- client → serveur : « Retour Base Instantané » (A19)
Remotes.NOTIFY = "Notify" -- serveur → client : (message) récompense ou refus à afficher

local KINDS: { [string]: string } = {
	[Remotes.PET_ACTION] = "RemoteEvent",
	[Remotes.CLAIM_GIFT] = "RemoteEvent",
	[Remotes.SPIN_WHEEL] = "RemoteEvent",
	[Remotes.WHEEL_RESULT] = "RemoteEvent",
	[Remotes.CLAIM_QUEST] = "RemoteEvent",
	[Remotes.TELEPORT_HOME] = "RemoteEvent",
	[Remotes.NOTIFY] = "RemoteEvent",
	[Remotes.OPEN_EGG] = "RemoteEvent",
	[Remotes.HATCH_RESULT] = "RemoteEvent",
	[Remotes.PET_ANNOUNCE] = "RemoteEvent",
	[Remotes.FIELD_BATCH] = "RemoteEvent",
	[Remotes.FIELD_SNAPSHOT] = "RemoteFunction",
	[Remotes.DEV_COMMAND] = "RemoteEvent",
	[Remotes.USE_ITEM] = "RemoteEvent",
	[Remotes.BUY_ITEM] = "RemoteEvent",
	[Remotes.ITEM_FEEDBACK] = "RemoteEvent",
}

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.event(name: string): RemoteEvent
	return Remotes._get(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return Remotes._get(name) :: RemoteFunction
end

function Remotes._get(name: string): Instance
	local kind = KINDS[name]
	assert(kind, `remote inconnu : {name}`)
	local parent = folder()
	if RunService:IsClient() then
		return parent:WaitForChild(name)
	end
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new(kind)
		remote.Name = name
		remote.Parent = parent
	end
	return remote :: Instance
end

return Remotes
