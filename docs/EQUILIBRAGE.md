# Équilibrage de l'économie (décision A51)

## Méthode

`tests/helpers/EconomySim.luau` simule un joueur **seul, appliqué, sans Pet ni avantage Robux**.

À chaque trajet, le joueur :

1. récolte la zone la plus rentable qu'il peut couper ;
2. rentre décharger au silo ;
3. laisse tourner l'usine ;
4. achète dans cet ordre : le Garage dès que possible, sinon une machine, sinon un niveau de tapis (seulement si le tapis ne suit plus la récolte).

Le modèle est volontairement simple. Il sert à repérer les dérives de prix, pas à prédire le temps de jeu à la seconde près.

`tests/regression/EconomyCurve.spec.luau` fige les fourchettes ci-dessous. Tout réglage qui en sort fait échouer la CI, ce qui oblige à le rendre intentionnel.

## Résultats

| Étape | Avant réglage | Après réglage | Cible |
|---|---|---|---|
| Faux (T2, 150 $) | 4,7 min | 4,7 min | < 6 min (CDC §8 « effet dopamine ») |
| Tondeuse (T3, 1 200 $) | 12,3 min | 12,3 min | 10-15 min |
| Tracteur (T4, 12 500 $) | 30,5 min | 51,7 min | 40-60 min |
| Double Faucheuse (T5, 85 000 $) | 43,8 min | 1 h 47 | 1 h 30 - 2 h |
| Moissonneuse XL (T6, 450 000 $) | 48,8 min | 2 h 42 | 2 h 30 - 3 h |
| 1er Rebirth possible (1 M $) | 57,4 min | 2 h 48 | 2 h 30 - 3 h |
| Cyber-Laser (T7, 3,5 M $) | 1 h 03 | 3 h 02 | ~3 h |

Avant le réglage, l'Usine ×8, vendue à 40 000 $, et un tapis dont le débit grimpait trop vite (×1,5 par niveau) faisaient passer de T4 à T7 en une demi-heure.

## Réglages

Les prix des paliers sont fixés par le CDC (§5) et n'ont pas été modifiés. Seules mes propres décisions ont bougé :

| Paramètre | Avant | Après | Fichier |
|---|---|---|---|
| Débit du tapis par niveau | ×1,5 | ×1,15 | `TycoonConfig.CONVEYOR.RATE_GROWTH` |
| Four à Pain | 2 500 $ | 20 000 $ | `TycoonConfig.MACHINES` |
| Usine de Céréales Dorées | 40 000 $ | 400 000 $ | `TycoonConfig.MACHINES` |

Le prix du tapis suit toujours `50 × 1,35^n` (CDC §8). Avec un débit qui ne croît que de 15 % par niveau, le tapis devient le principal « puits » d'argent de la fin de partie.

## À surveiller en jeu

Ces points ne sont pas modélisés par la simulation :

- **Les Pets** multiplient les revenus et la coupe. Un Dragon Doré équipé donne ×5, trois Dragons Arc-en-ciel donnent ×61. Ils accélèrent beaucoup la progression : à mesurer avec de vrais joueurs.
- **Les Rebirths** donnent +50 % de revenus chacun. Le second Rebirth coûte 3 M $, le troisième 9 M $.
- **Les événements** : Pluie Dorée ×2, hotspot ×3, récompense du boss ×3.
- **Les Gamepasses** : Revenus ×2, Remorque Infinie.

Pour accélérer ou ralentir le jeu, les leviers les plus sûrs sont `RATE_GROWTH`, puis le prix des machines.
