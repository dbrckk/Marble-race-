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

## PROCHAIN LOT RECOMMANDÉ

Rendre la dernière relance plus lisible avant le sprint. Vérifier les trajectoires dans le peloton à l’approche du dernier obstacle et la priorité des signaux de danger sur le HUD.
