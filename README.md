# Studs Harvest Tycoon

Jeu Roblox : récolte ASMR, Tycoon $/s, PvP « bumper car » et gacha de pets, avec une esthétique de briques à tenons (Classic Studs).

- Cahier des charges analysé, ambiguïtés et décisions : [`docs/ANALYSE_CDC.md`](docs/ANALYSE_CDC.md)
- Règles de code : [`docs/CLEAN_CODE.md`](docs/CLEAN_CODE.md)

## Démarrage
```bash
rokit install          # installe rojo, lune, selene, stylua, luau-lsp
rojo serve             # synchronisation avec Roblox Studio (plugin Rojo)
lune run tests/run     # tests unitaires, d'intégration et de non-régression
stylua --check src tests && selene src tests
```

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
