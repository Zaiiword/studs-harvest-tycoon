--!strict
-- Unique point d'entrée serveur (CDC §11) : charge les services, appelle Init() puis Start(). Aucun gameplay ici.
local Loader = require(game:GetService("ReplicatedStorage").Shared.util.Loader)
Loader.boot(script.Parent.services)
