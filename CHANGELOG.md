# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Une entrée par sprint.

## Fiche Roblox

### Ajouté
- `docs/FICHE_ROBLOX.md` : nom et description en 18 langues, réponses au questionnaire de maturité, brief des
  miniatures et de la vidéo, textes d'événement, liste de ce qu'il manque avant et après le lancement.

### Corrigé
- `docs/PUBLICATION.md` : le Starter Pack relève bien des éléments aléatoires payants, car ses 10 000 $ paient des œufs.

## Classements, tête du joueur et lisibilité (A58)

### Ajouté
- **Cinq tableaux de scores** le long du boulevard, lisibles des deux côtés : plus haut niveau, plus riches, mécènes
  Robux, rois de la récolte et du pare-chocs. Top 10 avec portrait, global (ou du serveur sans DataStore).
- Colonnes **Niveau, Argent et Rebirths** dans le menu des joueurs.
- **Tête du joueur** en grand au-dessus de sa grange, avec son nom.
- Suivi des Robux dépensés dans le profil.

### Modifié
- Panneau de test : +10 M $ remplace +100 K $.

### Corrigé
- Panneaux des machines masqués par la machine elle-même : ils passent devant, avec un contour de texte plus fin.
- Contour des boutons d'œufs qui scintillait avec les dalles du couvoir.

## Couvoir et lumières (A57)

### Ajouté
- **Couvoir** : terrasse dallée le long de la clôture sud, haie et enseigne ; les œufs s'y alignent, dans des caisses
  de paille, chacun derrière son bouton.
- Panneau de test : bouton +100 K $, en plus de +10 K $.

### Modifié
- Lumières de la ferme moins fortes et moins étendues, néons assombris, bloom réduit : plus rien n'éblouit.
- Potager avancé pour laisser la place au couvoir.

## Grande ferme Lego et sac à places (A55, A56)

### Ajouté
- **Plan de construction** de 34 éléments, révélés un par un : on part d'un terrain d'herbe et on bâtit une grange
  (plancher, murs, façade, portes, fenêtres, lanternes), on aménage la cour (fleurs, lampadaires, banc, foin, pommiers,
  potager, puits, citrouilles, fontaine, charrette, épouvantail, enclos à cochons), puis l'étage et le toit, et enfin
  le prestige (clocheton, drapeau, poulailler, ruches, serre, statue, arche, éolienne).
- **Deuxième étage** : escalier, plancher, murs et toit ouvrent une chaîne de 3 nouvelles machines (Séchoir ×1,5,
  Presse ×2, Emballeuse ×3).
- Murs en rangées de briques en quinconce avec soubassement en pierre et chaînage d'angle, toit à la Mansart en gradins
  à tenons, fenêtres à croisillons, portes à croix de Saint-André.
- Le toit s'efface quand on entre dans la grange ; les flèches passent par la porte et l'escalier.
- Le HUD explique quand un blé ne tient pas dans le sac.

### Modifié
- **Un blé prend autant de places qu'il vaut** : 1, 25 ou 250. La rareté et les événements ne prennent pas de place.
- Les boutons n'existent que le temps où ils sont utiles : une poignée à l'écran, qui tombent du ciel à leur apparition.
- Les machines se débloquent dans l'ordre ; le bouton Rebirth n'apparaît qu'une fois l'usine complète ; le Silo Géant
  après le Moulin ; les œufs de Ferme et de Rebirth avec la progression.
- Base en herbe, silo et tapis repositionnés derrière la grange. Les zones au sol et panneaux d'A53 disparaissent.

## Boulevard vers le champ et engin réservé au champ (A54)

### Ajouté
- Boulevard de 30 studs le long des bases : asphalte, ligne centrale, bordures de course, néons, drapeaux et
  arches « VERS LE CHAMP ». On y court ×3, ponts compris, avec une caméra qui s'élargit.

### Modifié
- L'engin n'apparaît qu'en entrant dans le champ ; il disparaît au retour, une fois le pont retraversé.
- Ponts face aux 4 bases centrales, élargis de 14 à 22 studs ; bases reculées de 30 studs.
- Flèches de guidage : passent par la porte de la base au lieu de traverser la clôture.
- Panneau de test décalé à droite des boutons du HUD, qu'il chevauchait.

