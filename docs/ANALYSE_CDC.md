# Analyse du Cahier des Charges — Studs Harvest Tycoon (V1.0)

Ce document résume le cahier des charges et relève les **ambiguïtés**, les **incohérences** et les **risques**.
Chaque point ouvert reçoit une **décision par défaut** (marquée `DÉCISION`). Toutes ces valeurs sont centralisées
dans `src/shared/config/` pour pouvoir être modifiées sans toucher au code.

---

## 1. Synthèse fonctionnelle

| Pilier | Contenu | Sprint |
|---|---|---|
| Récolte ASMR | Grille serveur de 2 500 cellules, coupe via requête spatiale toutes les 0,15 s, sac/remorque, RNG Géant (1/100) et Arc-en-ciel (1/1000) | 1, 4 |
| Véhicules & Bumper PvP | 7 paliers, contrôleur arcade (LinearVelocity), knockback calculé par le serveur, immunité de 15 s | 2 |
| Tycoon $/s | Silo → tapis → machines (×1,5 / ×3 / ×8), coût `Base × 1,35^n` | 3 |
| Prestige | Rebirth : +50 % de revenus, +15 % de masse, gemmes, œufs exclusifs | 4 |
| Événements | Boss Météorite (12 min, 50k PV, Top 3), météo (Pluie Dorée / Vent / Nuit Néon), objets de sabotage | 5 |
| Gacha Pets | 5 raretés, fusion 5→Or (×2)→Arc-en-ciel (×5), pets qui suivent le joueur | 6 |
| Rétention & UI | 9 cadeaux de temps de jeu, roue quotidienne, quêtes, 3 statues, HUD « Studs Pop » | 7 |
| Monétisation | 5 Gamepasses, 2 DevProducts, Starter Pack (15 min) | 8 |

**Architecture imposée :** Luau, un seul script d'entrée serveur et un seul script d'entrée client, services et contrôleurs dans des ModuleScripts, serveur autoritaire, DataStore avec verrouillage de session, envois groupés toutes les 0,2 s.

---

## 2. Ambiguïtés et décisions par défaut

