# Tamleek

Application Flutter Tamleek avec un catalogue informatif de packs REIT, FPI,
matières premières, crypto et actions. Les descriptions et compositions sont
locales et ne constituent pas des cours de marché vérifiés ou actualisés.

Lorsque Supabase est configuré, l’inscription, la connexion, la réinitialisation
du mot de passe et la déconnexion utilisent Supabase Auth. Sans configuration,
l’application démarre en mode local : l’inscription locale permet d’ouvrir les
écrans de l’application, mais ne crée pas de compte en ligne et ne conserve pas
le mot de passe. La connexion et la récupération de mot de passe nécessitent
Supabase.

Les autres écrans fonctionnent localement ou restent en consultation : les
informations de profil, la photo et la langue sont conservées sur l’appareil; le
catalogue, l’aide et les pages informatives restent accessibles hors ligne. Les
notifications ne sont pas disponibles hors ligne.

Les opérations financières ne sont jamais simulées localement. Avec une session
Supabase active, le portefeuille, les dépôts confirmés, les demandes de retrait,
les souscriptions et les positions sont lus depuis le backend. Les demandes de
souscription, de revente et de retrait restent en attente jusqu’à leur validation
et leur exécution réelles; l’application n’affiche pas ces demandes comme des
transactions déjà payées.

## Opérations financières Supabase

Applique les migrations Supabase. Les dépôts sont des demandes manuelles : le
client enregistre le réseau, le montant déclaré et le hash dans
`deposit_requests`, avec le statut `pending`. Aucun appel de vérification
on-chain ne crédite le compte en mode manuel et une demande en attente
n’augmente pas le solde. La vérification automatique est désactivée par défaut.

Pour examiner les dépôts depuis **Supabase → Table Editor → deposit_requests**,
filtre `status` sur `pending`, puis vérifie le hash, le réseau, le portefeuille
de réception et le montant réellement reçu. Modifie `amount_usdt` au montant
réel, puis passe `status` à `credited`. Le solde ne prend en compte que les
lignes `credited`. Pour un dépôt non reçu ou invalide, passe `status` à
`rejected` et explique la décision dans `review_note`. Le statut ne peut être
révisé qu’une fois depuis `pending`.

Il n’y a pas de bouton dédié dans l’application : la confirmation se fait en
modifiant la ligne dans le Table Editor comme indiqué ci-dessus. Pour traiter
les demandes dans le SQL Editor, utilise :

```sql
select id, user_id, network, transaction_hash, amount_usdt, created_at
from public.deposit_requests
where status = 'pending'
order by created_at;
```

Après vérification, remplace `<id>` par l’identifiant de la demande et `<montant_reçu>`
par le montant vérifié :

```sql
update public.deposit_requests
set amount_usdt = <montant_reçu>,
    status = 'credited',
    review_note = 'Réception vérifiée'
where id = '<id>' and status = 'pending';
```

Pour une demande invalide, utilise `status = 'rejected'` et renseigne le motif
dans `review_note`.

Une adresse de réception partagée peut recevoir les fonds, mais la vérification
manuelle du hash, du réseau et du montant reste indispensable avant d’accorder
un crédit. Ne marque jamais un dépôt comme `credited` avant d’avoir confirmé
sa réception.

Pour activer temporairement la vérification automatique, ouvre
**Supabase → Table Editor → deposit_verification_settings** et passe
`auto_enabled` à `true` sur la ligne `global`. Pour revenir au traitement
manuel, repasse cette valeur à `false`. Cette option doit rester désactivée
tant que des adresses personnelles ne sont pas affectées dans
`user_deposit_addresses` pour les comptes concernés. Le serveur vérifie aussi
ce réglage avant d’interroger une blockchain; un client ne peut pas l’activer.

Les demandes de retrait réservent le montant disponible et ne passent à l’état
payé qu’après le transfert sortant et l’enregistrement de son hash. Les achats
et reventes sont soumis à une revue; l’approbation doit correspondre à une
exécution réelle de l’opération. La migration
`20261119100000_fixed_investment_reference_prices.sql` active les 25 produits
avec un prix interne fixe de 1 000 USDT par unité. Ce prix ne suit pas les
marchés, n’est pas une NAV de marché vérifiée et n’est pas affiché dans
l’interface. Les documents KYC sont conservés dans le bucket privé
`kyc-documents` et doivent être examinés avant que le statut puisse être marqué
comme vérifié.

Dans le formulaire d’investissement, le mode fractionné demande un montant
USDT. Le mode parts entières demande un nombre de parts, au tarif fixe de
1 000 USDT par part quel que soit l’actif. Le cours interne fixe de chaque
unité sert au calcul des parts détenues; aucun cours ni aucune date de cotation
n’est affiché.

