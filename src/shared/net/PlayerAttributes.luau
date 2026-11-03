--!strict
-- Contrat réseau : attributs répliqués posés par le serveur sur chaque Player et lus par les clients.
-- Les instants (…_UNTIL) sont en temps serveur : comparer avec workspace:GetServerTimeNow().
return table.freeze({
	BASE_INDEX = "BaseIndex", -- n° de base Tycoon (PlotService)
	TIER = "Tier", -- palier d'outil/véhicule (1 par défaut ; acheté au Garage)
	BAG_COUNT = "BagCount", -- places occupées dans le sac (HarvestService)
	BAG_CAPACITY = "BagCapacity",
	BAG_BLOCKED = "BagBlocked", -- places demandées par un blé qui ne tient pas dans le sac, 0 sinon (A55)
	ON_ROAD = "OnRoad", -- sur le boulevard ou un pont : vitesse ×3 (A54)
	DIZZY_UNTIL = "DizzyUntil", -- fin du tournis après une éjection (BumperService)
	IMMUNE_UNTIL = "ImmuneUntil", -- fin de la bulle d'immunité aux chocs
	MONEY = "Money", -- trésorerie en $ (TycoonService)
	INCOME_PER_SECOND = "IncomePerSecond", -- cadence de l'usine, 0 si le silo est vide
	SILO_VALUE = "SiloValue", -- valeur brute en attente dans le silo
	SILO_CAPACITY = "SiloCapacity",
	CONVEYOR_RATE = "ConveyorRate", -- $ bruts consommés par seconde (autonomie = silo / débit)
	REBIRTHS = "Rebirths", -- nombre de Rebirths (+50 % de revenus, +15 % de masse chacun)
	GEMS = "Gems", -- Gemmes de Prestige
	IS_DATA_LOADED = "IsDataLoaded", -- vrai une fois le profil chargé (DataService)
	BOOST_UNTIL = "BoostUntil", -- fin du multiplicateur ×3 gagné contre le boss (EventService)
	ITEM_PREFIX = "Item_", -- Item_Mud, Item_Glove… : nombre d'exemplaires (InventoryService)
	EQUIPPED_PETS = "EquippedPets", -- « Dragon:Gold,Cow:Normal » (PetService, Pets.encodeEquipped)
	OWNED_PETS = "OwnedPets", -- « Dragon:Gold=2,Cow:Normal=5 » pour le menu des Pets
	CUT_POWER_MULTIPLIER = "CutPowerMultiplier", -- facteur des Pets sur la puissance de coupe (A2)
	SESSION_STARTED_AT = "SessionStartedAt", -- début de la session (cadeaux de temps de jeu)
	GIFTS_CLAIMED = "GiftsClaimed", -- « 1,2,5 » : cadeaux déjà réclamés dans la session
	WHEEL_READY_AT = "WheelReadyAt", -- prochain tour de roue possible
	QUEST_PROGRESS = "QuestProgress", -- « Harvest=120,Boss=0 » : avancement des quêtes du jour
	QUESTS_CLAIMED = "QuestsClaimed", -- « Harvest,Corn » : quêtes du jour déjà réclamées
	HOME_READY_AT = "HomeReadyAt", -- prochain « Retour Base Instantané » possible (A19)
	PASS_PREFIX = "Pass_", -- Pass_IncomeX2… : vrai si le joueur possède le Gamepass (MonetizationService)
	HAS_TURBO_TRACTOR = "HasTurboTractor", -- Mini-Tracteur Turbo du Starter Pack (A12)
	REVENGE_TARGET = "RevengeTarget", -- nom affiché du dernier agresseur (bouton « Se venger », A14)
	REVENGE_UNTIL = "RevengeUntil", -- fin d'affichage du bouton « Se venger »
	STARTER_OFFER_UNTIL = "StarterOfferUntil", -- fin de l'offre Starter Pack (0 : pas d'offre)
})
