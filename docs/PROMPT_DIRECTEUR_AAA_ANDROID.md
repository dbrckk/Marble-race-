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

### 2026-11-17 — Maillage des billes éloignées en Balanced (1.87.0-rc)

Base de comparaison GitHub `184f4d075f601c5f9a6dcb16012d7ec1dd0f0bd4`.

- Balanced réutilise la sphère Economy lorsque la bille occupe moins de 22 pixels à la hauteur de référence de 720 px. Elle retrouve le maillage Balanced à 27 pixels. Le joueur, les rivaux à moins de neuf mètres et le rival signalé gardent le détail de près.
- La décision est prise huit fois par seconde à partir de la caméra active. Les billes gardent leur matériau et leur sphère de collision. L’optimisation réduit le nombre de triangles, avec un appel de rendu par bille comme avant.
- Les tests couvrent les deux seuils, le rival signalé et les changements vers Economy et Ultra. Le temps d’image sur Redmi reste à mesurer.

### 2026-11-17 — Comparatif du matériau des billes en peloton

Base de comparaison GitHub `697e7a5f65c50738035844a7a6f52518e9ad2153`.

- Le prototype conditionne le motif animé au skin exclusif et le second reflet au profil. Les maillages, la caméra et l’éclairage sont fixes. Cinq paires de captures avant et après sont identiques pixel par pixel sous Mesa et sur Android 14 émulé avec ANGLE. Elles couvrent les billes ordinaires en Balanced et Economy, puis les dix motifs premium à temps égal sur les trois profils.
- Sous Mesa OpenGL ES logiciel à 960 × 540, la médiane des trois médianes Balanced passe de 9,87 à 9,29 ms. Sur Android émulé, la médiane des trois P95 Balanced passe de 204,8 à 170,3 ms, tandis que les médianes Economy augmentent dans les trois séries. Ces mesures portent sur les intervalles entre images du banc logiciel. Les temps GPU et le gain sur téléphone restent à mesurer.
- Le shader de la version 1.87.0-rc reste en service. L’instrumentation et les résultats sont archivés dans la [PR de comparaison](https://github.com/dbrckk/Marble-race-/pull/8) et le [journal Android](https://github.com/dbrckk/Marble-race-/actions/runs/44047903900).

### 2026-11-17 — Départ de Woodworks et calculs des bots (1.89.0-rc)

Base de comparaison GitHub `bf9cf989d9c2829e02b985cb36a11c26f10a615a`.

- Les bots demandent le bulletin de danger général uniquement lorsqu’ils remplissent déjà les critères du dépassement. Le bulletin du HUD et les prévisions des mécanismes, des portails et des pistes secondaires gardent leur propre cadence.
- Huit départs du premier tracé Woodworks avec 40 billes, en Balanced, dont quatre départs avec le rendu 3D désactivé pour isoler son coût. Mesures prises pendant le compte à rebours, les deux premières secondes et à ±7 m de l’entrée du premier module. Les fenêtres peuvent se recouper. Les compteurs GPU de Godot ne remontent pas de durée exploitable en OpenGL Compatibility sur ce banc.
- Sous Mesa OpenGL ES logiciel à 640 × 360, avec la 3D, la médiane des deux séries de temps de pilotage des bots passe de 0,71 à 0,41 ms par pas au départ et de 0,72 à 0,42 ms au premier module. Les 39 requêtes par pas de simulation deviennent zéro dans les deux fenêtres. La variante avec 3D désactivée confirme la baisse du coût du pilotage. Le rendu domine la durée d’une image sur le banc logiciel. Ces mesures ne quantifient pas un gain de FPS sur téléphone.
- [Banc reproductible et relevés Android](https://github.com/dbrckk/Marble-race-/pull/9).

### 2026-11-17 — Ombres du départ de Woodworks (1.90.0-rc)

Base de comparaison GitHub `bb15ead2a034ba98c7c311abc61a92c87dffd034`.

- En Balanced, Woodworks utilise deux cascades directionnelles jusqu’à 39 m, avec la première séparation à 11,7 m. Les petits supports, étagères et globes restent visibles. Les murs, la poutre, les obstacles et les billes gardent leurs ombres de proximité.
- Sous Godot 4.5.1 en OpenGL ES logiciel, neuf vues fixes couvrent les trois tracés à la grille, dans le premier module et au deuxième secteur. La médiane des appels de rendu passe de 808 à 640, de 908 à 718 et de 840 à 647 selon la vue. La désactivation complète des ombres éclaircit fortement la piste. Les lampes, le brouillard et les ombres de contact ont été isolés séparément.
- La régression vérifie Auto, les profils manuels, une relance et les transitions entre circuits. Les mesures d’appels de rendu ne donnent pas un gain en FPS sur téléphone.

### 2026-11-17 — Verre en mouvement et ombres des billes (1.91.0-rc)

Base de comparaison GitHub `f8af5c7e29428cb6b4b18da5941014c7f013a282`.

- Le shader atténue les bandes et les étincelles lorsque leur fréquence dépasse la résolution locale à l’écran. Les bandes trop fines convergent vers leur couleur moyenne. Les motifs résolus, les reflets de studio et l’animation des motifs premium restent visibles.
- À 640 × 360 sous Mesa OpenGL ES logiciel, les rotations identiques de 40 billes sur 18 images réduisent de 55 à 56 % la dérivée seconde moyenne de luminance à l’intérieur des billes en Balanced et Economy. Les appels de rendu et la géométrie restent identiques dans le comparatif de verre. Cet indicateur mesure la stabilité visuelle de la séquence.
- À la grille de Woodworks en Balanced, réactiver les ombres directionnelles individuelles fait passer la vue de 597 à 677 appels de rendu et de 274 230 à 325 078 triangles. Le jeu conserve le lot d’ombres de contact.
- [Mesures et séquences Android](https://github.com/dbrckk/Marble-race-/pull/11). Le gain de FPS sur téléphone reste à mesurer.

### 2026-11-17 — Mipmaps des matériaux de la piste (1.92.0-rc)

Base de comparaison GitHub `5a45d696d51ab34208258a2025b3736d24454712`.

- Le bois, sa carte de normales et le vernis utilisaient des samplers mipmap sans niveaux générés à l’import. Les trois réglages de texture sont désormais suivis dans Git et la vérification de démarrage contrôle les niveaux importés. Le filtrage réutilise les matériaux existants. Les trois textures ajoutent 1,06 Mio de données décodées pour leurs niveaux de détail.
- À 640 × 360 sous OpenGL ES logiciel, les quatorze poses suivent la caméra de course de Woodworks à 22 m/s. Pour chaque pose, deux décalages latéraux de ±2 mm sollicitent les textures sous le pixel. Sur la zone de bois mesurée, la variation absolue moyenne de luminance passe de 1,33 à 0,42 sur une échelle de 255. Les appels de rendu restent à 644 sur la grille du banc.
- Les variantes à bois et à vernis unis isolent le travail de leurs shaders. Les intervalles entre images fluctuent entre séries sous émulation logicielle. Les FPS sur téléphone restent à mesurer. [Relevés et captures](https://github.com/dbrckk/Marble-race-/pull/12).

### 2026-11-17 — Relief et brillance du bois selon la profondeur (1.93.0-rc)

Base de comparaison GitHub `320bf99ab051a8080d838536b245677ecd8103d7`.

- Le relief et les fibres de rugosité gardent leur intensité dans les 14 premiers mètres de profondeur de vue. Ils s’atténuent jusqu’à 28 m. Au-delà, le shader saute la lecture de la carte de normales et les calculs des fibres. Le bois garde sa couleur et ses mipmaps à toutes les profondeurs.
- Le banc à un plan conserve la même surface affichée à 8 et 36 m à 640 × 360 sous Mesa OpenGL ES logiciel. À 36 m, la médiane des huit médianes d’intervalle passe de 5,18 à 4,37 ms. La variante descend sous la base dans les huit séries. Les variantes sans relief et sans fibres ont été mesurées séparément.
- Quatre cadrages Woodworks couvrent la grille, un plan au ras du bois, le premier obstacle et le deuxième repère. Le premier plan au ras des planches est identique pixel par pixel dans la zone mesurée. Les temps de la scène complète varient selon les séries, les appels de rendu et triangles concordent. [Captures et relevés Android](https://github.com/dbrckk/Marble-race-/pull/13). Les FPS sur téléphone restent à mesurer.

### 2026-11-17 — Radar groupé et classement compact (1.94.0-rc)

Base de comparaison GitHub `d1538c98ce28be01ac8cf6f22e4ca89555b915f5`.

- Le radar échantillonne les 40 positions réelles à 10 Hz. Les 39 points adverses partagent un dessin instancié 2D. La ligne de progression et les deux formes du marqueur joueur sont dessinées séparément. Le classement conserve son contenu sur un panneau plus court.
- Dans les vues Woodworks à 640 × 360, le radar passe de 42 à 4 appels de rendu. La scène entière économise 38 appels et 2 028 triangles sur la grille, près du premier obstacle en vraie course et lors du passage à 79 km/h simulés. Le panneau occupe environ 32 % moins de surface dans les captures.
- Les régressions couvrent les 40 positions, la remise à zéro au redémarrage, les alertes et les commandes à deux doigts. [Validation et captures Android](https://github.com/dbrckk/Marble-race-/pull/14). Les FPS sur téléphone restent à mesurer.

### 2026-11-17 — Contraste des alertes en course (1.95.0-rc)

Base de comparaison GitHub `1f793ab8b4eb3da8c77fb84ac93f71473a7e6787`.

- Un fond sombre ajusté au texte accompagne les alertes de bord, de route, de mécanisme, d’objet rare et de terrain. Le panneau des dangers imminents conserve sa priorité. Les fonds des alertes laissent passer le toucher.
- Le comparatif Woodworks à 640 × 360 couvre la première approche en vraie course, la même pose avec un fond clair de contrôle et une approche du diamant. Sous Mesa OpenGL ES logiciel, le fond ajoute un appel de rendu au premier obstacle et trois dans le cadrage où trois alertes sont visibles.
- [Captures et vérification Android](https://github.com/dbrckk/Marble-race-/pull/15).

### 2026-11-17 — Repère du diamant et dégagement de la piste (1.96.0-rc)

Base de comparaison GitHub `3484ded54bc587d464072a623f01444253a6aa1d`.

- Le repère des objets rares occupe un emplacement fixe sous le classement. Les alertes de pilotage gardent le centre et la priorité en fonction de l’ordre des obstacles. Avec les mêmes positions d’objets, les 1 620 échantillons aux abords des objets sur les neuf tracés à 83 km/h conservent les mêmes fenêtres d’affichage.
- La crête recoupait la ligne du dernier diamant solo de Glacier sur le premier tracé. L’objet se trouve 1,5 m plus tôt, sur la même voie. Le test de collecte au sol échoue désormais dans GitHub Actions si Godot signale une assertion, même si le script affiche son marqueur de fin.

### 2026-11-17 — Lecture du retour des ponts (1.97.0-rc)

Base de comparaison GitHub `76b6635205c88decdba9ed6e4a42bcedec703727`.

- Le texte de duel s’efface pendant le guidage du retour sur la piste. Le losange continue de suivre le rival et le texte revient après la jonction. Le repère de bifurcation garde son comportement à l’entrée du pont.
- À Glacier, l’alerte indique de rejoindre la piste à droite puis de viser le centre. À Forge, le repère de retour et la prévision du piston gardent chacun leur emplacement. Les tests couvrent les trois tracés de ces deux circuits, le guidage hors du pont et les commandes tactiles.

### 2026-11-17 — Caméra de poursuite en peloton et en saut (1.98.0-rc)

Base de comparaison GitHub `ad37972b0d864e11193fc7db3f8938628f3e62ba`.

- La caméra de poursuite réutilise la densité des rivaux sur la même voie. Elle se relève progressivement à l’approche d’un obstacle et vise plus bas en vol pour garder l’atterrissage dans le cadre. Le réglage est propre à la caméra de poursuite.
- Dans 99 poses contrôlées à 83 km/h sur les trois variantes de Woodworks, les billes masquent 85 des 231 points échantillonnés sur les flèches d’entrée, contre 92 auparavant. Le centre du diamant et le sommet de la barrière de gauche gardent une ligne de vue dégagée dans ce banc. À 2,4 m de hauteur de saut, le point de piste à 14 m devant la bille passe d’environ 54,5 % à 52,7 % de la hauteur d’image.
- Le banc utilise les positions des billes et le rayon du modèle physique pour mesurer les masquages. Les régressions du peloton, de l’atterrissage et des trois caméras vérifient les transitions et le pilotage.

### 2026-11-17 — Temps d’image à la grille et au premier obstacle (1.99.0-rc)

Base de comparaison GitHub `68725090e8a42dbc2316cceaee35ea43c479e457`.

- Le rapport FPS ajoute la dernière 1,15 s sur la grille et la traversée à ±4 m de l’entrée du premier obstacle. Le relevé des cinq premières secondes englobe toujours le franchissement quand celui-ci survient dans cette fenêtre. Les nouveaux relevés utilisent le rapport copiable et le bouton de comparaison existants.
- Sur Mesa OpenGL ES logiciel à 640 × 360, dix courses de 40 billes reproduisent la même trajectoire. Le P95 médian par paire au premier obstacle est de 34,8 ms en Economy et de 111,7 ms en Balanced. Les médianes d’appels de rendu sont 358 et 627. En Balanced avec les ombres directionnelles coupées, le P95 est de 92,3 ms. Avec la 3D désactivée, il se situe entre 8,1 et 10,1 ms selon le profil. La comparaison neutralise les plafonds d’images natifs des profils.
- Ces intervalles concernent le banc logiciel. Le banc Android rejoue les 79 mêmes poses pour les deux profils et les variantes d’isolation. [Protocole et résultats](https://github.com/dbrckk/Marble-race-/pull/19). Les mesures sur téléphone physique restent à faire.

### 2026-11-17 — Ombres Balanced de Woodworks (1.100.0-rc)

Base de comparaison GitHub `4fb9b4a5d2812a5b21a86bee2bb5bd3fac03a1e6`.

- Woodworks en Balanced utilise une carte d’ombres directionnelles sur 36 m. Les ombres de contact restent actives sous les billes. Les captures comparatives couvrent la grille, la mise en mouvement et l’entrée du premier obstacle.
- Sur Mesa OpenGL ES logiciel à 640 × 360 et 40 billes, le P95 au premier obstacle passe de 114,0 à 88,8 ms, en prenant la médiane de deux essais par réglage. Avec deux cascades, réduire la portée à 31 m puis à 29 m donne respectivement 105,1 et 98,4 ms. Les médianes d’appels de rendu sont de 626,5 avant et 609 avec la carte unique.
- Les essais isolés des lampes, ombres de contact, du brouillard et du décor donnent des résultats variables selon la phase. [Protocole, mesures et captures Android 14](https://github.com/dbrckk/Marble-race-/pull/20). Les gains sur téléphone physique restent à mesurer.

### 2026-11-17 — Ombres Balanced de Forge (1.101.0-rc)

Base de comparaison GitHub `a3993048c32ed10d07079187acdad0f5c8c6d517`.

- Forge en Balanced utilise une carte d’ombres directionnelles sur 33 m. Cette portée couvre les pistons proches, dont celui situé après le pont. Auto applique le même réglage quand il sélectionne Balanced.
- Les neuf approches de pistons couvrent les trois variantes, avec douze poses de caméra par approche et une référence sans ombre. Sur Mesa OpenGL ES logiciel à 640 × 360, la carte unique réduit de 34 à 64 les appels de rendu médians par approche. La variation temporelle des ombres augmente de 1,55 % en médiane appariée, et de 3,74 % sur l’approche la plus affectée. Le banc fige les pistons en position haute et isole la couche d’ombres directionnelles.
- Le test de qualité adaptative couvre la sélection de Forge, le passage en course et le retour d’Auto à Balanced. [Protocole et captures Android 14](https://github.com/dbrckk/Marble-race-/pull/22).

### 2026-11-17 — Ombres Balanced de Glacier (1.102.0-rc)

Base de comparaison GitHub `204d123f78dd9a8df40d095c41a5ac8712b0cf43`.

- Glacier en Balanced utilise une carte d’ombres à 47 m. Les trois circuits utilisent ainsi une seule carte en Balanced, chacun à la portée mesurée pour son tracé. Les éléments de décor de Glacier conservent leurs ombres.
- Le banc rejoue douze poses de caméra par passage, aux abords de deux zones de glace et au retour du pont sur chacune des trois variantes. À 640 × 360 sous Mesa OpenGL ES, la carte unique économise de 123 à 184 appels de rendu médians par passage, soit 22,8 % en médiane appariée. La variation temporelle des ombres augmente de 1,05 % en médiane appariée. Le comparatif inclut deux cascades à la même portée et une référence sans ombre. [Protocole et captures Android 14](https://github.com/dbrckk/Marble-race-/pull/23).

### 2026-11-17 — Calculs de trafic en peloton (1.103.0-rc)

Base de comparaison GitHub `c88768b238498ada0e98ed6b242c3c753c7b4815`.

- Le [banc Android 14 avec 40 billes](https://github.com/dbrckk/Marble-race-/pull/24) mesure un P95 inférieur de 8,8 à 18,7 % avec les réglages d’ombres livrés. Les gains sur téléphone physique restent à établir.
- Les calculs de trafic lisent la position et la vitesse de chaque rival une fois par examen. La recherche du rival de tête sur Glacier écarte les billes hors de la fenêtre longitudinale avant le calcul latéral. Les règles de franchissement, de freinage et de dépassement utilisent les mêmes seuils.
- Sur un banc local sans rendu avec 40 billes, six répétitions de 7 200 appels par densité donnent un temps médian inférieur de 59 à 69 % pour la recherche du rival de tête et de 41 à 49 % pour le choix de voie. Ce banc mesure ces fonctions isolées. Un comparatif de 57 600 décisions vérifie les voies, la sélection des rivaux et le freinage utilisés au retour du pont.

### 2026-11-17 — Pilotage du peloton sur Forge (1.104.0-rc)

Base de comparaison GitHub `42b289afb1c948a84c4addf8a825e1a328b62fb0`.

- Le pilotage utilise la position et la vitesse au début de son étape et réutilise le centre de la piste pour les vérifications de proximité des rails. La vitesse est relue après une éventuelle impulsion de récupération. La gestion du trafic propre à Glacier s’exécute sur ce circuit.
- Sur un banc CPU sans rendu avec 40 billes, le pilotage est l’étape la plus coûteuse du script de simulation de Forge. Le P95 du pilotage et de la vérification d’arrivée passe de 855 à 756 µs, de 805 à 717 µs et de 792 à 640 µs sur les trois variantes. Le comparatif suit trois courses complètes à pas fixe. Les empreintes des positions et vitesses échantillonnées toutes les 60 étapes, les temps d’arrivée et les classements correspondent.

### 2026-11-17 — Contrôles du pont et animation des pistons (1.105.0-rc)

Base de comparaison GitHub `df7c18cf058b8b0e72d9f5956a25ad75d47dbd26`.

- Les contrôles du pont écartent les billes restées sur la piste principale avant de calculer les coordonnées du tablier. Les vérifications de saut et de récompense calculent ces coordonnées lorsqu’une bille est dans leur fenêtre. Les pistons réutilisent leur phase et leur hauteur d’extension dans la même mise à jour.
- Dans trois courses complètes de Forge avec 40 billes et un pas fixe, le P95 des contrôles du pont passe de 153 à 33 µs, de 132 à 56 µs et de 98 à 47 µs. Les empreintes des trajectoires échantillonnées, les temps d’arrivée et les classements correspondent pour les trois variantes.
- Sur un banc CPU sans rendu de 40 billes placées sur la piste principale, les contrôles du pont passent de 153 à 52 µs près du portail d’entrée et de 120 à 22 µs en amont de la jonction. La fenêtre excluait déjà cette grille à −104 m. Le temps médian du script d’animation des pistons baisse de 16 à 23 % sur le banc. Les positions, textes et couleurs comparés concordent. Les gains de FPS sur téléphone restent à mesurer.

### 2026-11-17 — Prévision des obstacles par les bots (1.106.0-rc)

Base de comparaison GitHub `086e4d09f3f973cf30d11f91701ddd4f2e4277f7`.

- La prévision calcule une fois la phase du mécanisme à l’arrivée de la bille. Un piston enterré libère sa voie. Pour les obstacles qui peuvent bloquer le passage, le calcul réutilise la même formule latérale et la même précision que le collider, en écartant le calcul de hauteur.
- Sur un banc CPU sans rendu, sept répétitions de 3 840 décisions par variante donnent une baisse médiane de 24 à 36 % pour cette fonction sur Forge, et de 35 à 43 % sur les deux autres circuits. Les 77 760 comparaisons autour des seuils de dégagement et de distance donnent des décisions identiques.
- Les trois courses complètes de Forge avec 40 billes donnent les mêmes positions et vitesses échantillonnées, temps d’arrivée et classements. Le P95 de l’ensemble du pilotage et de l’arrivée varie selon le tracé, de 853 à 794 µs, de 947 à 803 µs et de 750 à 765 µs. Les FPS sur téléphone restent à mesurer.

### 2026-11-17 — Anticipation des zones de terrain (1.107.0-rc)

Base de comparaison GitHub `8ee663bfe28989ec555217b7e2de5cdb21673822`.

- Les bots examinent les positions fixes des zones dans l’ordre du parcours et s’arrêtent au-delà de leur horizon. Sur Woodworks et Glacier, la prévision revient immédiatement à la voie choisie pour les profils qui ignorent déjà la zone. Sur Forge, elle calcule l’heure d’arrivée et la phase de l’évent quand sa proximité latérale peut modifier la trajectoire.
- Sur un banc CPU sans rendu, sept répétitions de 6 400 décisions par tracé donnent une baisse médiane du temps de prévision de 63 à 77 % sur Woodworks, de 71 à 76 % sur Glacier et de 38 à 60 % sur Forge. Les 204 120 comparaisons autour des seuils de distance, de largeur, de phase et de vitesse donnent les mêmes décisions.
- Une comparaison à 40 billes sur chacun des neuf tracés retrouve les mêmes trajectoires échantillonnées, temps d’arrivée et classements. Le P95 du pilotage et du contrôle d’arrivée baisse de 7 à 21 % selon le tracé dans ces essais CPU. Le temps d’image sur téléphone reste à mesurer.

### 2026-11-17 — Relance, résultats et fiabilité de la course (1.108.0-rc)

Base de comparaison GitHub `1730ecc614a6cff3797f80d70fd2e3915bf0cc5c`. Le [banc Android émulé et son contrôle CPU](https://github.com/dbrckk/Marble-race-/pull/25) précèdent ce lot.

1. En solo, Recommencer depuis la pause ou les résultats rejoue le même tracé, avec le même avantage et le fantôme correspondant. Les mécanismes reviennent à leur phase de départ. Tracé suivant sélectionne explicitement la variante suivante.
2. En ligne, Quitter demande confirmation et relâche les commandes locales. Reprendre redonne la main pendant que la course continue.
3. Le résultat principal reste visible au-dessus du rapport. Il affiche le rang d’arrivée, le temps à deux décimales et la variante. Une sortie de piste et une limite de temps ont des états distincts en solo. Les premiers du tableau sont réellement arrivés.
4. La carrière est écrite dans un fichier temporaire du même dossier, puis vérifiée et remplacée par renommage. Une écriture volontairement bloquée laisse les octets précédents intacts. La sauvegarde se recharge au format existant après une écriture réussie.
5. Woodworks et Glacier lisent une fois la position des billes éligibles à chaque étape physique. Forge parcourt les évents actifs sans créer ce relevé. Les tests de zone, de force, de recharge et d’anticipation couvrent les trois univers.

Les scénarios locaux couvrent le menu, le premier départ, le rejeu, les résultats, la pause et la sortie, la progression, les secteurs d’arrivée et les neuf tracés. Les écrans de résultats et de confirmation ont été rendus à 640 × 360 en OpenGL Compatibility. La vérification sur téléphone est reportée à la demande de l’utilisateur.

### 2026-11-17 — Écarts au fantôme aux secteurs (1.109.0-rc)

Base `e21135c51b9c30d40bdbb89e67c22494bfe84f95`. Le fantôme solo enregistre les trois temps cumulés de passage avec le tracé et l’avantage déjà associés au replay. En course et dans le bilan, un écart négatif indique une avance. Le bilan compare toujours au fantôme chargé au départ, avant le remplacement éventuel du record. L’affichage fonctionne aussi en Économie, qui masque le modèle 3D.

Les anciens fantômes restent lisibles et comparables à l’arrivée. Ils acquièrent les temps intermédiaires lors d’un nouveau record avec trois passages valides. Aux secteurs, le jeu continue d’afficher les temps habituels tant que le fantôme n’a pas de temps intermédiaires. Les tests de replay et de secteurs couvrent la sauvegarde, la relance, le nouveau record, les courses incomplètes et l’isolement du mode en ligne.

### 2026-11-17 — Bilan des secteurs face au fantôme (1.110.0-rc)

Base `fcdfe07f258bef2ee98b6a89f9fe82c00260fbe2`. Le bilan solo affiche d’entrée les quatre durées au centième, les records de secteur, l’écart à l’arrivée et le secteur où le joueur a perdu le plus de temps. Chaque écart de secteur soustrait les avances ou retards déjà accumulés avant son entrée. Les écarts cumulés aux trois repères restent dans le rapport détaillé. Les anciens fantômes affichent leur écart à l’arrivée. Les résultats en ligne et les abandons gardent leur présentation propre.

### 2026-11-17 — Carte du secteur le plus coûteux (1.111.0-rc)

Base `a53d68b8a718f956e85c1343faed6c1ad576fa58`. Depuis le bilan solo, **View Map** ouvre la carte du tracé terminé. Elle indique la zone, l’entrée et la sortie du secteur où le joueur a perdu le plus de temps face à son fantôme. Les repères correspondent aux positions de course, de la grille du joueur à la ligne d’arrivée. Le bouton de relance reprend le tracé et l’avantage utilisés.

### 2026-11-17 — Repère du secteur à travailler en course (1.112.0-rc)

Base `1fa5a3a5bde78c1f04e5a7a2426723a094b4e372`. Après **Retry Same Layout**, le radar indique l’entrée du secteur identifié dans le bilan ou sur la carte. La distance apparaît à l’approche selon la vitesse de la bille. Le secteur 1 s’annonce pendant le compte à rebours. Les dangers et les notifications de course passent avant ce repère textuel. Le repère utilise le même point d’entrée que la carte et s’efface au franchissement.

### 2026-11-17 — Écart sur le secteur ciblé après relance (1.113.0-rc)

Base `1c54522c9ef74e43cef7cc8607537316848b3183`. Une relance guidée terminée affiche le temps précédent, le temps actuel et le gain ou la perte au centième sur le secteur ciblé. Un redémarrage depuis la pause reprend le même temps de référence. Une nouvelle relance depuis le bilan utilise la course tout juste terminée. Le bilan affiche aussi les écarts au fantôme dans les cases des secteurs.

### 2026-11-17 — Choix du secteur depuis la carte (1.114.0-rc)

Base `26ad686604047b15ea362d6806aadb834ca4a676`. Le bilan ouvre la carte d’une course solo avec quatre secteurs chronométrés. Chaque portion de la piste est tactile et les quatre boutons permettent aussi de choisir un secteur. La carte affiche sa durée, ses repères d’entrée et de sortie et son écart au fantôme lorsqu’il est disponible. La relance depuis la carte reprend le choix du joueur et son chrono de référence.

### 2026-11-17 — Obstacles et approches du secteur choisi (1.115.0-rc)

Base `18c8aa844325b026474448746128f1677f91708f`. Les obstacles du secteur choisi sont numérotés dans l’ordre de la course. Les chevrons reprennent les peintures d’approche des mécanismes et des ponts, les flèches avant la glace ou le bord d’entrée de la zone physique. La liste se met à jour à chaque sélection pour le tracé qui vient d’être couru.

### 2026-11-17 — Repères en course pendant la relance guidée (1.116.0-rc)

Base `809c98300b71292208a25f464cba34cfe4487122`. Le radar et le panneau latéral reprennent le prochain obstacle numéroté de la carte et sa distance d’approche. Les repères suivent la piste principale ou le pont et indiquent le retour sur la piste à la sortie du pont. Ils s’effacent au fil du parcours. Les alertes de danger et les temps intermédiaires prennent la priorité sur le panneau latéral.

### 2026-11-17 — Sensations de course et lisibilité (1.117.0-rc)

Base `28b6d944a329549db2b207eb7b2b629342e734ab`. Captures natives en 640 × 360 avec 40 billes, sur le menu, le briefing, le départ, les premières sections des trois circuits et le bilan de Forge. Le panneau des circuits recouvrait le bouton des skins et les alertes encombraient le centre de la piste. Les options occupent maintenant une grille sous le sélecteur. La caméra de poursuite amortit son écart à la bille pendant la descente. Le joystick indique sa course réelle et le bouton de boost affiche la charge en anneau. Les obstacles d'ouverture et de fin se détachent sur le plateau grâce à des marquages bordés, intégrés aux maillages existants. Les alertes proches ont la priorité quand plusieurs indications se disputent la vue.

### 2026-11-17 — Rendu du peloton par instances (1.118.0-rc)

Base `5240a9d63eb285673069bed74458056b75c40825`. Les 39 adversaires gardent leurs corps physiques et leurs motifs de verre. Leur rendu utilise deux lots selon la taille à l'écran, avec culling par bille. La bille du joueur conserve son matériau pour les skins et le boost. Sur les départs capturés à 640 × 360 en Balanced, les appels de dessin passent de 590 à 552 sur Woodworks, de 719 à 681 sur Glacier et de 636 à 598 sur Forge. Le changement a été comparé avec le rendu GL Compatibility sur ordinateur.

### 2026-11-17 — Passage le plus coûteux après une relance guidée (1.119.0-rc)

Base `126b9e3eba23a635727f63c831576666b4693939`. Chaque secteur comprend quatre passages chronométrés en solo. Le bilan conserve les temps de la course précédente en mémoire et affiche le passage où la relance sur le même tracé a coûté le plus de temps. Le bouton ouvre la carte directement sur la zone surlignée. Les franchissements valides sont interpolés au fil de la course, sur la route ou le pont. Les passages incomplets laissent le bilan de secteur disponible.

### 2026-11-17 — Repère en course du passage ciblé (1.120.0-rc)

Base `2419255f8fbedad49b80b8231923a9f56077f64a`. Une relance du secteur surligné reporte le même intervalle sur le radar. Le panneau d’approche indique la distance à l’entrée puis à la sortie, avec priorité aux alertes de danger. Le repère s’efface après le passage et est rétabli si le joueur recommence depuis la pause.

### 2026-11-17 — Chrono du passage travaillé (1.121.0-rc)

Base `d2ae8dcee1bf26b261b94a18850da5568dd02ca5`. Le bilan solo compare au centième le temps du passage ciblé avec celui de la tentative précédente sur le même tracé. La carte continue de signaler la plus grosse perte de la course qui vient de se terminer. Sur Woodworks, le passage ciblé 4 est passé de 3,56 s à 2,66 s alors que la perte la plus importante concernait le passage 3.

### 2026-11-17 — Briefing plus lisible et alertes de course (1.122.0-rc)

Base `4bcaad09c4fab266557f16fd22bcbb7643e7f57e`. Le briefing affiche les six avantages avant la carte. Le nom du circuit, le tracé, le côté du pont et le conseil de conduite sont agrandis et restent visibles pendant le défilement. En course, les prévisions de passage libre et le texte du duel cèdent la place à la direction du pont et aux dangers pertinents. Aux mêmes positions avant les bifurcations, les lignes centrales passent de 4 à 3 sur Woodworks, de 3 à 2 sur Glacier, et de 4 à 2 sur Forge.

### 2026-11-17 — Bille du joueur repérable dans le peloton (1.123.0-rc)

Base `be40a3fab9a449f2e46ac3d230977e31073f1cf2`. Le repère YOU de taille fixe suit la projection de la bille. Deux arcs contrastés la délimitent au départ ou à proximité d’adversaires, puis disparaissent lorsque le peloton s’écarte. Les trois circuits ont été capturés aux mêmes positions avant et après. Le coût total augmente d’au plus un appel de dessin par image dans les neuf échantillons de bureau comparés. Le plafond conserve son ombre et libère la piste lorsque la caméra s’élève au-dessus du plateau.

### 2026-11-17 — Silhouettes des obstacles mobiles (1.124.0-rc)

Base `09d244a0eae3310b7c52aee819484c92f90a1636`. Les bras de Woodworks sont en bois cerclé, les volets de Glacier ont une silhouette givrée à pans coupés et les pistons de Forge ont une tête nervurée. Chaque obstacle partage deux maillages par biome. Les chevrons de Woodworks et de Glacier utilisent les bonnes couleurs pour le fond sombre et la bande claire. Les six vues appariées en GL Compatibility conservent le même nombre d’appels de dessin.

### 2026-11-17 — Portiques ouverts et supports des circuits (1.125.0-rc)

Base `e19f7c76817b0714284c784d851f8cef6d3a6400`. Les ponts ont des portiques en bois courbé, en lames de glace ou en acier ajouré. Les nouvelles piles des ponts partagent leur maillage avec les piliers des voûtes de la piste principale. Les portiques dégagent l'axe de la caméra, avec des ailes à plus de 1,5 m du centre. Les potelets de précision conservent leurs collisions. Les neuf vues comparées en GL Compatibility gardent le même nombre d'appels de dessin.

### 2026-11-18 — Contact et roulement sur les ponts (1.126.0-rc)

Base `f06548a1b02acfd30bdc43b66d4956390e5a9fdd`. En solo, la sonde d’envol confirme le matériau sur deux relevés du sol. Le son passe en fondu de la piste au bois, à la glace ou à l’acier et revient à la piste au raccord. Le roulement s’atténue en saut. Les passages activent un anneau bref à la surface et la traînée standard reprend la couleur du pont au contact. L’anneau réutilise le lot d’atterrissage existant. Le budget supplémentaire est une voix de roulement pour le joueur local.

### 2026-11-18 — Retour de surface des ponts en ligne (1.127.0-rc)

Base `6be2b1671518d64430fd05a2b56d7c5a925e4146`. Le client estime la vitesse de sa bille à partir des positions horodatées du serveur. La sonde de sol locale reconnaît le matériau du pont et pilote le son, la traînée et les anneaux de passage. Le client suspend le retour de roulement lors d’un retard de plus de 350 ms ou d’une correction importante. Deux clients indépendants vérifient le fondu et les anneaux à l’entrée et à la sortie du pont.

## PROCHAIN LOT RECOMMANDÉ

Vérifier la fluidité du peloton et le mix sonore sur Android. Affiner le niveau du roulement pendant un dépassement, quand le vent et les impacts se superposent.