Après validation d’une souscription, la position apparaît dans le portefeuille.
Le job Supabase `pg_cron` crédite automatiquement, le premier jour de chaque
mois, 20 % du capital encore investi au début du mois terminé. Les rendements
ne sont pas capitalisés et les unités déjà revendues sont exclues. Une ligne
par utilisateur, actif et mois empêche les doubles crédits. Les versements
apparaissent dans le solde USDT et dans l’historique de l’application.

Important : ce job applique une règle comptable fixe; il ne vérifie pas les
encaissements externes ni la disponibilité de liquidités. N’utiliser cette
automatisation que si les revenus et réserves nécessaires existent réellement.

Ces migrations et fonctions fournissent le registre et les contrôles d’accès;
elles ne remplacent pas un dépositaire, un fournisseur de liquidité, un courtier
ni le processus d’administration chargé d’attribuer les adresses et d’exécuter
les demandes. Tant que ces prérequis ne sont pas configurés, l’application
n’invente ni adresse, ni solde, ni confirmation de paiement.

## Authentification Supabase

Pour activer l’authentification en ligne, configure Supabase avec
`--dart-define-from-file=supabase_config.json`. Sans cette configuration,
l’application démarre tout de même en mode local; l’authentification sécurisée
et la réinitialisation du mot de passe restent indisponibles. L’inscription,
la connexion et la réinitialisation en ligne nécessitent une connexion Internet
et un projet Supabase configuré pour l’authentification par e-mail/mot de passe.

1. Dans Supabase, active l’authentification par e-mail dans
   **Authentication → Providers**. Dans **Authentication → URL Configuration**,
   définis `https://lupusgang457.github.io/Tamleek/` comme **Site URL** et
   ajoute cette même URL aux redirections autorisées. Ajoute aussi
   `tamleek://login-callback/` pour Android/iOS. Une URL de redirection
   `localhost` ne doit servir qu’au développement local.
2. Copie `supabase_config.example.json` vers `supabase_config.json`, puis
   renseigne l’URL du projet et sa clé `publishable` depuis
   **Project Settings → API Keys**.
3. Lance l’application avec la configuration **Tamleek (Supabase)** dans
   **Run and Debug** de VS Code, ou depuis le terminal :

```shell
flutter run --dart-define-from-file=supabase_config.json
```

Le fichier local `supabase_config.json` est ignoré par Git. La clé `publishable`
est prévue pour l’application; ne place aucune clé secrète dans le client.
Pour que l’APK release inclue cette configuration et se connecte à Supabase,
construis-la avec :

```shell
flutter build apk --release --dart-define-from-file=supabase_config.json
```

Dans VS Code, tu peux aussi lancer la tâche **Tamleek: Build release APK
(Supabase)** depuis **Terminal → Run Build Task**. Elle transmet le fichier
local de configuration afin d’éviter de générer un APK sans connexion en ligne.

## Publication Web

Le workflow GitHub Actions `.github/workflows/deploy-web.yml` construit et
publie l’application sur GitHub Pages après chaque push sur `main`. Pour ce
dépôt, l’adresse Web est `https://lupusgang457.github.io/Tamleek/`. Ajoute cette
adresse comme **Site URL** et dans les **Redirect URLs** autorisées de
**Supabase → Authentication → URL Configuration** afin que les liens de
confirmation reviennent dans l’application. Après l’enregistrement d’un dépôt,
d’un retrait, d’une souscription ou d’une revente, la confirmation de succès
s’affiche avant le reçu. Les demandes de dépôt en attente affichent le réseau,
le hash, le montant déclaré et le statut; elles ne créditent pas le solde avant
validation manuelle.

GitHub Pages sert la version Web dans un navigateur; il ne fournit pas de
téléchargement Android. Pour distribuer l’application Android, il faut générer
un APK ou AAB signé et le publier séparément, par exemple dans une GitHub
Release ou sur Google Play.

## Signature Android

Une build Android release doit utiliser une clé privée dédiée. Configure les
propriétés locales dans `android/key.properties` (ce fichier et les keystores
sont ignorés par Git) :

```properties
storePassword=<mot-de-passe-du-keystore>
keyPassword=<mot-de-passe-de-la-cle>
keyAlias=tamleek-release
storeFile=C:/chemin/vers/tamleek-release-key.jks
```

Génère ensuite l’APK signé avec `flutter build apk --release`. Conserve la clé
privée et ses mots de passe dans un emplacement sûr : sans cette même clé, les
versions ultérieures ne pourront pas mettre à jour l’application installée.

La photo de profil et les préférences de langue sont enregistrées localement.
Le bouton « Se déconnecter » ferme la session Supabase.

## Lancer et vérifier le projet

Depuis ce dossier, avec Flutter installé et un appareil ou émulateur connecté :

```shell
flutter pub get
flutter run --dart-define-from-file=supabase_config.json
```

Pour vérifier le projet :

```shell
flutter analyze
flutter test
```
