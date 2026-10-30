--!strict
-- Contrat réseau : attributs répliqués posés par le serveur sur chaque Player et lus par les clients.
-- Les instants (…_UNTIL) sont en temps serveur : comparer avec workspace:GetServerTimeNow().
return table.freeze({
	BASE_INDEX = "BaseIndex", -- n° de base Tycoon (PlotService)
	TIER = "Tier", -- palier d'outil/véhicule (1 par défaut ; boutique au Sprint 3)
	BAG_COUNT = "BagCount", -- blés dans le sac (HarvestService)
	BAG_CAPACITY = "BagCapacity",
	SILO_VALUE = "SiloValue", -- valeur brute déposée (provisoire jusqu'à TycoonService, Sprint 3)
	DIZZY_UNTIL = "DizzyUntil", -- fin du tournis après une éjection (BumperService)
	IMMUNE_UNTIL = "ImmuneUntil", -- fin de la bulle d'immunité aux chocs
})
