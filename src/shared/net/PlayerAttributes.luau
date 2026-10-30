--!strict
-- Contrat réseau : attributs répliqués posés par le serveur sur chaque Player et lus par les clients.
return table.freeze({
	BASE_INDEX = "BaseIndex", -- n° de base Tycoon (PlotService)
	TIER = "Tier", -- palier d'outil/véhicule (VehicleService au Sprint 2 ; 1 par défaut)
	BAG_COUNT = "BagCount", -- blés dans le sac (HarvestService)
	BAG_CAPACITY = "BagCapacity",
	SILO_VALUE = "SiloValue", -- valeur brute déposée (provisoire jusqu'à TycoonService, Sprint 3)
})
