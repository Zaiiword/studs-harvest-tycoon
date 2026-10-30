# Studs Harvest Tycoon

Jeu Roblox : récolte ASMR, Tycoon $/s, PvP « bumper car » et gacha de pets, avec une esthétique de briques à tenons (Classic Studs).

- Cahier des charges analysé, ambiguïtés et décisions : [`docs/ANALYSE_CDC.md`](docs/ANALYSE_CDC.md)
- Règles de code : [`docs/CLEAN_CODE.md`](docs/CLEAN_CODE.md)

## Installation (Windows)
Prérequis : [Git](https://git-scm.com), [Roblox Studio](https://create.roblox.com), [VS Code](https://code.visualstudio.com).

```powershell
cd C:\roblox
git clone https://github.com/Zaiiword/studs-harvest-tycoon.git
cd studs-harvest-tycoon
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
```
`setup.ps1` installe Rokit puis la chaîne d'outils figée dans `rokit.toml` (rojo, lune, wally, selene, stylua, luau-lsp) et les packages Wally (Promise, Signal, Trove, Jest).

Dans Roblox Studio : installer le **plugin Rojo** (Creator Store), puis ouvrir une Baseplate.

## Commandes
| Commande | Effet |
|---|---|
| `.\scripts\dev.ps1` | `rojo serve` : dans Studio, onglet Rojo → **Connect** |
| `.\scripts\test.ps1` | Format + lint + tests Lune (unitaires, intégration, non-régression) |
| `.\scripts\format.ps1` | Formate tout le code avec StyLua |
| `.\scripts\build.ps1` | Génère `build/StudsHarvestTycoon.rbxl` |
| `wally install` | Réinstalle les librairies après une modification de `wally.toml` |

Ouvrez le dossier dans VS Code et acceptez les extensions recommandées (Luau LSP, StyLua, Selene, Rojo).

## Arborescence
```
src/shared/domain   logique métier pure (testée sous Lune)
src/shared/config   équilibrage (aucune logique)
src/shared/util     outils (Loader, Signal, Trove…)
src/shared/net      contrat réseau + validateurs
src/server          MainServer + services
src/client          MainClient + contrôleurs
tests/              unit · integration · regression · e2e
```

## Roadmap
| Sprint | Périmètre | État |
|---|---|---|
| 0 | Setup Rojo, rendu Lego, carte concentrique | 🔜 |
| 1 | Grille de blé, coupe, sac | ⏳ |
| 2 | Véhicules arcade + Bumper PvP | ⏳ |
| 3 | Tycoon silo/usine $/s | ⏳ |
| 4 | Raretés, Rebirth, DataStore | ⏳ |
| 5 | Boss Météorite, météo, sabotage | ⏳ |
| 6 | Œufs, pets, fusion | ⏳ |
| 7 | HUD, VFX, rétention | ⏳ |
| 8 | Monétisation, équilibrage, publication | ⏳ |
