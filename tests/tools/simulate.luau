--!strict
-- Affiche la courbe de progression simulée (docs/EQUILIBRAGE.md) : lune run tests/tools/simulate.luau
local EconomySim = require("../helpers/EconomySim")
local r = EconomySim.run(4 * 3600)
for tier = 2, 7 do
	print(string.format("T%d à %.1f min", tier, (r.tierReachedAt[tier] or -60) / 60))
end
print(string.format("Rebirth possible à %.1f min", (r.rebirthReadyAt or -60) / 60))
for _, id in { "Mill", "Path", "WallBack", "Facade", "Oven", "Roof" } do
	print(id, string.format("%.1f min", (r.builtAt[id] or -60) / 60))
end