### Corrigé
- Le premier joueur recevait la base la plus éloignée du champ : les bases sont attribuées du centre vers
  les bords.

## Usine — plus d'options, boutons et flèches de guidage (A53)

### Corrigé
- La fontaine scintillait : l'eau était au même niveau que le dessus du bassin.

### Ajouté
- **Silo Géant** : 4 agrandissements (capacité ×2 chacun), le silo grandit aussi en hauteur.
- **7 décorations** à acheter : Lampadaires, Parterres Fleuris, Fontaine (jet d'eau), Drapeau Géant et Arche
  Néon au nom du joueur, Statue Dorée, Éolienne Géante (ailes animées). Conservées au Rebirth.
- **Boutons au sol** façon grands tycoons : socle, plaque et anneau néon selon l'état (vert abordable,
  rouge trop cher, violet Rebirth prêt, gris verrouillé), panneau icône + nom + prix ; un bouton épuisé
  disparaît. Panneaux assortis pour les machines et la grille de déchargement.
- **Arrivée animée** : les briques d'une machine ou d'une décoration achetée tombent du ciel en rebondissant,
  avec étincelles et son.
- **Flèches de guidage au sol** : chevrons lumineux qui défilent vers le bouton abordable le moins cher (ou
  le silo, en jaune, quand le sac est plein), en passant par les ponts ; grosse flèche au-dessus de la cible.
  Bouton ➡️ du HUD pour les activer / masquer.
- Flèches **une seule fois par objet** : un bouton déjà acheté (ou la grille déjà utilisée) n'est plus
  montré, même après reconnexion (sauvegardé).
- **Base aménagée** : dalles colorées et bordées par zone (Usine, Achats, Œufs, Jardin), allées pavées vers
  la grille, panneaux de zone, lampadaires alignés le long de l'allée, tapis à rails et rouleaux, grille de
  déchargement à cadre et barreaux, panneaux d'œufs au style des boutons (chances dans le menu 🐾).
- Profil v6 (niveau du silo, décorations, objets déjà guidés) ; tests : achats, Rebirth, sauvegarde, plan de la base sans
  chevauchement, choix de la cible et trajet des flèches.

## Menu Pets et pop-up de la roue

### Ajouté
- Menu 🐾 refait dans le style de la boutique : inventaire en grille avec chaque Pet en 3D (ViewportFrame),
  cartes aux couleurs de la rareté (Or : contour doré, Arc-en-ciel : dégradé arc-en-ciel), pastilles ×N et
  ✔ équipé, fiche détaillée avec le Pet qui tourne, Équiper / Retirer / Fusionner 5 ; onglet Œufs avec les
  chances par rareté et l'ouverture des Œufs Légendaires.
- Pop-up « GAGNÉ ! » après un tour de roue : halo de rayons, confettis, icône du lot, son ; le pointeur
  claque à chaque case.
- Bouton 🐾 du HUD au même style que 🛒 et 🎁.

### Corrigé
- Les séparateurs de la roue tournaient autour de leur propre centre (traits décentrés).

## Menu Récompenses — même style que la boutique

### Ajouté
- Menu 🎁 refait : onglets Cadeaux / Quêtes / Roue dans la fenêtre premium. Cadeaux en cartes colorées
  selon l'état (à réclamer, en attente, reçu), quêtes avec barre de progression, roue dorée à cases
  colorées, pointeur rouge et tableau des chances. Les récompenses prêtes « respirent ».
