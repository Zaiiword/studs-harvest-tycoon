# Passation — reprise du projet dans une session Claude Code locale

> À donner à Claude au début de la nouvelle session, avec le PDF du cahier des charges.

## Contexte et consignes de l'utilisateur
- Jeu Roblox **Studs Harvest Tycoon**, décrit dans le PDF « Cahier des Charges – Studs Harvest Tycoon » (V1.0, 12 sections, 8 sprints).
- Claude réalise **tout le développement**, y compris la carte (map).
- **Tests obligatoires** : unitaires, intégration, non-régression, bout en bout.
- **Commit + push sur GitHub à chaque prompt** (Conventional Commits).
- Dépôt : https://github.com/Zaiiword/studs-harvest-tycoon — dossier local : `C:\roblox\studs-harvest-tycoon` (Windows).
- Langue des échanges et de la documentation : **français**.

## Ce qui a été fait (3 commits sur `main`)
1. `chore: analyse du CDC, standards clean code et squelette du projet`
2. `test: mini-framework TestKit, tests unitaires des formules et golden de non-régression`
3. `chore: librairies Wally, scripts Windows (setup/dev/test/build), config VS Code et CI`

### Documents
- `docs/ANALYSE_CDC.md` : synthèse, **20 ambiguïtés avec leur décision par défaut (A1 à A20)**, 4 incohérences, conformité Roblox, risques. **À relire avant chaque sprint.**
  - A1 : `PetFactor = 1 + Σ(bonus − 1)`, pour éviter un revenu nul sans pet.
  - A2 : CutPower par palier : 1, 2, 5, 12, 30, 70, 150.
  - A5 : le silo stocke une valeur en $ brute.
  - A15 : le bonus de masse Rebirth +15 % n'est appliqué qu'une fois.
  - A20 : 8 joueurs par serveur.
- `docs/CLEAN_CODE.md` : règles obligatoires.
  - Couches `domain` (pur, sans API Roblox) / `config` / `util` / `net` / `services` / `controllers`.
  - SOLID, `--!strict` partout, aucun nombre magique (tout dans `config`).
  - Serveur autoritaire, validateurs et limite de fréquence sur chaque Remote.
  - Trove et pooling d'objets, `task.*` uniquement.
  - Pyramide de tests, Conventional Commits, ADR.

### Code existant
- `src/shared/config/VehicleConfig.luau` : 7 paliers (CDC §5) et constantes de masse.
- `src/shared/config/EconomyConfig.luau` : constantes d'économie (CDC §8).
- `src/shared/domain/Formulas.luau` : `petFactor`, `incomePerSecond`, `tycoonButtonPrice`, `rebirthCost`, `effectiveMass`, `knockbackForce`.
- `src/shared/util/Loader.luau` : cycle de vie `Init()` puis `Start()`.
- `src/server/MainServer.server.luau` et `src/client/MainClient.client.luau` : points d'entrée uniques.
- `tests/TestKit.luau` (describe/it/expect sous Lune) et `tests/run.luau` (lanceur).
- `tests/unit/Formulas.spec.luau` (9 tests) et `tests/regression/EconomyGolden.spec.luau` (3 golden).

### Outillage
- `rokit.toml` : rojo, lune, selene, stylua, luau-lsp, wally, wally-package-types.
- `wally.toml` : Promise, Signal, Trove ; Jest et JestGlobals en dev. Versions minimales à confirmer au premier `wally install`.
- `default.project.json` : Rojo, avec `Packages` dans ReplicatedStorage et `DevPackages` dans ServerScriptService.
- `scripts/setup.ps1`, `dev.ps1`, `test.ps1`, `format.ps1`, `build.ps1` (Windows) et `scripts/test.sh` (CI).
- `.github/workflows/ci.yml` : wally install, format, lint, tests, build.
- `.vscode/` : extensions recommandées et formatage à l'enregistrement.

## ⚠️ Rien n'a encore été exécuté
L'environnement cloud n'avait ni Lune ni Rojo. Première action de la nouvelle session :
```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
.\scripts\test.ps1
```
Corriger ce qui échoue : versions Wally, chemins `require` Lune, règles Selene/StyLua sur le code existant.
Le push GitHub avait aussi été refusé (403, l'application GitHub Claude n'était pas installée). Le push doit se faire depuis le PC.

## Prochaine étape : Sprint 0
Setup Rojo, rendu Lego Studs (MaterialVariant) et carte concentrique : 8 bases Tycoon sur la couronne extérieure, 4 ponts étroits, anneaux Blé Vert / Maïs Doré / Blé Diamant, cœur central.
La carte doit être générée **par code**, avec ses dimensions dans `config/MapConfig`, et testée sur la géométrie pure (positions des bases et des ponts, rayons des anneaux).
Livrable : la carte visible dans Studio via `rojo serve`, avec les tests, un commit et un push.
