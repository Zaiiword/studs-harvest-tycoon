# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Une entrée par sprint.

## Passe visuelle 1 (A35)

### Ajouté
- `Decor` (domaine pur, testé) : murs de la tige, clôtures des bases ouvertes côté champ, arbres, portiques,
  variation déterministe des brins.
- `DecorService` : murs de briques le long du champ, portiques avec le nom de chaque zone, clôtures en bois et
  enseigne « Base de … » par base, arbres Lego sur la barre, rambardes des ponts.
- Véhicules en briques par palier : roues, cabine vitrée, pare-chocs, grandes roues arrière (tracteurs),
  barre de coupe à la largeur de la hitbox (moissonneuses), néons (Cyber-Laser).
- Machines en briques : moulin à ailes, four avec cheminée, usine à deux cheminées ; toit sur le silo.
- `TycoonAnimController` : ailes de moulin qui tournent, briques qui défilent sur le tapis des usines actives.
- Post-traitement : saturation, contraste, bloom et rayons du soleil légers.

## Sprint 3 — Tycoon : silo, tapis, machines et revenu

### Ajouté
- `Tycoon` (domaine pur) : silo en $ bruts plafonné, tapis à niveaux, Moulin ×1,5 / Four ×3 / Usine ×8
  cumulés, revenu à la seconde (formule du CDC §8), autonomie du silo, achats et Garage (A33).
- `TycoonService` : usine construite sur la base (boutons au sol avec prix, grille de déchargement, silo dont
  la hauteur suit le remplissage, tapis, machines qui apparaissent à l'achat), revenu encaissé chaque seconde.
- `EconomyHudController` : trésorerie, $/s et autonomie du silo en haut de l'écran, alerte « silo vide ».
- Panneau de test Studio (paliers, +10 000 $) en remplacement de `!tier` (A34).
- Tests : usine, retrait partiel du sac, repère local de base, formatage, boucle économique, golden des prix.

### Corrigé
- Le véhicule n'apparaissait pas : la commande `!tier` passait par `Player.Chatted`, qui ne se déclenche pas
  de façon fiable avec TextChatService. Le montage du véhicule signale désormais ses échecs dans l'Output.

## Sprint 2 — Véhicules arcade et Bumper PvP

### Ajouté
- `VehicleMotion` (domaine pur) : cap qui pivote vers la direction voulue, adhérence avant forte et latérale
  faible (dérapage fluide).
- `VehicleService` : carrosserie par palier (3 à 7) soudée au personnage, LinearVelocity + AlignOrientation,
  surveillance de la vitesse. `VehicleController` : pilotage client relatif à la caméra (PC, mobile, manette).
- `Bumper` (domaine pur) et `BumperService` : détection des chocs à 10 Hz, éjection selon la formule de
  masse du CDC §5, tournis de 0,8 s, bulle d'immunité de 15 s, zones sécurisées (A29 à A31).
- `DevCommandsService` : `!tier N` dans le chat, uniquement dans Studio.
- Tests : conduite, détection des chocs, golden des vitesses d'éjection.

### Modifié
- Carte en T à grande échelle (tige de 3 000 studs) et affichage du champ par chunks avec un budget
  de 2 500 brins côté client (A21, A32).

## Sprint 1 — Récolte, grille serveur et sac à dos

### Modifié après le premier test en Studio
- Carte en T (A21) : 8 bases sur la barre, fossé + 4 ponts, champ en tige de 880 studs qui se rétrécit,
  rareté croissante en s'éloignant des bases. Grille 110×30 de 8 studs (2 378 brins), brins plus gros.
- Sols colorés et contrastés avec le blé ; suppression automatique de la Baseplate grise du modèle Studio.
- Plan d'eau sous toute la carte : tomber renvoie à sa base.

### Ajouté
- `FieldGrid` (domaine pur) : grille 50×50 (1 898 brins actifs ≤ 2 500), PV par anneau, repousse à 8 s,
  tirage de rareté Géant (1/100, ×10 valeur, ×3 PV) et Arc-en-ciel (1/1 000, ×100), boîte de coupe devant l'outil.
- `Bag` : capacité par palier, paliers visuels de 10 %, pénalité « PLEIN » (-10 % de vitesse).
- `FieldService` : champ autoritaire, lots binaires (`FieldCodec`, 4 octets par événement) toutes les 0,2 s,
  état initial à la connexion (1 octet par cellule, limité en fréquence).
- `HarvestService` : récolte serveur toutes les 0,15 s sans requête client, sac visible sur le dos qui grandit,
  déchargement sur sa base vers un silo provisoire.
- `PlotService` : une base et un point d'apparition par joueur. `HazardService` : sortie du fossé.
- Client : `FieldController` (brins locaux, prédiction de coupe), `HarvestController` (briques volantes en arc,
  pool + `BulkMoveTo`, son « Pop » à tonalité croissante), `BagHudController` (jauge « Studs Pop »).
- Utilitaires `Freeze` (gel profond des configs), `RateLimiter` (token bucket), `Bricks` (style Lego).
- Tests : grille, rareté, sac, codec, limiteur, intégration de la boucle de récolte, golden du champ.

### Modifié (Sprint 0 revu après relecture du CDC)
- Carte redimensionnée sur la grille du champ (A21, A24) : sol en briques alignées sur la grille, bord en escalier.
- Rendu Lego actif : surfaces Studs/Inlet partout, MaterialVariant optionnel (A25), éclairage `Brightness = 3`
  et `ColorShift_Top` doré (`RenderService`).
- `MapService` : plus de fonction à 9 paramètres, config gelée.

## Sprint 0 — Setup et carte

### Ajouté
- Outillage Rokit / Rojo / Lune / Selene / StyLua / Wally, scripts Windows, CI.
- Carte concentrique générée par code : 8 bases, 4 ponts, 3 anneaux, cœur central.
