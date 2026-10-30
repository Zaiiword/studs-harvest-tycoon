# Standards de Clean Code — Studs Harvest Tycoon

Ces règles complètent le cahier des charges. Elles sont **obligatoires** et vérifiées automatiquement en CI quand c'est possible.

## 1. Architecture

### 1.1 Couches (Clean Architecture adaptée à Roblox)
```
src/shared/domain   → logique métier PURE (formules, RNG, grille, économie). Aucune API Roblox (pas de game, workspace, Instance).
src/shared/config   → données d'équilibrage (tables figées). Zéro logique.
src/shared/util     → outils génériques (Signal, Maid/Trove, RateLimiter, Promise-like).
src/shared/net      → contrat réseau : noms des Remotes + validation des paramètres.
src/server/services → orchestration côté serveur (adaptateurs vers DataStore, Players, physique).
src/client/controllers → présentation : input, VFX, UI. Jamais de règle métier.
```
- **Règle de dépendance :** `controllers/services → domain → config`. Le `domain` n'importe jamais un service.
- **Pourquoi :** le domaine pur tourne sous **Lune** (hors Studio), donc 100 % testable en CI.

### 1.2 Principes SOLID appliqués
- **S (une seule responsabilité) :** un service correspond à un sous-domaine (`FieldService` ne gère pas l'argent ; il émet `Harvested` et `EconomyService` crédite).
- **O (ouvert/fermé) :** les nouveaux paliers, œufs et machines s'ajoutent dans `config`, sans toucher au code.
- **L (substitution) :** tous les services respectent le même cycle de vie `Init()` → `Start()` → `Destroy()`.
- **I (interfaces ciblées) :** les services exposent une API publique minimale. Les champs privés sont préfixés par `_`.
- **D (inversion des dépendances) :** on injecte les dépendances (`DataStore`, `Clock`, `Random`) pour pouvoir utiliser des doubles de test (mocks) : `FakeDataStore`, `FakeClock`, `Random.new(seed)`.

### 1.3 Single-Script Architecture
- `MainServer.server.luau` et `MainClient.client.luau` se contentent de **charger, initialiser puis démarrer** les modules. Aucun gameplay dans ces fichiers.
- Ordre garanti : tous les `Init` (sans yield), puis tous les `Start` (yield autorisé, dans `task.spawn`).

## 2. Style Luau

| Règle | Outil |
|---|---|
| `--!strict` en tête de **chaque** fichier | selene + revue |
| Formatage automatique (tabulations, 120 colonnes) | StyLua (`stylua --check`) |
| Lint (variables inutilisées, shadowing, globales interdites) | Selene (`std = roblox`) |
| Analyse de types | `luau-lsp analyze` |

### Conventions de nommage
- Modules et classes en `PascalCase` (`FieldService`), fonctions et variables en `camelCase`, constantes en `UPPER_SNAKE_CASE`.
- Booléens préfixés par `is`, `has`, `can` ou `should` (`isFull`, `canRebirth`).
- Événements au passé (`WheatCut`, `PlayerRebirthed`), requêtes à l'impératif (`RequestCut`).
- Pas d'abréviations obscures. Exception : les termes du domaine (`HP`, `RNG`, `PvP`).

### Fonctions
- Une fonction fait **une seule chose**, en 30 lignes au maximum (60 tolérées pour l'UI déclarative).
- 4 paramètres au maximum. Au-delà, on passe une table typée.
- Retour anticipé (*guard clauses*) plutôt que des `if` imbriqués sur plus de 2 niveaux.
- Pas d'effet de bord caché : une fonction `compute*` ou `get*` ne modifie rien.

### Types
- Chaque structure de données publique a un `export type` (`PlayerProfile`, `Cell`, `TierDef`).
- Pas de `any` sauf à la frontière réseau, où la valeur est immédiatement validée et convertie dans le bon type.
- Les tables de config sont protégées avec `table.freeze` (copie profonde gelée).

## 3. Pas de nombres magiques
- Toute valeur d'équilibrage vit dans `src/shared/config/*`, avec un commentaire qui renvoie au CDC (`-- CDC §5`).
- Seules exceptions : `0`, `1` et `-1` quand leur sens est évident.

## 4. Sécurité et serveur autoritaire
1. **Ne jamais faire confiance au client.** Chaque `RemoteEvent` passe par un **validateur de types** (`net/Validators`) qui vérifie le type, les bornes, les `NaN` et `inf`.
2. **Limite de fréquence** (*token bucket*) pour chaque joueur et chaque remote.
3. Le client **demande** et le serveur **décide**. Les remotes ne transportent jamais de montant d'argent.
4. Les erreurs envoyées au client sont génériques, et les logs serveur sont détaillés.
5. Le DataStore est toujours appelé dans un `pcall` avec réessais et backoff exponentiel. Pas d'écriture en dehors du `ProfileStore` maison.

## 5. Gestion des ressources
- Chaque connexion ou instance créée est enregistrée dans un **Trove/Maid**, nettoyé à `PlayerRemoving` ou à `Destroy`.
- Les objets temporaires (briques volantes, textes flottants) passent par un **pool d'objets** (*object pooling*) : jamais de `Instance.new` dans une boucle chaude.
- On utilise `task.*` uniquement (`task.wait`, `task.spawn`, `task.delay`), jamais `wait()` ou `spawn()`, qui sont dépréciés.

## 6. Tests (pyramide)

| Niveau | Dossier | Outil | Contenu |
|---|---|---|---|
| Unitaire | `tests/unit` | Lune + mini-framework `describe`/`it`/`expect` | Formules, RNG (avec graine), grille, fusion, coûts |
| Intégration | `tests/integration` | Lune + faux objets (*fakes*) | Services du domaine combinés (récolte → silo → revenu, sauvegarde/verrou) |
| Non-régression | `tests/regression` | Lune, « golden values » | Valeurs d'économie figées : toute modification d'équilibrage doit être **intentionnelle** (mise à jour du snapshot) |
| Bout en bout | `tests/e2e` | run-in-roblox / Open Cloud Luau Execution | Scénario joueur simulé dans un vrai DataModel |

- **Règle :** tout bug corrigé ajoute un test de non-régression qui reproduit ce bug.
- **Couverture visée :** 100 % des fonctions de `shared/domain`.
- Les tests sont **déterministes** : `Random.new(seed)` et une horloge injectée, jamais `os.time()` directement.
- Structure Arrange / Act / Assert, un seul comportement par `it`, des noms de test lisibles (« rejette une coupe hors de portée »).

## 7. Git et CI
- **Conventional Commits** : `feat(field): …`, `fix(data): …`, `test:`, `refactor:`, `docs:`, `chore:`.
- Un commit = un changement cohérent. Un push à chaque itération (chaque prompt).
- La CI (GitHub Actions) exécute StyLua check, Selene, puis tous les tests Lune. Un échec bloque la fusion.
- Branches : `main` reste stable, les sprints se font sur `sprint/N-nom`.

## 8. Documentation
- Chaque module commence par un commentaire d'en-tête : rôle, section du CDC, dépendances.
- On commente le **pourquoi**, pas le **quoi**.
- Une décision d'architecture importante donne lieu à un ADR dans `docs/adr/NNNN-titre.md`.
- `CHANGELOG.md` est mis à jour à chaque sprint.

## 9. Performance (60 FPS mobile)
- Pas de `while true do` sans `task.wait`. On préfère `RunService.Heartbeat` avec un accumulateur.
- Pas de `FindFirstChild` en chaîne dans une boucle : on met les références en cache.
- La grille est une table plate indexée `(x - 1) * size + z`, plutôt que des tables imbriquées.
- Les paquets réseau sont regroupés en buffers (`buffer` Luau) pour les lots de coupes.
