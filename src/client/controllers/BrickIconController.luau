--!strict
-- Icônes en briques posées par le serveur (A72) : les panneaux des boutons au sol et des œufs. Le serveur ne crée que
-- le cadre ; chaque client y construit son propre ViewportFrame, la sculpture et sa caméra (un ViewportFrame
-- répliqué depuis le serveur n'affiche rien, et une Camera n'est jamais répliquée).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrickIcon = require(ReplicatedStorage.Shared.util.BrickIcon)

local BrickIconController = {}

local function hydrate(holder: Instance)
	BrickIcon.hydrate(holder)
end

function BrickIconController:Start()
	CollectionService:GetInstanceAddedSignal(BrickIcon.REMOTE_TAG):Connect(function(holder)
		task.spawn(hydrate, holder)
	end)
	for _, holder in CollectionService:GetTagged(BrickIcon.REMOTE_TAG) do
		task.spawn(hydrate, holder)
	end
end

return BrickIconController
