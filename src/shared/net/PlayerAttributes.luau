--!strict
-- Contrat réseau : attributs répliqués posés par le serveur sur chaque Player et lus par les clients.
-- Les instants (…_UNTIL) sont en temps serveur : comparer avec workspace:GetServerTimeNow().
return table.freeze({
	BASE_INDEX = "BaseIndex", -- n° de base Tycoon (PlotService)
	TIER = "Tier", -- palier d'outil/véhicule (1 par défaut ; acheté au Garage)
	BAG_COUNT = "BagCount", -- blés dans le sac (HarvestService)
	BAG_CAPACITY = "BagCapacity",
	DIZZY_UNTIL = "DizzyUntil", -- fin du tournis après une éjection (BumperService)
	IMMUNE_UNTIL = "ImmuneUntil", -- fin de la bulle d'immunité aux chocs
	MONEY = "Money", -- trésorerie en $ (TycoonService)
	INCOME_PER_SECOND = "IncomePerSecond", -- cadence de l'usine, 0 si le silo est vide
	SILO_VALUE = "SiloValue", -- valeur brute en attente dans le silo
	SILO_CAPACITY = "SiloCapacity",
	CONVEYOR_RATE = "ConveyorRate", -- $ bruts consommés par seconde (autonomie = silo / débit)
})
