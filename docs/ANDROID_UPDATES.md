# Android: conserver sa progression et installer les mises à jour

## Pour les joueurs Android (sans ordinateur)

Les **APK de test** générés par GitHub Actions sont signés avec une clé de
débogage temporaire. Il est **impossible de garantir** qu'un APK de test plus
récent s'installera directement par-dessus un précédent. Android exige
**la même identité de paquet et le même certificat de signature**.

À partir de la version **1.25**, le menu principal comprend **SAVE / RESTORE** :

1. Avant une désinstallation, ouvrir **SAVE / RESTORE**, puis toucher
   **COPY MY CAREER CODE**.
2. **Coller immédiatement** ce code dans une note conservée *en dehors de
   Marble Race* (Google Keep, Drive, fichier personnel…). Il ne suffit pas
   de le laisser uniquement dans le presse-papiers Android.
3. Tester d'abord l'installation par-dessus la version actuelle. Ne
   désinstaller que si Android la refuse **et** si la copie du code est sûre.
4. Après installation, ouvrir **SAVE / RESTORE**, coller le code dans la zone
   prévue, choisir **CHECK CODE**, vérifier le récapitulatif, puis
   **CONFIRM REPLACE MY CAREER**.

Le code contient les médailles, les records de temps, les classements, les
déblocages, la maîtrise, la ligue et les apparences. Il ne contient pas les
fichiers de course fantôme, les préférences, ni les données de connexion.
Les codes contiennent un contrôle SHA-256 pour détecter les copies incomplètes
ou endommagées, **pas** une signature d'authenticité. Restaurer un code
**remplace** la progression locale. Une copie locale `marble_career.cfg.before_import` est conservée, et le bouton **UNDO PREVIOUS IMPORT** permet de prévisualiser cette version puis de la restaurer avec confirmation. Cette annulation locale n'existe plus après désinstallation.

L'application n'envoie **aucune** de ces données à un serveur pour effectuer
une sauvegarde et ne demande pas de permission Android d'accès aux fichiers.

## Pour le propriétaire du dépôt : signature stable

La signature stable est **facultative** tant qu'une clé n'est pas configurée.
Une clé privée n'est jamais générée en CI pour une release, jamais ajoutée
au dépôt et jamais publiée comme artefact. L'absence de configuration ne
bloque pas l'APK de test habituel.

Pour activer la voie stable une fois pour toutes, utiliser une seule
**keystore personnelle** et configurer dans les paramètres du dépôt
**Settings → Secrets and variables → Actions** :

| Nom | Type | Valeur |
| --- | --- | --- |
| `MARBLE_ANDROID_KEYSTORE_BASE64` | Secret | Contenu binaire de la keystore encodé en Base64, sans sauts de ligne |
| `MARBLE_ANDROID_KEY_ALIAS` | Secret | Alias exact de la clé |
| `MARBLE_ANDROID_KEY_PASSWORD` | Secret | Mot de passe de la keystore et de la clé |
| `MARBLE_ANDROID_SIGNING_SHA256` | Variable | Empreinte SHA-256 du **certificat public** associé à cette clé, 64 caractères hexadécimaux |

Pour générer une nouvelle clé si aucune clé de diffusion n'existe déjà (par
exemple depuis un environnement Android avec Java `keytool` installé) :

```bash
keytool -genkeypair -keystore marble-release.jks -alias marble \
  -keyalg RSA -keysize 3072 -validity 10000
keytool -list -v -keystore marble-release.jks -alias marble
base64 -w 0 marble-release.jks > marble-release.jks.base64
```

**Important** : Godot 4.5 attend le même mot de passe pour la keystore et
la clé. Garder la keystore, son alias et son mot de passe dans un endroit
privé et durable : les perdre peut empêcher toute mise à jour compatible.
Si une clé existante a déjà été employée pour diffuser une version,
**réutiliser précisément cette clé** plutôt qu'en créer une nouvelle.

La variable publique d'empreinte sert de **verrou de sécurité** : le script
`ci/sign_android_release.sh` vérifie l'empreinte avant la compilation,
puis revérifie la signature de l'APK produit. Si une variable est manquante
ou si la clé a changé, l'export stable est refusé plutôt que d'émettre
une « fausse mise à jour ».

## Téléchargement des APK et sécurité des mises à jour

L'action `Verify and build Android APK` publie :

- `marble-race-android-debug` : APK de test + `debug-build-identity.txt`
  détaillant numéro de version, identifiant de paquet et empreinte SHA-256
  de **ce build précis**.
- `marble-race-android-stable-signed` **uniquement si la signature stable
  est configurée** : APK signé + `release-update-info.txt`.

Pour installer directement une mise à jour au lieu de réinstaller, les deux
APK doivent avoir exactement **`com.dbrckk.marble_race`** comme paquet,
le **même certificat** et un numéro de version supérieur. Passer d'un APK
debug à un APK stable nécessite généralement la sauvegarde par code puis
la désinstallation : les signatures sont différentes.

**Google Play** : une mise en ligne nouvelle application nécessite un AAB
signé avec la bonne clé d'upload. L'APK stable ajouté ici est destiné à
l'installation directe, **pas** un AAB prêt à publier. La signature de
l'application installée depuis Google Play peut être gérée séparément par
Play App Signing : ne pas supposer qu'un APK stable externe pourra la
remplacer directement.

Les artefacts GitHub Actions ne sont conservés que pendant 21 jours.