- Bouton 🎁 du HUD avec pastille « ! » et frétillement dès qu'une récompense attend.
- Modules partagés `ui/Tabs`, `ui/Grid`, `ui/HudButton` (aussi utilisés par la boutique) et
  `RewardText` (vrais noms d'objets : « Œuf Légendaire » au lieu de « LegendaryEgg »).

## Boutique — refonte visuelle

### Ajouté
- `ui/Window` : fenêtre de menu « premium » réutilisable (fond assombri, dégradé, gros contour, titre doré,
  croix rouge, ouverture qui rebondit) ; se ferme par la croix, un clic à côté ou B à la manette.
- `ui/Style` : coins, contours, dégradés, gros textes contourés et boutons « bonbon ».
- Boutique : onglets Gamepasses / Objets, grille de cartes colorées (icône flottante, badges MEILLEUR,
  POPULAIRE, ÉPIQUE, bouton d'achat vert avec icône Robux, état « POSSÉDÉ »), 2 à 4 colonnes selon l'écran,
  bouton 🛒 du HUD qui frétille.

### Corrigé
- La boutique, le menu des Pets et le menu Cadeaux se ferment enfin par une croix.

## Engins — habillage détaillé (A52)

### Ajouté
- `VehicleVisualConfig` et `VehicleLooks` : modèle en briques détaillé pour chaque engin (Tiers 3 à 7), palettes,
  livrée Turbo, pare-buffle Titan généré d'après la carrosserie.
- `VehicleVisualController` : habillage local de tous les engins, roues et rabatteurs qui tournent selon la
  vitesse, pods en lévitation, néons et gyrophares pulsants, phares (SpotLight), fumée d'échappement et
  flammes de réacteur proportionnelles à l'accélérateur, paille projetée en fauchant dans le champ, gerbe de
  briques à l'apparition.
- Tests de cohérence des modèles (roues au sol, pilote dégagé, coupe = hitbox, Turbo, Titan).

### Modifié
- Le serveur ne construit plus que la carrosserie physique (`VehicleModels` supprimé) ; le Titan ne
  reconstruit plus l'engin côté serveur.

## Sprint 8 — Monétisation, équilibrage et publication

### Ajouté
- `MonetizationService` : 5 Gamepasses (vérifiés à l'arrivée et à l'achat), 4 Developer Products,
  `ProcessReceipt` idempotent qui ne confirme qu'après une sauvegarde réussie (historique des reçus).
- Effets : Remorque Infinie, Revenus ×2, Titan (masse ×2,5, pare-buffle doré), Aimant (hitbox +35 %,
  vitesse +20 %), Triple Éclosion & Auto-Hatch ; palier effectif commun serveur/client (`Loadout`, A48).
- Bazooka (3 tirs), Météorite Dorée avec le nom de l'acheteur en géant (mise en file si un boss est
  déjà là), « Se venger ! » contextuel 6 s (A49), Starter Pack une fois par compte (A50).
- Client : boutique 🛒, bouton de vengeance, offre Starter Pack avec compte à rebours ; achats simulés dans
  Studio tant que les identifiants valent 0.
- Profil v5 (achats). Simulation d'économie et test de la courbe de progression (A51).
- `docs/EQUILIBRAGE.md` et `docs/PUBLICATION.md` (Creator Hub, identifiants, conformité).

### Modifié
- Équilibrage (A51) : tapis ×1,15 par niveau, Four 20 000 $, Usine 400 000 $.

## Sprint 7 — Rétention, HUD « Studs Pop », effets et audio

### Ajouté
- `Retention` (pur) : 9 cadeaux de temps de jeu par session, Roue de la Fortune quotidienne, 3 quêtes du jour
  identiques sur tous les serveurs, statistiques cumulées (A44 à A46).
- `RetentionService` : récompenses vérifiées côté serveur, statistiques reçues par signaux des autres services.
- `LeaderboardService` : 3 statues (Top $, Top Récolte, Roi du Pare-Chocs) avec l'avatar du premier,
  classement global par OrderedDataStore, repli local (A47).
- « Retour Base Instantané » (A19) : bouton géant dès 90 %, gratuit, 30 s de recharge, vérifié par le serveur.
- Game feel : textes flottants (+25 🌾, CRITIQUE ×10 !, ARC-EN-CIEL ×100 !!), tremblement de caméra selon la
  taille de l'outil, secousse et son à l'éjection, rebond élastique et clic sur tous les boutons, notifications.
- Menu 🎁 (cadeaux, quêtes, roue animée avec chances affichées). Sons par défaut intégrés à Roblox.
- Profil v4 (rétention et statistiques). Tests : cadeaux, roue, quêtes, sauvegarde, placement des statues.

## Sprint 6 — Gacha Pets

### Ajouté
- `Pets` (pur) : tirage pondéré par œuf, bonus par rareté (CDC §8), variantes Or ×2 / Arc-en-ciel ×5 (A17),
  équipement (3 au plus), fusion de 5 identiques, nettoyage des données, encodage réseau.
- `PetService` : distributeurs d'œufs sur chaque base (Basique, Ferme, Rebirth) avec prix et chances,
  Œuf Légendaire ouvert depuis le menu, annonce du Secret Mythique dans le chat (A42, A43).
- Bonus des Pets sur les revenus de l'usine et sur la puissance de coupe (récolte, boss) (A1, A2).
- Client : Pets en briques qui suivent leur maître en sautillant (Or brillant, Arc-en-ciel animé), menu 🐾
  (équiper, retirer, fusionner, ouvrir, chances), animation d'éclosion.
- Profil v3 avec les Pets (migration automatique) ; `Profile.fromGame` prend une table typée.
- Tests : tirage, fusion, équipement, sauvegarde, effet sur l'usine et la coupe, validation réseau.

## Sprint 5 — Événements, boss Météorite et sabotage

### Ajouté
- Météo serveur (A10) : 4 min de beau temps puis 2 min de Pluie Dorée (×2), Tempête de Vent (véhicules
  +25 %, chocs ×1,5) ou Nuit Néon (Arc-en-ciel ×5) ; ambiance client (teinte, brume, nuit).
- Hotspot (A11) : zone ×3 qui se déplace toutes les 90 s dans le Blé Diamant, balise néon visible de loin.
- Boss Météorite (A40) : Épi Géant de Cristal de 50 000 PV toutes les 12 min au bout du champ, barre de PV,
  Top 3 récompensé (Œuf Légendaire, revenus ×3 pendant 5 min).
- Sabotage (A41) : Flaque de Boue, Gant de Boxe, Onde de Choc, Bazooka ; ciblage et ligne de vue côté
  serveur, immunité respectée ; achat en gemmes ; barre d'objets (touches 1 à 4) et messages de retour.
- `InventoryService` ; profil v2 avec inventaire (migration automatique depuis v1).
- `BumperService` expose `contestants`, `eject` et `spin` : sabotage et chocs partagent les mêmes règles.
- HUD : bandeaux météo, boss et multiplicateur. Panneau de test : boss, météo, objets.
- Tests : météo, hotspot, boss, ciblage, inventaire, combat de boss, validation réseau.

### Modifié
- Plantes détaillées par zone (blé, maïs, cristaux) avec niveau de détail (A39).

## Sprint 4 — Sauvegarde et Rebirth

### Ajouté
- `Profile` (pur) : format sauvegardé versionné ; toute donnée lue est nettoyée (types, NaN, bornes, machines
  inconnues).
- `ProfileStore` (pur) : verrou de session via UpdateAsync, expiration après 5 min, refus d'écrire sans le
  verrou, réessais avec délai doublé (A38).
- `DataService` : chargement à l'arrivée (expulsion avec message si le profil est verrouillé ailleurs),
  sauvegarde toutes les 60 s, au départ et à la fermeture du serveur ; repli en mémoire dans Studio.
- `Rebirth` (pur) et bouton Rebirth sur la base : toutes les machines + 1e6 × 3^r $, remise à zéro de
  l'argent, des machines, du tapis et du palier, +50 % de revenus, +15 % de masse PvP, 10 × (r + 1) gemmes (A37).
- HUD : Rebirths et gemmes.
- Tests : Rebirth, nettoyage du profil, verrou de session (faux DataStore), session complète et
  scénario anti-duplication.

### Corrigé (après test de la passe visuelle)
- Véhicules immobiles : force de LinearVelocity quasi nulle au montage. Force illimitée, direction lue dans
  `Humanoid.MoveDirection`, propriété réseau rendue au pilote.
- Blé : tige + épi légèrement penché ; sols en tons de terre (A36). Zones raccourcies (Blé Vert ÷ 3).

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
