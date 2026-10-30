# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Une entrée par sprint.

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
