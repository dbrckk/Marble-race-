# Marble Race — publication Google Play, version 1.0.0

**Statut : préparation technique, PAS publiée.** La pipeline actuelle produit un APK de test. Le préréglage `Android Play` est un **AAB signé destiné à Play Console**, mais son export reste volontairement bloqué jusqu'à la configuration des SDK et des comptes marchands.

## Publication depuis un smartphone Android (GitHub Actions)

La préparation de l'AAB est désormais automatisée dans le workflow
[`Build signed Google Play internal AAB`](../.github/workflows/play-internal.yml).
Cette action **ne publie pas le jeu** : elle crée un AAB signé pour la piste
interne, uniquement si la configuration réelle est complète.

**Configurer une seule fois :**

1. Dans Google Play Console, créer le produit **ponctuel consommable**
   `random_skin_6h`, tarif cible **2 €** en France, et les comptes de test.
   Chaque résultat aléatoire doit afficher **10 % de probabilité**.
2. Dans AdMob, créer l'application Android et l'emplacement **Rewarded**.
   Préparer les déclarations de confidentialité et les choix UMP requis.
3. Héberger `billing_service/` (Dockerfile inclus), avec un vrai compte
   de service Google Play Developer API et un **volume SQLite persistant**
   sur une instance unique. Configurer `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`,
   `MARBLE_DB_PATH=/data/purchases.sqlite3` et `PORT`. Tester `/healthz`.
   L'URL utilisée par le jeu doit se terminer par **`/verify`** sur HTTPS.
   Les secrets doivent être placés directement dans l'hébergeur, jamais dans
   le dépôt, un APK, un message ou une capture.
4. Dans GitHub → dépôt → Settings → Secrets and variables → Actions,
   renseigner les **variables** `MARBLE_ADMOB_APP_ID`,
   `MARBLE_ADMOB_REWARDED_UNIT_ID`, `MARBLE_PLAY_VERIFY_URL` et
   `MARBLE_ANDROID_SIGNING_SHA256` (empreinte publique de la vraie clé).
   Renseigner les **secrets** `MARBLE_ANDROID_KEYSTORE_BASE64`,
   `MARBLE_ANDROID_KEY_ALIAS` et `MARBLE_ANDROID_KEY_PASSWORD`.
   Réutiliser la clé d'upload existante si le package a déjà été publié.
5. Depuis un téléphone, ouvrir GitHub → Actions →
   **Build signed Google Play internal AAB** → Run workflow. Si toutes
   les dépendances et informations sont valides, récupérer
   `marble-race-play-internal-aab` dans les Artifacts. Uploader le
   `marble-race-play.aab` sur la piste de **test interne** de Play Console.
6. Tester sur un vrai téléphone Android : consentement accepté/refusé,
   vidéo complète/interrompue, achat de test, transaction en attente,
   récupération après coupure réseau, remplacement du skin actif,
   expiration après 4/6 h, réinstallation, remboursements, performances.
   **Ne passer en production qu'après tous ces essais.**

Le workflow de contrôle indépendant
[`Verify pinned Play Store native SDK dependencies`](../.github/workflows/play-native-sdk-check.yml)
vérifie les versions et SHA-256 des bibliothèques officielles, puis tente une
compilation AAB de test avec une **clé jetable détruite après usage**.
Cet essai ne produit aucun artefact installable en production.

Le composant `billing_service/app.py` vérifie les vrais jetons Google,
refuse les transactions en attente ou annulées, et persiste l'état de
consommation. Il attribue **une seule fois** un des dix skins (tirage serveur
cryptographiquement aléatoire) et son expiration UTC six heures plus tard.
Si une réponse est perdue, une nouvelle demande retourne le **même skin
et la même expiration**, jamais un nouveau tirage ou six heures supplémentaires. Son stockage doit être sauvegardé.
L'app garde une transaction non confirmée pour réessayer la vérification
sans initier un deuxième achat.

## Contenu V1

- Trois univers à relief et neuf variantes de courses, 40 billes, physique et commandes Android, championnat et multijoueur.
- Jeu freemium entièrement jouable sans publicité ni achat.
- **10 skins temporaires exclusifs** : Nebula Sovereign, Solar Phoenix, Void Emperor, Aurora Prism, Glacial Crown, Dragonfire Relic, Celestial Lotus, Quantum Mirage, Obsidian Eclipse et Royal Stardust.
- Une publicité **récompensée volontaire**, déclenchée uniquement depuis la boutique, donne **un skin au hasard pour 4 h** une fois la récompense Google Mobile Ads réellement émise.
- Un achat intégré **consommable**, référence `random_skin_6h`, au **prix cible de 2 € en France**, donne **un skin au hasard pour 6 h** après validation sécurisée.
- Chaque attribution remplace immédiatement le skin actif, même s'il restait du temps. **Durées non cumulables** et ancien skin non conservé. Un même skin peut ressortir au tirage.
- **10 % exactement par skin et par tirage**, quels que soient sa durée, son origine et les tirages précédents.
- Skins purement esthétiques : couleurs de verre animées, lumière, traînée, cendres, fumée, cristaux ou poussière d'étoiles. Aucune vitesse, résistance ou récompense de jeu accrue.

## Conditions bloquantes à lever pour la publication

