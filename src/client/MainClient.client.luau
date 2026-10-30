--!strict
-- Unique point d'entrée client (CDC §11) : charge les contrôleurs, appelle Init() puis Start().
local Loader = require(game:GetService("ReplicatedStorage").Shared.util.Loader)
Loader.boot(script.Parent.controllers)
