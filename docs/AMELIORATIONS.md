# Améliorations de gameplay : vers le top 100 Roblox

Inventaire de tout ce qui peut rapprocher Studs Harvest Tycoon des jeux les plus joués de Roblox, établi après lecture
du code et parties de test dans Studio (15/11/2026).

Légende :

- ✅ **Fait** sur la branche `feat/ameliorations-top100` (décision Axx dans `ANALYSE_CDC.md`, entrée dans le `CHANGELOG`).
- ⭐ **Recommandé** : utile et sans risque, à faire ensuite.
- 🧑 **À faire par toi** : demande un accès (Creator Hub, groupe, assets) ou une décision de ta part.
- ⚖️ **À décider** : il y a du pour et du contre.
- ⛔ **Déconseillé** pour l'instant, avec la raison.

## Ce qui manquait le plus

1. **Rien n'est achetable en Robux dans le jeu publié.** Tous les identifiants de `MonetizationConfig` valent 0 :
   boutique, Starter Pack et « Se venger » ne proposent rien hors de Studio. C'est le premier point bloquant pour un jeu
   du top 100. 🧑 Créer les 5 Gamepasses et les 4 produits sur le Creator Hub (ou me le demander : je peux les créer
   par l'API Open Cloud si tu me donnes le feu vert), puis renseigner les identifiants.
2. **Le jeu n'existe qu'en français.** Le public Roblox est surtout anglophone. Sans version anglaise, le jeu ne peut
   pas viser le top 100. ⭐ Passer les textes par une table de localisation (source anglaise, traduction française),
   ou au minimum activer la traduction automatique avec le français comme langue source.
3. **Les récompenses ne suivaient pas la progression, et rien ne faisait revenir le lendemain.** ✅ Corrigé (voir
   Rétention).
4. **Un nouveau joueur n'avait aucune flèche.** ✅ Corrigé (A67).
5. **Premier Rebirth vers 3 h de jeu.** ⚖️ Voir Progression.

## 1. Premières minutes (onboarding)

| Idée | État | Détail |
|---|---|---|
| Flèches au sol vers l'achat abordable et le silo | ✅ existant (A53) | |
| Flèches vers le champ pour un joueur qui n'a jamais déchargé | ✅ A67 | Sans elles, un joueur à 0 $ n'avait aucune indication. |
| Barre « objectif suivant » sous la trésorerie | ✅ A59 | Le prochain grand achat (Garage, machine ou Rebirth) et l'argent réuni. |
| Calendrier de connexion ouvert seul à l'arrivée | ✅ A61 | Une fois par session, quand la récompense attend. |
| Apparition tournée vers le champ | ✅ A67 | Le joueur apparaissait face au couvoir, le champ sur le côté. |
| Texte d'accueil de 3 s (« Coupe le blé, rapporte-le au silo ») | ⭐ | Une ligne en surimpression la première fois, en plus des flèches. |
| Mesurer l'entonnoir (AnalyticsService) | ⭐ | `LogOnboardingFunnelStepEvent` : premier blé, premier déchargement, premier achat, Faux, Tondeuse. Sans mesure, on règle à l'aveugle. |
| Tutoriel bloquant en plusieurs étapes | ⛔ | Les joueurs Roblox quittent les tutoriels imposés ; les flèches font le travail sans bloquer. |

## 2. Boucle de récolte

| Idée | État | Détail |
|---|---|---|
| Récolte automatique, briques volantes, son à hauteur croissante, Géant / Arc-en-ciel | ✅ existant | La boucle de base est bonne. |
| Retour base instantané à 90 % | ✅ existant (A19) | |
| Amélioration « Sac XXL » en gemmes | ✅ A65 | +10 % de places par niveau. |
| Combo de récolte (multiplicateur qui monte si on coupe sans s'arrêter) | ⚖️ | Bon game feel, mais il faut l'équilibrer avec le sac à places (A55). |
| Vendre n'importe où (sans retour au silo) | ⛔ | Casse la boucle silo → usine et l'embuscade au retour (CDC §3). |
| Gamepass « Auto-récolte » (le personnage récolte seul) | ⛔ | Contraire au cœur du jeu (on conduit sa machine) ; les gains hors ligne couvrent déjà le besoin d'idle. |

## 3. Progression et économie

| Idée | État | Détail |
|---|---|---|
| Gains hors ligne de l'usine | ✅ A60 | Le silo continue d'être vidé 12 h au plus ; pop-up « Bon retour ! ». |
| Améliorations permanentes en gemmes (sac, coupe, revenus) | ✅ A65 | Donne enfin un usage aux gemmes ; conservées au Rebirth. |
| Succès permanents payés en gemmes | ✅ A64 | 7 familles, 3 à 5 paliers. |
| Premier Rebirth plus tôt | ⚖️ | Aujourd'hui vers 3 h (A51). Les simulateurs du top proposent le premier prestige en 20 à 45 min, puis allongent. Mon avis : c'est trop long pour des sessions Roblox de 20-30 min. Mais cela demande de toucher aux prix des paliers du CDC (§5). À trancher. |
| Boutique du Rebirth (jetons de Rebirth → bonus permanents) | ⭐ | Prolonge le prestige ; les gemmes du Rebirth vont aujourd'hui dans les améliorations A65. |
| Nouvelles zones de champ débloquées au Rebirth (vergers, citrouilles, champ de cristal) | ⭐ | Le plus gros levier de contenu après le premier Rebirth ; la carte en T s'y prête (prolonger la tige). |
| Potions de boost (×2 argent 10 min, ×2 chance) | ⭐ | Récompense des quêtes, de la roue, et produit Robux. |
| Statistique de chance (Géant, Arc-en-ciel) | ⚖️ | La rareté est tirée à la repousse, pour tout le serveur : une chance par joueur demande de la tirer à la coupe. |

## 4. Rétention

| Idée | État | Détail |
|---|---|---|
| Cadeaux de temps de jeu, roue quotidienne, quêtes du jour | ✅ existant | |
| Récompenses en argent indexées sur le revenu | ✅ A59 | 1 à 10 minutes d'usine à plein régime. |
| Calendrier de connexion sur 7 jours | ✅ A61 | Œuf Légendaire au jour 7, série remise à zéro si on manque un jour. |
| Codes (réseaux sociaux, mises à jour) | ✅ A62 | BIENVENUE, LEGO, MOISSON ; une ligne dans `RetentionConfig.CODES` pour en ajouter. |
| Quêtes de la semaine | ⭐ | Objectifs plus longs, meilleure récompense (œuf, potion). |
| Notification « ton silo est vide » (Roblox Experience Notifications) | ⭐ | Fait revenir le joueur quand son usine s'arrête ; demande l'activation sur le Creator Hub. |
| Événements de week-end (×2 argent, chance) | ⭐ | Annoncés à l'avance ; se pilotent avec un drapeau de config. |
| Pass saisonnier (piste gratuite + piste Robux) | ⚖️ | Très rentable dans le top 100, mais beaucoup de contenu à produire à chaque saison. |

## 5. Pets (collection)

| Idée | État | Détail |
|---|---|---|
| 11 espèces au lieu de 5 | ✅ A66 | Cochonnet, Lapin, Mouton, Abeille, Licorne, Golem. |
| Index de collection qui rapporte des gemmes | ✅ A66 | 33 entrées, silhouettes noires pour celles qui manquent. |
| Bouton « Équiper les meilleurs » | ✅ A66 | |
| Plus d'espèces, propres à chaque œuf | ⭐ | Aujourd'hui les espèces sont partagées entre œufs, par rareté. Un œuf = un thème (ferme, prairie, cristal) donne envie d'ouvrir chacun. |
| Suppression automatique d'une rareté à l'éclosion | ⭐ | Indispensable quand on ouvre beaucoup d'œufs (Auto-Hatch). |
| Niveaux des Pets (XP en récoltant) | ⚖️ | Attachement aux Pets ; ajoute un calcul de bonus à équilibrer. |
| Pets géants / « Huge » ultra-rares | ⭐ | Énorme moteur de partage (« j'ai eu un Huge ! ») ; annonce serveur déjà en place (A43). |
| Échange de Pets entre joueurs | ⛔ | Pour l'instant : risques d'arnaque et de duplication, modération à prévoir. À revoir avec une vraie communauté. |

## 6. Social et multijoueur

| Idée | État | Détail |
|---|---|---|
| +10 % de revenus par ami présent (4 au plus), +10 % Premium | ✅ A63 | Pastille « 👥 Inviter » qui ouvre l'invitation Roblox. |
| Classements globaux et statues | ✅ existant (A47, A58) | |
| Récompense de groupe (rejoindre le groupe → coffre ou +10 %) | 🧑 | Demande l'identifiant de ton groupe Roblox. Gros levier de communauté. |
| Rappel « Mets le jeu en favori / like » après 10 min | ⭐ | Le nombre de favoris pèse dans la recommandation Roblox. |
| Étiquettes de chat (VIP, niveau) | ⭐ | Visibles de tous, poussent au Gamepass VIP. |
| Champ coopératif contre le boss (récompense de serveur) | ✅ existant (Top 3) | Une petite récompense pour **tous** les participants motiverait davantage. ⭐ |
| Clans | ⚖️ | Fort pour la rétention à long terme, lourd à construire. |

## 7. PvP et sabotage

| Idée | État | Détail |
|---|---|---|
| Bousculade, objets de sabotage, immunité, zones sûres | ✅ existant | |
| Option « paix » pour les débutants (pas d'éjection avant le Tracteur) | ⚖️ | Le Blé Vert est déjà une zone sûre (A29). À surveiller : un nouveau joueur éjecté dans le Maïs peut partir. |
| Bazooka et vengeance en Robux | ✅ existant, 🧑 identifiants | Inactifs tant que les produits n'existent pas. |

## 8. Monétisation

| Idée | État | Détail |
|---|---|---|
| 5 Gamepasses, 4 produits, Starter Pack | ✅ code, 🧑 identifiants à 0 | Rien ne se vend en ligne aujourd'hui (voir en haut). |
| Gamepass VIP (+20 % de revenus, étiquette de chat, porte VIP) | ⭐ | Le Gamepass le plus vendu des simulateurs. |
| Potions et œufs en Robux (avec chances affichées) | ⭐ | Respecter `PolicyService` (pays où les objets aléatoires payants sont interdits). |
| Offrir un Gamepass à un ami | ⭐ | |
| Serveurs privés (prix bas) | 🧑 | Un réglage du Creator Hub. |
| Récompense Premium (Premium Payouts) | ✅ A63 | +10 % de revenus pour les abonnés Premium. |

## 9. Interface, mobile et confort

| Idée | État | Détail |
|---|---|---|
| Boutique, menus Pets et Récompenses au style des grands jeux | ✅ existant | |
| Onglets Succès, Codes, Connexion, Gemmes, Index | ✅ A61 à A66 | |
| Vérifier tout le HUD sur téléphone | ⭐ | La colonne de gauche empile 4 gros boutons (jusqu'à 340 px) : limite sur un petit écran en paysage. |
| Menu Réglages (sons, musique, qualité du champ) | ⭐ | |
| Musique d'ambiance | ⭐ | Il n'y a aucune musique. Des pistes libres existent dans le Creator Store. |
| Panneau de test Studio | ✅ existant | Masqué hors de Studio. |

## 10. Contenu vivant et visuel

| Idée | État | Détail |
|---|---|---|
| Météo, hotspot, boss Météorite | ✅ existant | |
| Événements saisonniers (Halloween : citrouilles, Noël : neige) | ⭐ | Mises à jour régulières = remontée dans l'algorithme. |
| Cosmétiques d'engins (peintures, traînées) | ⭐ | Bon produit Robux sans effet sur l'équilibre. |
| Badges | 🧑 | Aucun badge : à créer sur le Creator Hub (premier blé, Tracteur, Rebirth, Mythique…). |
| Icône et miniatures du jeu | 🧑 | Décisives pour le taux de clic dans les recommandations. |

## 11. Technique

| Idée | État | Détail |
|---|---|---|
| Tests Lune (unitaires, intégration, non-régression) | ✅ | 345 avant cette passe, 399 après. |
| Mesures de jeu (AnalyticsService : entonnoir, économie) | ⭐ | Pour juger les changements sur le temps passé en jeu, pas à l'intuition. |
| Test de charge à 8 joueurs | ⭐ | Studio, Test → 8 joueurs : vérifier le champ, les Pets et les chocs. |

## Ce qui a été fait dans cette passe

| Décision | Changement |
|---|---|
| A59 | Récompenses indexées sur le revenu, barre d'objectif |
| A60 | Gains hors ligne de l'usine, pop-up « Bon retour ! » |
| A61 | Calendrier de connexion sur 7 jours |
| A62 | Codes |
| A63 | Bonus des amis et de Premium, bouton d'invitation |
| A64 | Succès permanents |
| A65 | Améliorations en gemmes |
| A66 | 6 nouvelles espèces de Pets, index, « Équiper les meilleurs » |
| A67 | Flèches vers le champ pour les débutants |

Profil sauvegardé : v6 → v9 (migration automatique, aucun profil existant n'est perdu).
