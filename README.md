# Tamleek

Application Flutter d’investissement avec un tableau de bord inspiré de la
maquette fournie : packs REIT, FPI, matières premières, crypto et actions.
Chaque pack ouvre une fiche présentant sa description et sa composition.
Le bouton « Investir » d’une fiche ouvre un parcours de préparation avec choix
du montant (10 à 8 250 $ en fractionné; 1 000 $ minimum en intégral). Le mode
intégral se règle par multiples de 1 000 $ par part. Le mode fractionné affiche
une projection illustrative basée sur l’hypothèse demandée de 20 % par mois,
composée mensuellement (791,61 % sur 12 mois); la même projection est affichée
pour les parts entières. Ce chiffre n’est pas un rendement réel ni garanti. La
confirmation n’effectue aucune transaction : aucun service d’investissement
sécurisé n’est connecté. La fiche Investir propose aussi de revendre une
position uniquement lorsque le pack correspondant est détenu, avec une
estimation de frais de 5 %;
la vente n’est pas exécutée sans service de transaction connecté.
Les lignes d’activité du portefeuille ouvrent un reçu détaillé. Les demandes
de dépôt, retrait, investissement et revente affichent également un reçu avec
leur statut réel (non exécuté tant que les services correspondants ne sont
pas connectés); les lignes d’historique préremplies sont marquées comme
exemples non vérifiés.
Chaque reçu est présenté comme un ticket à bord dentelé, avec une image
d’ambiance liée à l’opération et un bouton circulaire pour partager le reçu
en PNG. Les demandes de dépôt, retrait, investissement et revente affichent
d’abord une confirmation, puis leur reçu détaillé.

Le profil regroupe en bas de page, dans la section « Centre », les notifications,
le support par e-mail (qui prépare un brouillon adressé à
tamleek.contact@gmail.com), la page « Aide et informations », la page
« Autorisation » et le choix de langue français/anglais, conservé sur l’appareil.
Cette dernière page affiche la licence commerciale fournie, encadrée et
agrandissable. La page d’aide présente l’histoire de Tamleek, ses cinq piliers
et la photo du fondateur. Les liens officiels du site, de Facebook et de YouTube
ouvrent les pages fournies depuis le profil. Le bloc « Notre emplacement » a
été retiré.

Les prix et rendements affichés sont des estimations informatives non
actualisées et ne garantissent pas de revenus futurs.

Le logo Tamleek est utilisé dans les notifications internes et comme icône
Android par défaut pour Firebase Cloud Messaging. L’envoi réel de notifications
push nécessite encore la configuration d’un projet Firebase.

Le backend Firebase est optionnel au lancement et s’active lorsque les options
Firebase sont fournies par `--dart-define`. Lorsqu’il est configuré,
l’inscription et la connexion utilisent Firebase Authentication
(e-mail/mot de passe), la réinitialisation de mot de passe est envoyée par
Firebase et le profil (nom, e-mail, téléphone) est synchronisé dans
`users/{uid}`. Sans configuration Firebase, l’application conserve le parcours
local de démonstration; aucune authentification distante n’est alors réalisée.
La connexion Google et la connexion par numéro de téléphone ne sont pas
configurées.

Le formulaire KYC demande prénom, nom, année et lieu de naissance, ville,
département, pays, numéro de pièce et photo obligatoire. Avec Firebase, la photo
(JPEG, PNG ou WebP, 5 Mo maximum) est téléversée dans un chemin Storage privé,
puis la fonction callable `submitKyc` valide les données et crée
`kycSubmissions/{uid}` avec le statut `pending`. Les règles Firestore interdisent
aux clients d’écrire le statut; seule une personne habilitée dans le projet
Firebase peut examiner le dossier et modifier son statut. Le badge vert et le
déblocage KYC dépendent exclusivement du statut `verified` lu dans Firestore.
Un investissement strictement supérieur à 5 000 $ et tout retrait restent
bloqués jusque-là. Sans Firebase, la soumission est désactivée et les données
ne sont ni conservées ni transmises.

Cette configuration ne traite pas les paiements : les dépôts, investissements,
retraits et reventes restent des demandes informatives non exécutées.

La photo de profil et les préférences de langue restent locales. Le bouton
« Se déconnecter », en bas du profil, ferme également la session Firebase
lorsque le backend est configuré.

## Dépôts USDT

L’écran de dépôt affiche les adresses et QR fournis pour Polygon, Solana, BNB
Smart Chain, TRON et Ethereum, et valide localement le format du hash selon le
réseau. La vérification on-chain, le suivi des confirmations et le crédit du
solde nécessitent un backend; aucun dépôt n’est confirmé ni crédité par
l’application seule.

## Configurer Firebase

1. Dans le projet Firebase de Tamleek, ajoute les applications Android
   (`com.example.tamleek`), iOS et Web nécessaires, puis active le fournisseur
   E-mail/Mot de passe dans Authentication.
2. Crée Firestore et Storage. Dans un terminal interactif connecté au compte
   Firebase qui possède Tamleek, sélectionne le projet avec la commande
   `firebase use --add`, puis déploie les règles et la fonction :

```shell
npm --prefix functions install
npm --prefix functions run build
firebase deploy --project PROJECT_ID --only firestore:rules,storage,functions
```

3. Copie `firebase_config.example.json` vers `firebase_config.json`, remplace
   les valeurs par les paramètres de l’application Firebase ciblée, puis lance
   `flutter run --dart-define-from-file=firebase_config.json`. L’App ID doit
   correspondre à la plateforme configurée; `AUTH_DOMAIN` est requis pour le
   Web.

Les paramètres Firebase du client identifient le projet, mais ne sont pas des
secrets. Ne jamais ajouter au dépôt de clé de compte de service, jeton OAuth ou
mot de passe. Le traitement KYC nécessite un plan Firebase autorisant le
déploiement des Cloud Functions et Storage. Les documents refusés et leur photo
privée ne sont remplacés qu’à la nouvelle soumission; les administrateurs
doivent appliquer une politique de conservation et de suppression conforme aux
obligations de Tamleek.

## Lancer l’application

Depuis ce dossier, avec Flutter installé et un appareil ou émulateur connecté :

```shell
flutter pub get
flutter run
```

## Vérifier le projet

```shell
flutter analyze
flutter test
```
