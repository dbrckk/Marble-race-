# MARBLE RACE — PROMPT DIRECTEUR AAA PREMIUM ANDROID
Version du plan : 2026-11-16
Dépôt : dbrckk/Marble-race-
Branche de travail actuelle : woodworks-race-flow (PR #1)
Base observée : 1.68.0-rc, Godot 4.5.1 GL Compatibility, 40 billes physiques, 3 univers × 3 variantes.
Statut : plan d'exécution, pas attestation de qualité AAA.

## PROMPT À EXÉCUTER À CHAQUE « CONTINUE » / « GO »

Tu es responsable technique, game designer, technical artist, expert optimisation Android, QA et ingénieur réseau de Marble Race. Ta mission est de livrer un jeu de course de billes Android à finition commerciale premium, spectaculaire, amusant, accessible, robuste et réellement jouable. Ne produis pas de prototype isolé : modifie les parcours existants, vérifie les résultats et termine un lot cohérent avant de passer au suivant.

### Préparation obligatoire
1. Vérifie le dépôt réel, sa branche, sa PR, ses derniers commits, les changements locaux, les workflows et les problèmes ouverts. Ne travaille jamais sur une branche supposée. Respecte les changements non committés et le workflow de la PR #1.
2. Relis README.md, docs/ROADMAP_PREMIUM_PLAY_STORE_2026-10-27.md, docs/ANDROID_PERFORMANCE.md, docs/15_GAMEPLAY_PILLARS.md, docs/STAR_LIST_GAME_REVIEW.md et les tests concernés.
3. Établis une baseline reproductible : screenshots par biome, parcours tactile, taux d'achèvement des courses, collisions, frametime et budget draw calls. Sépare mesures réelles Android et mesures headless.
4. Priorité absolue aux régressions bloquant le lancement, les courses, les contrôles, la progression, le réseau ou l'export. Corrige-les avant toute nouvelle décoration.
5. Préfère Godot natif et ressources libres vérifiées. Le catalogue star-list est une source d'idées, jamais une licence d'utilisation implicite.

## TOP 5 — ordre d'exécution

### P1 — Direction artistique 3D cohérente et exceptionnelle
- Auditer tous les éléments visibles : pistes, rails, ponts, obstacles, silhouettes, ciel, fonds, billes, matériaux, lumières, VFX, UI et caméra. Classer les primitives non justifiées et les éléments trop répétitifs.
- Construire une bible visuelle par univers : Woodworks (atelier mécanique chaleureux et bois travaillé), Glacier (glace translucide, givre et contraste lisible), Forge (acier, braises, machines, chaleur). Préserver une identité colorimétrique propre à chaque monde.
- Remplacer progressivement les formes génériques visibles par géométrie soignée, silhouettes originales, détails de matériaux et décors crédibles. Employer MultiMesh, LOD, atlases, pooling et shaders compatibles GL Compatibility; préserver les colliders exacts et la visibilité des dangers.
- Ajouter éclairage directionnel maîtrisé, ambiance, contacts, particules contextuelles, caméra et transitions, sans masquer les trajectoires.
- Acceptation : captures comparables avant/après sur les 9 variantes, à vitesse de course et en 40 billes; aucun obstacle masqué, aucune régression physique, vérification des droits d'assets, budget GPU respecté sur appareil réel.

### P2 — Gameplay arcade de course mémorable
- Améliorer le plaisir des 30 premières secondes : départ immédiatement compréhensible, accélération, pilotage tactile, turbo, premier objet rare et premier obstacle clairement annoncés.
- Chaque biome doit proposer au moins une décision physique distinctive : trajectoire sûre/rapide, saut ou raccourci à risque, obstacle temporisé avec contre-jeu, interaction lisible à pleine vitesse.
- Revoir les enchaînements glace/volet, pont/retour, piston/évent et les collisions de peloton; pas de passages arbitrairement bloqués.
- Raffiner les objets rares immédiats réservés aux vrais joueurs : effets différenciés, utiles mais non décisifs, lisibles et validés par le serveur. Les skins restent cosmétiques.
- Acceptation : parcours réel sur 9 variantes, 40 billes, collisions et trajectoires reproductibles, aucun blocage permanent, commandes tactiles testées, championnats complets et aucune récompense injuste.

### P3 — IA crédible et multijoueur robuste
- Étendre les comportements existants : freinage en file, anticipation d'un joueur qui se rabat, annulation et reprise de dépassement, prise de risque contextuelle et réaction aux portes temporisées.
- Tester en priorité Glacier avec joueur distant se rabattant à la sortie du pont, sous 0/80/150/250 ms de latence simulée, jitter et pertes raisonnables. Consigner collisions, délais de réaction, positions serveur/client et cas limites.
- Garder physique et objets rares sous autorité serveur; valider fraîcheur des commandes, anti-rejeu, limites de vitesse et absence d'avantage client.
- Améliorer la gestion des déconnexions et reconnexions sans promettre des salons multiples tant qu'ils ne sont pas implémentés et testés.
- Acceptation : scénarios multi-clients réels, serveur dédié, courses terminées sans blocage ni triche, métriques de collisions et latence documentées. Les bots restent identifiés honnêtement comme bots.

### P4 — Performance Android mesurée et adaptive
- Conserver 40 RigidBody3D et 60 Hz physique sauf décision explicitement motivée par mesures.
- Mesurer FPS, p95 et p99 frametime, coût physique, draw calls, mémoire, température et batterie sur sessions de 15 min, départs à 40 billes, Glacier/Forge et profils graphiques. Cible : 60 FPS stables sur appareil de référence quand possible, 30 FPS réguliers sur appareils modestes, sans garantie avant mesure.
- Prioriser les gains sans impact gameplay : instancing, culling, LOD, pooling audio/VFX, plafonds particules, ombres et shaders, suppression des allocations répétées.
- Implémenter adaptation de qualité avec hystérésis et plafonds explicites; ne jamais réduire la précision des collisions, la lisibilité du HUD ni modifier l'équité réseau pour gagner des FPS.
- Acceptation : tableau avant/après issu d'appareils physiques, pas seulement CI; aucun stutter majeur introduit, aucune fuite mémoire, thermique et batterie documentées.

### P5 — Finition produit et sortie Google Play
- Uniformiser HUD, menus, tutoriel, pause, résultats, progression, objectifs, retours haptiques, accessibilité, lisibilité et navigation tactile sur ratios Android courants.
- Réaliser une identité sonore originale par univers, mixage adaptatif et priorité aux signaux de danger; vérifier le rendu sur haut-parleur de téléphone et écouteurs.
- Protéger la sauvegarde et la migration de carrière, les meilleurs temps et les déblocages. Tester installation, mise à jour, reprise après mise en arrière-plan et retour hors ligne.
- Finaliser un AAB release réellement signé, les métadonnées Play, la confidentialité et le consentement, les SDK AdMob/Billing réels, la vérification des achats côté serveur, les remboursements et l'expiration des skins temporaires. Pas de faux paiement ni de publicité simulée en production.
- Acceptation : parcours neuf utilisateur -> première course -> résultats -> deuxième course -> reprise, APK/AAB vérifiés, aucun secret dans Git, transactions testées en environnement Play autorisé. Ne pas annoncer une publication sans preuve.

## MÉTHODE D'EXÉCUTION ET LIVRABLES
- Choisir le lot ayant le meilleur impact joueur et le risque le plus faible, dans l'ordre fiabilité > jouabilité > sécurité > architecture > performances > visuel > extras; si P1 ne peut être testé sans P4, mettre d'abord en place les mesures minimales.
- Pour chaque lot : problème et preuve initiale -> cause racine -> fichiers modifiés -> implémentation réelle -> tests ciblés -> régression 9 tracés/40 billes si pertinent -> lint/import Godot -> build Android -> comparaison visuelle/performance -> commit sur la branche autorisée -> vérification du workflow.
- Ne jamais prétendre avoir testé sur Redmi sans appareil ni inventer de score FPS, de résultat CI ou d'APK. Distinguer systématiquement « validé en CI », « testé sur appareil » et « à confirmer ».
- Pas de TODO, mock ou placeholder présenté comme fonctionnel. Préserver les règles physiques, l'autorité réseau, la compatibilité de sauvegarde et les mécanismes de monétisation.
- Mettre à jour ce document à chaque lot avec : date, SHA, tests, captures, métriques, décisions, blocages, et la prochaine action unique. Ne pas effacer l'historique des validations.
- Ne publier sur Google Play qu'après validation explicite de tous les prérequis commerciaux et techniques.

## JOURNAL DES LOTS

### 2026-11-16 — Garde-corps des trois univers (1.69.0-rc)

Base de comparaison GitHub `3546ac930e24d66d631d60a7d6674ec51b4c7fca`, résultat dans le commit qui introduit cette entrée.

| Univers | Variantes observées | Garde-corps | Finition livrée | Structures restantes visibles en course |
| --- | --- | --- | --- | --- |
| Woodworks | 0, 1, 2 | 106 par tracé | Bois mouluré, gorge et couronne laiton | Arche de départ, montants d’atelier, socles des décors |
| Glacier | 0, 1, 2 | 105 par tracé | Arêtes de glace, face cyan et givre | Arche de départ, piliers du fond, transition pont/piste |
| Forge | 0, 1, 2 | 106 par tracé | Acier en retrait et rebord cuivre | Arche de départ, parois d’atelier, supports des mécanismes |

- Comparaison sur trois positions de la caméra de course par variante, avec 40 billes positionnées en peloton, profil Équilibré, 82 km/h affichés et trois instants reproductibles de la course. [Comparatif des trois univers](screenshots/v1.69-guardrails.jpg).
- Un lot de dessin pour la famille des garde-corps, contre six lots matériau et un lot de liseré. Le profil passe de 108 à 60 triangles par élément. Les ouvertures et les transformations des colliders correspondent sur les neuf tracés.
- Sur 27 paires de vues OpenGL Compatibility avec Mesa llvmpipe, médianes de six appels de dessin et 5 520 primitives affichées en moins par image. Ces vues statiques décrivent le coût géométrique. Le temps d’image, la stabilité thermique et la lisibilité en mouvement restent à mesurer sur un Android physique.
- Import Godot 4.6.3, vérifications de tracés, de contrôles tactiles, de rendu, de raccourcis et de qualité graphique validés localement. La simulation existante a mesuré 38, 39 et 36 arrivées sur 40 sur les trois parcours sans pilotage humain. Le workflow GitHub vérifie le build Android avec Godot 4.5.1.

### 2026-11-16 — Départ dégagé et feux synchronisés (1.70.0-rc)

Base de comparaison GitHub `ab10cbd7f3305c14fed26602155e49ff34cd6218`, résultat dans le commit qui introduit cette entrée.

- Deux montants latéraux libèrent la vue sur les premiers obstacles. Bois et laiton à Woodworks, glace facettée à Glacier, acier nervuré et cuivre à Forge. Le signal utilise une surface pour la paire de montants et une instance groupée de six feux, sans ombres supplémentaires ni colliders.
- Le HUD affiche la préparation, 3, 2, 1 et le départ sous l’indicateur de vitesse. Les feux changent avec ce même compte à rebours et s’éteignent après le lancement. Les essais automatisés couvrent les neuf tracés, 40 billes, le déverrouillage des corps et la remise à zéro.
- 27 paires de vues OpenGL Compatibility avec Mesa llvmpipe, du compte à rebours au début du roulage. Médiane de 11 appels de dessin et 634 primitives affichées en moins par image pour la scène entière. [Comparatif des trois départs](screenshots/v1.70-start-gates.jpg).
- Les contrôles tactiles, la pause et la reprise, le cadrage et le HUD passent en local. Le temps d’image sur un Android physique reste à mesurer.

### 2026-11-16 — Premier passage de chaque tracé (1.71.0-rc)

Base de comparaison GitHub `b122be0826748b244a73924736797acb5d417590`, résultat dans le commit qui introduit cette entrée.

- Le premier module reçoit des coques assorties à son univers et des bandes ambre sur les obstacles et au sol. Les chevrons indiquent les ouvertures de l’entrée calculées d’après les colliders. Le cercle discontinu figure le débattement complet de la palette sur les variantes qui en comportent une.
- Une seule surface regroupe les plots, déflecteurs, blocs et marquages du premier module. Le repérage reste visible en mode Économie. Les dimensions, positions, matériaux physiques et mouvements des obstacles suivent les règles existantes.
- 27 paires de vues OpenGL Compatibility avec Mesa llvmpipe, 40 billes. La médiane est de 40 appels de dessin et 7 102 primitives affichées en moins par image. [Comparatif des trois univers](screenshots/v1.71-opening-obstacles.jpg).
- Les neuf variantes passent la vérification des ouvertures et du débattement. Contrôles tactiles, caméra, avertissements de danger et import Godot vérifiés localement. Lisibilité et temps d’image restent à mesurer en jeu sur Android physique.

### 2026-11-16 — Première bifurcation lisible à pleine vitesse (1.72.0-rc)

Base de comparaison GitHub `2485953106a494e6fc5d8c51f1c47de4a7e8aa9c`, résultat dans le commit qui introduit cette entrée.

- Le premier toit de Woodworks et de Glacier devient latéral. Les balises de secteur passent sur les bords au plan de chronométrage. Les comparaisons à 86 km/h montrent le pont dans la vue de poursuite jusqu’à l’ouverture. [Comparatif des trois circuits](screenshots/v1.72-first-fork.jpg).
- Dix flèches près de la bifurcation. Menthe pour la piste et ambre pour le pont, avec deux repères alignés sur son tablier incliné. Le HUD signale le côté, la distance, le temps à vitesse de course puis le moment de bifurquer. Une bille encore sur l’accotement conserve le contexte de la piste.
- 27 paires de captures à 40 billes en OpenGL Compatibility avec Mesa llvmpipe. Écart médian par circuit de −14 appels de dessin à Woodworks, −15 à Glacier et +6 à Forge. Temps d’image et facilité de lecture à confirmer sur Android physique.
- Tests Godot sur les neuf tracés, avec visée de la caméra, vrai tablier, signal au HUD, choix du côté et conservation des récompenses sous autorité serveur.

### 2026-11-16 — Retour des ponts et volet de Glacier (1.73.0-rc)

Base de comparaison GitHub `5d03f34d911ee0720511db27c2be18c394367d45`, résultat dans le commit qui introduit cette entrée.

- Les sorties utilisent un panneau et des flèches alignées sur le tablier. À Woodworks, le deuxième passage libère la vue du peloton et le guidage reste présent sur la lèvre. La règle du franchissement du pont et les colliders conservent leurs paramètres.
- À Glacier, une seule alerte indique la rentrée à droite, le corridor central et le côté du volet à l’approche. Au retour sur piste, le HUD reprend la prévision de collision et le son reste disponible pour le danger réel.
- 36 paires de vues à 86 km/h avec 40 billes en OpenGL Compatibility. Écart médian des appels de rendu de −1,5 à Woodworks, −4 à Glacier, 0 à Forge. [Comparatif des sorties](screenshots/v1.73-bridge-returns.jpg). Le temps d’image sur Android physique reste à mesurer.
- Régressions Godot sur neuf tracés et vérification du relais entre l’alerte de rentrée et le volet physique. Tests de caméra, commandes, récompenses de pont et collisions de peloton intégrés au workflow Android.

### 2026-11-16 — Ligne d’arrivée et chrono du franchissement (1.74.0-rc)

Base de comparaison GitHub `86bcb22501a9b46b2611b012aa41855c7c1ba777`, résultat dans le commit qui introduit cette entrée.

- L’arrivée reçoit un damier à deux rangées aligné sur le plan de la piste et deux balises latérales propres à l’univers. Le dernier passage de Woodworks et de Glacier libère la vue sur la ligne. Les panneaux de secteur suivent le plan de chronométrage.
- Les résultats affichent le temps enregistré au franchissement. La revanche lance la variante suivante avec 40 billes. Le test de bout en bout vérifie le résultat affiché et enchaîne une nouvelle course avec le bouton existant.
- 27 paires de vues à 86 km/h avec 40 billes en OpenGL Compatibility. Médiane de 50 appels de rendu et 4 272 primitives affichées en moins par image. [Comparatif des trois arrivées](screenshots/v1.74-finish-line.jpg). Temps d’image sur Android physique à mesurer.

### 2026-11-16 — Dernier obstacle et sprint final (1.75.0-rc)

Base de comparaison GitHub `d4a6ddc38315e40bfe44746974d00eadc855cc23`.

- Le dernier module réunit les finitions des plots, blocs et déflecteurs dans une surface. Leurs bandes au sol suivent les colliders, et la palette conserve un cercle de débattement visible en Économie. Les obstacles conservent leurs positions, dimensions et trajectoires.
- L’alerte de conduite la plus proche prend la place centrale lorsqu’un déflecteur, la palette, le dernier obstacle temporisé, l’évent ou la plaque de glace concerne la trajectoire. Le HUD suspend les annonces secondaires. « FINAL STRAIGHT » se déclenche après le dernier virage relevé, avant le damier.
- 27 paires de vues à 86 km/h avec 40 billes en OpenGL Compatibility sur Mesa llvmpipe. Écarts médians de −44 appels de rendu et −6 986 primitives par image. [Comparatif des trois circuits](screenshots/v1.75-final-approach.jpg). Temps d’image sur Android physique à mesurer.
- Neuf simulations depuis l’entrée du secteur avec 40 billes. Le joueur termine les neuf courses et retrouve son chrono au résultat. Les nombres de billes déjà arrivées à l'ouverture des résultats et les temps du joueur correspondent à la version précédente. Les tests du HUD couvrent les neuf variantes, la priorité du danger et le retour à l’affichage normal après le passage.

### 2026-11-16 — Récupération des blocages dans le dernier secteur (1.76.0-rc)

Base de comparaison GitHub `9b27b799158c7dc42f17d6d62b487f8ce66056aa`.

- Sur la troisième variante de Glacier, les contacts physiques montrent la bille du joueur coincée devant le plot d’entrée du dernier module. Les reprises vers l’avant la renvoyaient contre la même face. Après deux reprises infructueuses dans cette zone, la récupération solo peut soulever la bille et la faire reculer brièvement vers le côté. La direction du joueur reste prioritaire dès qu’il braque au-delà du seuil de récupération. Les positions des obstacles et les règles en ligne sont conservées.
- Le test Godot 4.5.1 reproduit une entrée à 18 m/s avec 40 billes. La bille du joueur, encore bloquée au bout de 60 s avant le correctif, franchit maintenant la ligne à 19,80 s sur ce tracé. Elle termine sur les neuf variantes. Six variantes classent 40 billes et trois en classent 39 dans la fenêtre de 60 s. Certaines billes IA peuvent donc encore rester bloquées dans ce scénario.
- Le test de peloton est intégré à la vérification Android. Les mesures de temps d’image sur téléphone restent à faire.

### 2026-11-16 — Passage du dernier portique de Forge (1.77.0-rc)

Base de comparaison GitHub `6fad6efd6aa56fdf8735dead1f9724295e045a9b`.

- Sur la troisième variante de Forge, une bille IA pouvait se retrouver au contact de la bosse et du plot central, puis revenir contre ces deux colliders après chaque tentative de récupération. La bosse est déplacée après le dernier virage relevé en solo. Elle garde le même profil. Les courses réseau utilisent sa position actuelle côté serveur, y compris si une partie en ligne suit une course solo sur le même tracé.
- Dans le scénario de régression à 40 billes sur Godot 4.5.1, le blocage de 47,5 s a disparu et la plus longue absence de progression sur ce tracé est passée à 11,2 s. Sur les neuf variantes, le joueur franchit l’arrivée et chaque IA termine ou est éliminée dans les 60 s. Six variantes classent 40 billes, trois en classent 39.
- Avec un peloton lancé 14 m plus en amont, les 40 billes ont franchi l’arrivée sur la troisième variante de Forge en 26,95 s. Le même essai a révélé un blocage IA sur Woodworks et un autre sur Glacier. Les vues OpenGL Compatibility, à l’approche de l’obstacle et avant l’arrivée, ont permis de vérifier le déplacement de la bosse en vue de poursuite.

### 2026-11-16 — Passages du peloton sur Woodworks et Glacier (1.78.0-rc)

Base de comparaison GitHub `3dbca0484f5e402f01160885a5eef2235f06eaab`.

- Sur le troisième tracé de Woodworks, la bille se coinçait entre le plot à ressort gauche et le raccord de rambarde. Le plot est avancé de 2,60 m vers l’amont. La mini-carte, la géométrie et les effets de contact suivent le même emplacement.
- Sur le premier tracé de Glacier, le bord de la dernière bosse bloquait une bille entrée dans le peloton. La bosse est déplacée après le virage relevé comme sur Forge. Les trois placements solo sont testés lors des transitions vers le multijoueur puis du retour au même tracé en solo.
- Le test de peloton couvre les neuf variantes et deux entrées supplémentaires à 51 m de l’arrivée, à 18 m/s. Sur ces deux entrées, les 40 billes passent la ligne. La simulation distincte qui a révélé les blocages classe également les 40 billes sur ces deux tracés. Certaines variantes peuvent toujours éliminer des billes.

### 2026-11-16 — Franchissement de l’arrivée et collisions de Forge (1.79.0-rc)

Base de comparaison GitHub `e4eb3e258c61b596d7695205c3a938b3039d84b0`.

- L’autorité de course interpole la position au franchissement dans le sens de la course. Elle vérifie la largeur réelle du tablier, sa hauteur et une marge de 8 m pour les sauts. La régression Godot 4.5.1 couvre les trois circuits avec des billes au sol, en saut, sous le tablier et hors de la largeur.
- Dans une course normale à 40, les contacts du marteau, de la palette et d’un plot de Forge pouvaient pousser une bille sous le tablier. Les marteaux solo de Forge sont reculés de 1,60 m dans le sens de la course. Les scénarios depuis la grille n’observent plus de passage sous le tablier à l’intérieur de la piste sur Forge. Deux sorties latérales restent observées sur la troisième variante. Les courses réseau gardent les positions de mécanismes du serveur déployé.
- Les départs artificiels qui plaçaient des billes dans des obstacles ont été écartés pour diagnostiquer ce défaut. La régression du championnat surveille le passage sous le tablier près de la paire marteau-palette identifiée sur Forge.

### 2026-11-16 — Mesures Android par phase de course (1.80.0-rc)

Base de comparaison GitHub `a9557b001be60c2e47af53b0b8d11d983cd21bb4`.

- Le réglage FPS active un relevé local par phase. Il couvre le départ, le milieu de course et le dernier secteur. Le rapport associe chaque P95 au tracé, au profil et au nombre d’images. Il inclut les images lentes ainsi que les relevés de physique et de rendu.
- L’écran de résultats permet de copier le rapport ou de rejouer le même tracé avec le même atout dans l’autre profil. Le changement de profil est conservé dans les réglages. Le chronométrage saute l’intervalle de pause et compte les saccades en jeu.
- Godot 4.5.1 vérifie la séparation des phases, les pauses, les saccades et la relance de comparaison depuis les résultats. Les mesures sur Redmi restent à faire.

### 2026-11-16 — Première course guidée par les gestes (1.81.0-rc)

Base de comparaison GitHub `812ec7b814dfbbe76747d6338c617776f175d15e`.

- La première course solo sur Woodworks enregistre la direction et le boost au moment où ils sont appliqués à la bille. Les consignes suivent les actions du joueur, même si elles arrivent après les anciennes limites de temps ou dans l’ordre inverse.
- Le guide explique le diamant turbo et les flèches ambrées du pont lorsqu’ils deviennent pertinents. Il se termine après le choix de route et la validation des deux commandes. Le diamant reste facultatif. Le panneau laisse la priorité aux alertes de danger.
- Vérification Godot 4.5.1 avec deux doigts, boost bref entre deux rafraîchissements du HUD, diamant collecté ou dépassé, pont et piste principale, sauvegarde du parcours et isolation multijoueur.

### 2026-11-16 — Signal des pistons de Forge (1.82.0-rc)

Base de comparaison GitHub `61e7064f8f97039b8488d0d646722929275bcb02`.

- Les trois pistons gagnent une tête d’acier nervurée, un socle et un feu d’accotement. Le contour au sol reste fixe autour du piston. Le feu, le marquage et le texte suivent l’horloge du mécanisme, du préavis ambre à la phase rouge puis à la réouverture. La lueur d’un évitement de précision reste sur le contour du piston.
- Le signal décrit l’état actuel du mécanisme. Le HUD continue à prévoir son état au moment du passage du joueur. Les réglages de collision et les règles solo et réseau gardent les trajectoires existantes.
- Godot 4.5.1 vérifie les phases des neuf pistons sur les trois variantes, y compris le passage du préavis à la montée. Les 12 paires de vues en OpenGL Compatibility, caméra de poursuite à une vitesse affichée de 82 km/h, ont chacune le même nombre d’appels de rendu avant et après. [Comparatif du piston au retour du pont](screenshots/v1.82-forge-piston.jpg). Mesures de fluidité sur Redmi en attente.

### 2026-11-16 — Mesurer le départ et la jonction du pont (1.83.0-rc)

Base de comparaison GitHub `f82157d6712bb0d2509e8434d5e9bcb72ed79cfb`.

- Le rapport copiable distingue les cinq premières secondes après GO et les huit mètres de part et d’autre de la jonction du pont. Les deux lignes complètent les trois secteurs du rapport.
- La zone de jonction couvre le même tronçon sur les deux routes. Pour comparer les profils, rejouer le même tracé avec le même atout et suivre la même trajectoire. Chaque fenêtre courte relève au moins une fois les compteurs Godot dès qu’elle enregistre un intervalle.
- Le test du rapport couvre les limites des fenêtres, l’exclusion de la pause, les images lentes et la relance de comparaison. Mesures sur Redmi à effectuer.

### 2026-11-17 — Copie du rapport FPS sur Android (1.84.0-rc)

Base de comparaison GitHub `e533e8dd79f4a68a68347c76630687ca1e2ec93e`.

- Godot 4.5.1 planifie l’écriture du presse-papiers sur le thread Android. La confirmation attend la relecture du rapport complet. En cas d’échec, le rapport reste consultable et sélectionnable dans les résultats.
- Une relance ou un retour au menu invalide la confirmation en cours. La fenêtre du rapport se ferme lors du changement d’écran.

### 2026-11-17 — Ombres directionnelles de Forge en Balanced (1.85.0-rc)

Base de comparaison GitHub `b4cb5f61ebabb3dc93c03d9e657ead284fa2dcb5`.

- Forge passe à deux cascades d’ombres directionnelles sur 33 m en Balanced, avec la première séparation à 9,9 m de la caméra. Le réglage s’applique aussi lorsque Auto sélectionne Balanced.
- Sur Godot 4.5.1 avec Mesa en OpenGL ES, quatre vues fixes et 40 billes sont comparées pour chacun des trois tracés de Forge. Les médianes des appels de rendu passent de 828 à 675 sur la grille, de 1 004 à 825 dans l’ouverture, de 957 à 779 à l’approche du retour du pont et de 915 à 717 après le retour. Les ombres proches restent visibles.
- La régression de profil couvre la relance, Auto, Economy, Ultra et le changement de circuit. Les temps d’image sur Redmi restent à mesurer.

### 2026-11-17 — Ombres des décors hors piste de Forge (1.86.0-rc)

Base de comparaison GitHub `b41dccc954fc2d051db7a559126e75853edca19f`.

- Balanced retire des passes d’ombre les supports sous la piste, l’établi, les garnitures, les étagères, les trophées et les globes des lampes. Les éléments restent visibles. Les ombres des murs et de la poutre continuent de modeler la piste. Ultra retrouve les ombres secondaires.
- Sur 12 vues fixes avec 40 billes et trois tracés, les médianes d’appels de rendu passent de 779 à 726 à l’approche du retour de pont, puis de 717 à 660 après la jonction. Le retrait des ombres des murs et de la poutre modifie fortement l’image et a été écarté.
- La régression couvre la reconstruction du tracé, le changement de profil et le passage à Glacier. Les temps d’image sur Redmi restent à mesurer.

## PROCHAIN LOT RECOMMANDÉ

Profiler le rendu des billes dans le peloton à la jonction du pont. Chercher une réduction sur les billes éloignées en conservant la lisibilité des concurrents proches.
