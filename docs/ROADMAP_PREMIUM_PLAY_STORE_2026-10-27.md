# Marble Race — roadmap produit premium Android (audit du 27 octobre 2026)

## Base constatée dans le code (pas une évaluation subjective de l'APK)

- Godot 4.5.1 GL Compatibility, 40 billes physiques, trois univers et trois variantes de tracé par univers.
- Quatre objets rares immédiats réservés aux humains, ponts/raccourcis physiques, portes temporisées, bandes spécifiques aux biomes, bots tactiques.
- Défis de maîtrise 9/9, cinq styles permanents, ligue solo, meilleurs fantômes/secteurs, médailles de précision 1–3 passages par circuit.
- Dix skins exclusifs cosmétiques temporaires : vidéo récompensée 4h ou consommable Play à 2 € pour 6h, expiration non cumulable.
- Des tests headless, course longue, réseau autoritaire et génération APK debug sont intégrés dans Actions. **Succès CI ≠ qualité graphique AAA ni 60 FPS Android mesurés.**
- Le workflow AAB interne existe mais nécessite SDK Google natifs, ID AdMob réel, produit Google Play, serveur de vérification réellement déployé et signature permanente. **L'APK debug n'est pas un AAB publiable.**

## Top 12 priorités — ordre recommandé

| Ordre | Évolution | Impact joueur (sur 5) | Effort (sur 5) | Livrable et critère de validation |
|---:|---|---:|---:|---|
| 1 | **Boucle 30 secondes : tutoriel jouable et onboarding clair** | 5 | 3 | Départ guidé sans long texte : pousser, prendre un diamant, anticiper une porte, turbo, classement. Validation Android portrait/landscape selon jeu, sans blocage des doigts ni tutoriel obligatoire à chaque course. |
| 2 | **Identité visuelle exceptionnelle des 3 univers** | 5 | 5 | Silhouettes et props vraiment différents, matériaux mieux composés, VFX événementiels et caméra/composition lisibles. Avant/après capturés sur le même téléphone en profil équilibré. Vérifier licences de toute ressource externe. |
| 3 | **Obstacles à choix et interactions uniques** | 5 | 4 | Ajouter une mécanique distinctive par biome, visible avant contact, avec vrai collider et contournement possible. Chaque variante change des décisions, pas seulement la couleur/l'emplacement. Test 40 billes × 9 configurations. |
| 4 | **Vraie bande-son originale et système audio adaptatif** | 5 | 3 | Trois ambiances musicales distinctes, transitions propres menu/course/sprint, mixage limité pour choc/ramasse/fin, test à volume smartphone. Aucune musique importée sans droits. |
| 5 | **6–8 items humains supplémentaires, lisibles et équilibrés** | 5 | 4 | Vraie rareté, effets immédiats, couverture événement par circuit, animation de pickup et contre-jeu; serveur seul responsable des impulsions. Mesurer si chaque item est utile, éviter gagnant automatique. |
| 6 | **Campagne courte : missions de course variées et défis quotidiens locaux** | 5 | 4 | Défis par biome (précision, raccourci, temps, sans crash), récompenses esthétiques permanentes hors achat; génération déterministe sans dépendance cloud ni triche serveur. Mesurer retour au jeu, pas de récompense indisponible. |
| 7 | **Performance réelle sur 2–3 gammes Android** | 5 | 3 | Session de 15 min par qualité, FPS p95, ralentissements, température et batterie. Dégrader d'abord particules/ombres, préserver 40 colliders et HUD. Mesure obligatoire sur Redmi 15 5G + appareil modeste. |
| 8 | **Google Play : vrai AAB signé et monétisation activée sans tromper** | 5 | 4 | API cible à jour, tests UMP/consentement, AdMob récompensée, achats Billing à 2 €, HTTPS de vérification, clé durable, politique de confidentialité, compte Play Console, fiche/store et piste interne. Tester le reroll à 4h et l'achat de 6h; pas d'upload public automatique. |
| 9 | **Joueurs IA mémorables, sans triche** | 4 | 4 | Styles visuels/attitudes/pilotage différents, erreurs et prises de risque crédibles, réactions aux hazards et aux vrais adversaires. Identités bot claires si montrées comme bots; pas de fausse impression de joueurs humains. |
| 10 | **Plus de courses et de contenu de fin de jeu** | 4 | 5 | Quatrième univers réellement original ou un championnat remanié, modes chrono/ghost, nouvelles variantes de relief et objectifs. Garder des courses courtes et reproductibles. |
| 11 | **Multijoueur multi-salles et reconnect maîtrisé** | 4 | 5 | Aujourd'hui une salle dédiée de 2–4 humains au-dessus de bots. Plusieurs salons indépendants, sécurité d'entrée, latence, coût d'hébergement contrôlé et tests d'isolement; pas de classement irréaliste sans backend. |
| 12 | **Polish commercial : captures, cohérence UI, télémétrie locale et crash QA** | 4 | 3 | Icône unique, écran de démarrage, textes FR/EN, captures téléphone, contrôles sur tous ratios, rapport de crash sans information personnelle, revue des retours utilisateurs. |

## Priorités par phase

**Phase A — prochaine version de test :** tutoriel jouable, feedback des obstacles, écran de fin avec médailles de précision, tests systématiques de fluidité. La progression des médailles est déjà implémentée et doit rester cosmétique.

**Phase B — identité premium :** chaque biome gagne un nouveau comportement physique, des séquences d'audio originales et des effets procéduraux budgétés. Réutiliser MultiMesh et AudioStreamPlayer en pool, jamais 40 lumières dynamiques.

**Phase C — Release interne Google Play :** assembler le vrai AAB par le workflow dédié, activer AdMob UMP et le consumable vérifié, configurer les secrets hors dépôt, valider les achats et restaurations sur un appareil Android réel. Gérer publication/staging manuellement via Play Console pour cette première sortie.

**Phase D — rétention post-lancement :** observer tutoriel terminé, courses finies, reprises, performance p95 et satisfaction, puis sélectionner modes additionnels par signaux réels, pas par nombre d'effets.

## Barrières de qualité à ne pas contourner

1. Aucune fausse « disponibilité Play Store » tant que le fichier AAB, la signature et le circuit de paiement réels ne sont pas validés.
2. Aucun bonus de collision/vitesse lié à un skin payé; achat et vidéo strictement volontaires.
3. Règles physiques identiques pour joueur/IA et réseau serveur autoritaire.
4. Chaque changement de collider/trajectoire passe les 9 variantes, la course 110–120s, le championnat complet et le réseau.
5. Les captures Godot headless et CI servent à vérifier une régression, pas à promettre les FPS, la musique ou l'effet « wow » réellement perçus sur téléphone.
6. Les sources citées par star-list sont des références techniques, pas des licences implicites pour tous leurs modèles ou sons.
