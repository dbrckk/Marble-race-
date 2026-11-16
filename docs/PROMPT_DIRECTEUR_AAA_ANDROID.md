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

## PROCHAIN LOT RECOMMANDÉ
Construire l'inventaire visuel mesurable des neuf tracés et un jeu de captures comparables sur les trois biomes, puis traiter la première famille d'éléments génériques très visibles (pistes/rails/structures proches caméra), sans toucher aux colliders ni aux alertes de danger. En parallèle, instrumenter les mesures nécessaires pour refuser toute régression de performance. Vérifier en CI et indiquer ce qui nécessite encore un appareil Android.