| # | Point ambigu | Pourquoi c'est un problème | DÉCISION par défaut |
|---|---|---|---|
| A1 | **`Somme_Bonus_Pets`** dans la formule du revenu | Sans pet, la somme vaut 0, donc le revenu vaut 0 (bug bloquant au démarrage) | `PetFactor = 1 + Σ(bonus_i − 1)` sur les pets équipés. Vaut 1 sans pet. |
| A2 | **Puissance de coupe vs PV du blé** (Maïs 15 PV, Diamant 100 PV) | Les dégâts par coupe ne sont définis nulle part | Dégâts par tick = `CutPower` de l'outil × bonus des pets. Valeurs par palier : 1, 2, 5, 12, 30, 70, 150. |
| A3 | « Tondeuse+ requise » pour l'anneau 2 | Verrou strict ou simple contrainte de dégâts ? | Verrou souple : tout le monde peut entrer, mais en dessous de la Tondeuse les dégâts sont trop faibles pour que ça vaille le coup. |
| A4 | Géant ×10 / Arc-en-ciel ×100 | Le multiplicateur s'applique à quoi ? | Il multiplie la valeur de base de l'anneau. Le Géant a aussi 3× plus de PV. |
| A5 | « Débit_Tapis » et « Valeur_Moyenne_Blé » | Le silo stocke-t-il des unités ou une valeur ? | Le silo stocke une **valeur en $ brute** (somme des blés déposés). Le tapis consomme `ConveyorRate` $ bruts par seconde. Revenu/s = brut consommé × multiplicateurs. |
| A6 | Les machines se cumulent-elles ? | ×1,5 × ×3 × ×8 donne ×36 | Les multiplicateurs se **multiplient** entre eux, et chaque machine a des niveaux qui augmentent le débit. |
| A7 | `Prix_Base` des boutons Tycoon | Non défini | Il est défini pour chaque bouton dans `TycoonConfig` (tapis 50 $, moulin 250 $, four 2 500 $, usine 40 000 $, plus des éléments décoratifs). |
| A8 | « Tycoon complété » (condition du Rebirth) | Non défini | Toutes les machines sont achetées au niveau 1 **et** l'argent atteint `RebirthCost(r) = 1e6 × 3^r`. |
| A9 | Prix des œufs et gemmes du Rebirth | Non définis | Œuf basique 500 $, œuf de ferme 25k $, œuf Rebirth 50 gemmes. Gemmes gagnées = `10 × (r+1)`. |
| A10 | Durée et rotation de la météo | Non définies | Un cycle toutes les 6 min : 4 min de temps clair, puis 2 min d'un événement tiré au sort. |
| A11 | « Hotspots dynamiques » | Mentionnés mais non spécifiés | Une zone de 20 studs avec ×3 de valeur, qui se déplace toutes les 90 s dans l'anneau 3 ou au centre. |
| A12 | Mini-Tracteur Turbo (Starter Pack) | N'existe pas dans le tableau des paliers | Véhicule cosmétique avec les statistiques du Tier 4 et +10 % de vitesse. Il ne remplace pas la progression. |
| A13 | Bazooka (DevProduct) vs Gant de Boxe (gemmes) | Deux objets qui servent à éjecter | Gant : portée de contact, 80 studs d'éjection. Bazooka : projectile de 60 studs de portée, 3 charges. Le serveur valide la ligne de vue. |
| A14 | Le Quick-Fling « Se venger » | À quelle cible s'applique l'achat ? | Le serveur mémorise le dernier agresseur pendant 6 s. L'achat cible ce joueur uniquement. Le produit est remboursé (non consommé) si la cible a quitté la partie. |
| A15 | Masse : Gamepass Titan ×2,5 et Rebirth +15 % | Additif ou multiplicatif ? | Les deux sont **multiplicatifs** : `Masse = MasseTier × 2,5^titan × (1 + 0,15 × r)`. La formule de knockback reprend déjà ce `(1 + 0,15 × r)`, il n'est donc **pas** compté une deuxième fois. |
| A16 | Remorque Infinie | Peut rendre le silo infiniment rempli | Capacité `math.huge`, mais la pénalité « PLEIN » ne s'applique jamais. Le silo garde un plafond de stockage. |
| A17 | Fusion Or ×2 / Arc-en-ciel ×5 | Le multiplicateur porte sur quoi ? | Il multiplie le bonus du pet, qui vaut alors `1 + (bonus − 1) × k`. |
| A18 | Batching 0,2 s vs requête de coupe 0,15 s | Deux fréquences différentes | Le client demande une coupe toutes les 0,15 s (limité par le serveur). Le serveur diffuse les coupes par lots toutes les 0,2 s. |
| A19 | Téléportation « Retour Base Instantané » | Gratuite et illimitée ? | Gratuite, avec 30 s de recharge, disponible seulement si le sac est rempli à 90 % ou plus. |
| A20 | Joueurs par serveur | Non précisé | **8 joueurs maximum**, soit un par base. |
| A21 | Forme de la carte | Le CDC §3 décrit une arène concentrique | **Écart demandé par le porteur de projet** (la version concentrique était jugée minuscule ; référence : une carte « dont on ne voit pas le bout ») : carte **en T**. La barre (« Plaza », 160 × 1 200 studs) porte les 8 bases ; un fossé de 24 studs franchi par 4 ponts étroits la sépare de la tige (le champ, **3 000 studs** de long). Le long de la tige : Blé Vert (0–1 200), Maïs Doré (1 200–2 200), Blé Diamant (2 200–2 800), puis l'arène du boss (2 800–3 000). La tige se rétrécit de 480 à 240 studs de large : on garde l'« entonnoir » du CDC (plus c'est rentable, plus c'est étroit et disputé). 16 062 brins : 8 070 / 5 370 / 2 622. Une brume légère fait se perdre le bout du champ à l'horizon. |
| A22 | Bases | Taille et position non précisées | 8 bases de 120×120 studs alignées sur la barre (pas de 145 studs), tournées vers le champ. Chacune a un SpawnLocation. |
| A23 | Ponts | « 4 ponts étroits » | 4 ponts de 14 studs de large (z = ±60, ±180), avec 10 studs de recouvrement sur chaque rive du fossé. Les bases aux extrémités de la barre doivent la longer : la circulation converge vers les ponts (zones d'embuscade du CDC). Aucun brin ne pousse sous leurs extrémités. |
| A24 | Grille du champ vs hitbox | Une hitbox de 4 studs (Tier 1) rate des brins espacés | Grille 375×60 de cellules de **8 studs**, brins de 2,4 × 4 studs ; une cellule est touchée si son carré recoupe la boîte de coupe (marge d'une demi-cellule). Conséquence assumée : Mains Nues (4) et Faux (7) couvrent souvent le même nombre de rangées ; l'écart entre ces deux paliers vient de la puissance de coupe et de la capacité. |
| A25 | « Rendu Lego authentique (MaterialVariant) » | Un MaterialVariant exige une texture (asset) que le dépôt ne fournit pas | Toutes les briques ont des surfaces natives **Studs** (dessus) et **Inlet** (flancs, dessous), et le sol est posé en briques sur la grille (bord en escalier). Dès que `AssetIds.STUDS_COLOR_MAP` / `STUDS_NORMAL_MAP` sont renseignés, `RenderService` crée le MaterialVariant « LegoStuds » et toutes les briques l'utilisent. |
| A26 | Requête de coupe client (CDC §11 : « il envoie sa position et demande à couper ») | Une position envoyée par le client est une surface d'attaque inutile | **Écart volontaire** : le serveur coupe seul, toutes les 0,15 s, avec la position du `HumanoidRootPart` qu'il connaît déjà. Aucun Remote client → serveur pour la récolte, donc rien à falsifier. Pour le « zéro latence », le client prédit les brins qu'il abat d'un coup et les masque tout de suite ; une prédiction non confirmée réapparaît au bout d'1 s. |
| A27 | Fossé et bords de la carte | Un joueur qui tombe ne peut plus remonter | Un plan d'eau à −10 studs s'étend sous toute la carte ; le toucher renvoie le joueur sur sa base, sans perte de blé (« Protection anti-frustration » du §6). La carte supprime aussi la `Baseplate` et le `SpawnLocation` du modèle Studio, qui masquaient le sol généré. |
| A32 | « Jusqu'à 2 500 plants simultanés » (CDC §4) | Incompatible avec une carte dont on ne voit pas le bout | La limite sert la fluidité sur mobile : elle s'applique aux brins **affichés simultanément**. Le serveur gère toute la grille (16 062 brins, quelques Mo, coût négligeable) ; chaque client affiche les chunks de 8×8 cellules les plus proches de sa caméra (rayon 220 studs) avec un pool fixe de 2 500 pièces recyclées. Le faisceau d'un Blé Arc-en-ciel reste visible de partout. |
| A28 | Silo avant le Sprint 3 | Le déchargement existe dès le Sprint 1 mais l'usine non | Entrer sur sa base vide le sac dans l'attribut provisoire `SiloValue` (valeur brute en $). `TycoonService` le remplacera au Sprint 3. |

## 3. Incohérences relevées

1. **Section 5 : « À partir du Palier 3 »**, alors que le tableau donne Tier 1 (Mains Nues) et Tier 2 (Faux). La Tondeuse (Tier 3) est bien le premier engin. C'est cohérent, mais la Tondeuse doit utiliser le contrôleur véhicule et non une animation à pied.
2. **Double comptage des Rebirths dans la masse** (voir A15) : la section 7 dit « +15 % de masse permanente » et la formule de knockback multiplie aussi par `(1 + 0,15 × r)`. On ne l'applique qu'une seule fois.
3. **Section 8 : `Prix_Base × 1,35n`** : c'est un problème d'exposant perdu dans le PDF. Il faut lire `1,35^n`.
4. **Starter Pack déclenché « après 4 min (au premier remplissage complet du silo) »** : ce sont deux conditions distinctes. **DÉCISION :** la première des deux qui arrive, et l'offre n'est proposée qu'une fois par compte.

## 4. Conformité Roblox (bloquant pour la publication)

- **Paid Random Items** : un objet aléatoire payé en Robux doit afficher ses probabilités. Les œufs payés en $ ou en gemmes ne sont pas concernés, mais l'**Œuf Légendaire** et la roue doivent aussi afficher leurs taux. Il faut aussi vérifier `PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted` pour certains pays.
- **Nom de l'acheteur affiché en géant** (Météorite Dorée) : il faut utiliser `DisplayName`, qui est déjà filtré. Aucun texte libre n'est autorisé.
- **Annonce dans le chat** (Mythique) : passer par `TextChatService` avec un message système.
- **`ProcessReceipt`** : il doit être idempotent, avec un historique des reçus dans le profil, et ne renvoyer `PurchaseGranted` qu'**après** une sauvegarde réussie.
- **Sabotage payant** : l'immunité de 15 s s'applique aussi au Bazooka. On ne peut pas acheter le droit d'enchaîner les éjections sur un même joueur (risque de signalement pour comportement abusif).

## 5. Risques techniques

| Risque | Mitigation |
|---|---|
| 2 500 modèles de blé côté client | Instancier une seule fois, puis jouer sur `Transparency` / `CFrame` au lieu de `Destroy` / `Clone`. Utiliser `BulkMoveTo` et un pool de briques volantes. |
| Triche (téléportation, coupe à distance) | Le serveur vérifie la distance à `HumanoidRootPart`, plus une tolérance liée au ping, le rayon de l'outil, une limite de fréquence (token bucket) et la vitesse maximale. |
| Duplication d'objets | Verrou de session (`UpdateAsync` + `LockId` + date d'expiration), sauvegarde au `BindToClose` et toutes les 60 s. |
| Physique PvP qui varie selon le ping | Les collisions sont détectées **côté serveur** (vérification de proximité à 10 Hz entre véhicules), puis l'impulsion est appliquée par le serveur. |
| Inflation de l'économie | La progression est simulée dans un test (`tests/integration/economy_curve`) qui vérifie les temps visés pour atteindre chaque palier. |

## 6. Hors périmètre / prérequis côté utilisateur

- Création des Gamepasses et DevProducts sur le Creator Hub. Leurs ID seront à renseigner dans `MonetizationConfig`.
- Publication de l'expérience et activation de l'accès aux API Studio (DataStore).
- Fichiers audio et décalcomanies : on utilise des assets libres du Creator Store, et leurs ID sont centralisés dans `AssetIds`.
