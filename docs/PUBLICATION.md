# Publication : liste de contrôle

À faire dans Roblox Studio et sur le Creator Hub (https://create.roblox.com). Le code est prêt. Ces étapes demandent ton compte Roblox.

## 1. Publier l'expérience

1. Fusionne la dernière branche de sprint dans `main`, puis lance `.\scripts\dev.ps1` et connecte Rojo dans Studio.
2. Dans Studio, choisis File, puis Publish to Roblox, sur l'expérience existante « Tractor Harvest Tycoon » (textes, traductions et réglages dans docs/FICHE_ROBLOX.md).
3. Dans Game Settings :
   - **Security** : active *Enable Studio Access to API Services* (sauvegarde et classements).
   - **Places**, puis **Max Players** : **8**, soit une base par joueur (A20).
   - **Basic Info** : genre Simulation, appareils PC, Mobile, Tablette et Console (CDC, page 1).

## 2. Créer les Gamepasses (Creator Hub, puis Monetization, puis Passes)

| Clé dans `MonetizationConfig` | Nom | Prix |
|---|---|---|
| `InfiniteTrailer` | Remorque Infinie | 499 R$ |
| `IncomeX2` | Revenus ×2 | 299 R$ |
| `Titan` | Pare-Chocs Lourd Titan | 199 R$ |
| `Magnet` | Aimant à Briques & Vitesse | 149 R$ |
| `TripleHatch` | Triple Éclosion & Auto-Hatch | 399 R$ |

## 3. Créer les Developer Products (Monetization, puis Developer Products)

| Clé | Nom | Prix |
|---|---|---|
| `Bazooka` | Bazooka Éjecteur (3 tirs) | 39 R$ |
| `Meteor` | Invoquer Météorite Dorée | 99 R$ |
| `Revenge` | Se venger ! | 39 R$ |
| `StarterPack` | Starter Pack | 99 R$ |

## 4. Renseigner les identifiants

Ouvre `src/shared/config/MonetizationConfig.luau` et remplace chaque `id = 0` par l'identifiant affiché sur le Creator Hub. Fais ensuite un commit et un push.

Tant qu'un identifiant vaut 0, l'offre affiche « Bientôt disponible ! » en jeu publié. Dans Studio, le panneau de test la simule.

## 5. Tester les achats

Dans Studio, une fois les identifiants renseignés, les achats sont **des achats de test gratuits**. Vérifie que :

- le Starter Pack donne bien le Mini-Tracteur Turbo, le Pet Épique et les 10 000 $, puis disparaît ;
- « Se venger » éjecte l'agresseur, ou donne 1 tir de Bazooka si l'agresseur est parti ;
- les Gamepasses s'appliquent tout de suite après l'achat (sans reconnexion) ;
- après Stop puis Play, les achats sont toujours là (sauvegarde).

## 6. Assets à remplacer (facultatif mais recommandé)

Dans `src/shared/config/AssetIds.luau` :

- **Les sons** (Pop, clic, éjection, récompense) utilisent par défaut des fichiers intégrés à Roblox. Remplace-les par des sons du Creator Store.
- **La texture « tenons Lego »** (`STUDS_COLOR_MAP`, `STUDS_NORMAL_MAP`) active le MaterialVariant (A25).

## 7. Conformité Roblox (docs/ANALYSE_CDC.md §4)

- **Éléments aléatoires payants : à trancher (docs/FICHE_ROBLOX.md, section 3).** Aucun œuf n'est vendu directement en Robux, mais le Starter Pack donne 10 000 $, et ces $ paient des œufs. D'après l'exemple du questionnaire Roblox, c'est bien un élément aléatoire payant, et `ArePaidRandomItemsRestricted` n'est pas géré. Les chances sont affichées partout (distributeurs, menu des Pets, roue).
- **`ProcessReceipt`** est idempotent et ne confirme un achat qu'après une sauvegarde réussie.
- **Les noms affichés** (Météorite, statues, annonces) utilisent `DisplayName`, déjà filtré par Roblox. Aucun texte libre n'est saisi par les joueurs.
- **Le sabotage payant** respecte l'immunité de 15 s : on ne peut pas acheter le droit d'éjecter en boucle un même joueur.
- **Le panneau de test** n'existe que dans Studio. Le serveur ignore ses commandes en jeu publié.
