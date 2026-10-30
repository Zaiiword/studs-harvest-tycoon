--!strict
-- Cycle de vie commun des services/contrôleurs : tous les Init (sans yield), puis tous les Start (yield autorisé).

export type Module = { Init: ((self: Module) -> ())?, Start: ((self: Module) -> ())? }

local Loader = {}

function Loader.boot(folder: Instance)
	local modules: { Module } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, (require :: any)(child))
		end
	end
	for _, module in modules do
		if module.Init then
			module:Init()
		end
	end
	for _, module in modules do
		if module.Start then
			task.spawn(module.Start, module)
		end
	end
end

return Loader