1. Installer les dépendances natives officielles : [Godot AdMob de Poing Studios](https://github.com/poingstudios/godot-admob-plugin) (Godot 4.5 compatible) et [GodotGooglePlayBilling](https://github.com/godot-sdk-integrations/godot-google-play-billing). Déployer leurs composants **Android natifs** Gradle ; les simples scripts GDScript ne suffisent pas. Activer le consentement **UMP EEE/RGPD** avant d'initialiser/charger des publicités.
2. Dans **AdMob**, créer une application et un emplacement **Rewarded** réels ; ajouter l'ID application Android dans la configuration native du plugin et l'ID unité dans `MARBLE_ADMOB_REWARDED_UNIT_ID`. Ne jamais publier les IDs de test de Google comme IDs de production. Le joueur doit accepter volontairement la vidéo. Aucune publicité imposée entre les courses.
3. Dans **Play Console > Monétisation > Produits intégrés**, créer `random_skin_6h`, **produit ponctuel consommable** (pas un abonnement), prix de base cible 2,00 € en France. Contrôler le tarif final/local affiché par la feuille de paiement Google. Vérifier l'achat avec une licence de test avant publication.
4. Déployer un service HTTPS `MARBLE_PLAY_VERIFY_URL` qui vérifie les achats via l'**API Google Play Developer**, contrôle l'état **PURCHASED** et le produit/paquet, consomme le token **de façon idempotente** dans un stockage persistant et renvoie `{"ok":true,"consumed":true,"product_id":"random_skin_6h","token_sha256":"<SHA-256 exact du token>"}` **uniquement après** cette transaction. Le serveur doit refuser les tokens réutilisés, en attente, annulés et remboursés. L'application n'attribue **jamais** de skin après un simple appui ou un retour de facturation non vérifié. **Ne déployer aucun service de validation qui se contente de renvoyer ok:true.**
5. Utiliser le **même certificat de signature** dans la durée. Configurer les secrets GitHub `MARBLE_ANDROID_KEYSTORE_BASE64`, `MARBLE_ANDROID_KEY_ALIAS`, `MARBLE_ANDROID_KEY_PASSWORD` et la variable `MARBLE_ANDROID_SIGNING_SHA256`. **Ne jamais transmettre ces secrets dans le chat ou un dépôt Git.**
6. Installer le modèle Gradle Godot 4.5.1, SDK et compilateur **Android 36**, exporter le préréglage `Android Play` en AAB avec l'outil `ci/play_release_preflight.sh`. Godot 4.5.1 cible **API 35 par défaut**, qui **n'est plus recevable pour une nouvelle app** depuis le 31 août 2026. Le script de prépublication met le modèle Gradle à **compileSdk/targetSdk 36** et refuse tout élément absent. Prévoir un test réel sur Android 16 pour cette surcharge.
7. Tester installation Play (piste interne), achat réel en mode test, publicité récompensée, refus consentement, absence de publicité, changement de skin pendant les 4/6 h, fermeture/redémarrage d'app, expiration et révocation/refund. Valider l'intégrité de la progression et le consentement.
8. Compléter dans Play Console : classification PEGI/IARC, politique de confidentialité **publique sur HTTPS**, accès aux données (Data safety, y compris partenaires publicitaires et achats), ID publicitaire, captures réelles du jeu, icône 512×512, bannière 1024×500, fiche en français et anglais, âge cible, pays, tests et règles sur les achats aléatoires. Pour les comptes personnels récents, vérifier aussi les éventuels prérequis de test fermé.
9. La prise en charge des achats à **2 €** dépend des tarifs et taxes fixés dans la console, et non d'un chiffre codé en dur dans le jeu. Garder **la mention explicite « 10 % par skin » immédiatement avant** le bouton de paiement.

## Export

Le dépôt contient `export_presets.cfg` avec :

- `Android` : APK de debug actuel, destiné aux tests. Ce **n'est pas** un AAB Play Store.
- `Android Play` : v1.0.0 (code 100), ARM64, Gradle AAB, paquet `com.dbrckk.marble_race`.

Une fois le modèle Gradle installé, les dépendances natives intégrées, les variables d'environnement présentes et la signature configurée :

```bash
bash ci/play_release_preflight.sh
Godot_v4.5.1-stable_linux.x86_64 --headless --path . \
  --export-release "Android Play" build/marble-race-play.aab
```

**Ne pas uploader le paquet tant que le préflight et les vrais tests de paiement ne réussissent pas.** La simulation GitHub Actions seule ne prouve ni un paiement bancaire ni le rendu publicitaire.

## Tests automatiques

`tests/freemium_skins.gd` : catalogue exact, 10 %, tirages, expiration, non-cumul, effets cosmétiques uniquement, boutons inactifs sans SDK, anti-récompense fictive. Toutes les régressions physiques existantes doivent rester vertes.

## Limites explicites de V1

- Les skins temporaires sont visibles **sur la bille locale**. Le partage de l'apparence aux autres clients du multijoueur exigera une synchronisation visuelle spécifique et ne doit pas être annoncé pour cette version.
- L'heure d'expiration stockée localement est contrôlée contre les retours d'horloge, mais **ce n'est pas une source de temps inviolable**. Le service d'entitlements peut remplacer ce stockage avec une échéance signée à l'avenir.
- Le pont de monétisation n'autorise aucun paiement réel tant que le service de vérification et les SDK sont absents.

Sources à revérifier avant soumission : politique Google Play sur [les achats aléatoires](https://support.google.com/googleplay/android-developer/answer/9858738), [les annonces](https://support.google.com/googleplay/android-developer/answer/9857753), [API cible 36](https://support.google.com/googleplay/android-developer/answer/11926878), [export AAB Godot](https://docs.godotengine.org/en/4.5/tutorials/export/android_gradle_build.html).
