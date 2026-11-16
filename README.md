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

Le logo Tamleek est utilisé dans les notifications internes. Les notifications
push ne sont pas reliées à un fournisseur.

Le backend Supabase est optionnel au lancement. Lorsqu’il est configuré,
l’inscription et la connexion utilisent Supabase Auth (e-mail/mot de passe),
la réinitialisation est envoyée par e-mail et le profil est synchronisé dans
`public.profiles`. Sans configuration Supabase, l’application conserve le
parcours local de démonstration; aucune authentification distante n’est
réalisée.

Le formulaire KYC demande prénom, nom, année et lieu de naissance, ville,
département, pays, numéro de pièce et photo obligatoire. Avec Supabase, la photo
(JPEG, PNG ou WebP, 5 Mo maximum) est envoyée dans le bucket privé
`kyc-documents`. La fonction Edge `submit-kyc` vérifie la session, les champs et
le contenu de l’image, puis crée `public.kyc_submissions` avec le statut
`pending`. Les utilisateurs ne peuvent ni écrire ni modifier ce statut; seuls
les administrateurs peuvent examiner le dossier et le passer à `verified` ou
`rejected`. Le badge vert et le déblocage KYC reposent sur le statut `verified`
reçu de Supabase. Un investissement strictement supérieur à 5 000 $ et tout
retrait restent bloqués jusque-là. Sans configuration Supabase, la soumission
est désactivée et les données ne sont ni conservées ni transmises.

Cette configuration ne traite pas les paiements : les dépôts, investissements,
retraits et reventes restent des demandes informatives non exécutées.

La photo de profil et les préférences de langue restent locales. Le bouton
« Se déconnecter », en bas du profil, ferme également la session Supabase
lorsque le backend est configuré.

## Dépôts USDT

L’écran de dépôt affiche les adresses et QR fournis pour Polygon, Solana, BNB
Smart Chain, TRON et Ethereum, et valide localement le format du hash selon le
réseau. La vérification on-chain, le suivi des confirmations et le crédit du
solde nécessitent un backend; aucun dépôt n’est confirmé ni crédité par
l’application seule.

## Configurer Supabase

1. Crée un projet Supabase et active la connexion par e-mail dans
   **Authentication → Providers**. Dans **Authentication → URL Configuration**,
   ajoute `tamleek://login-callback/` aux URLs de redirection autorisées (pour
   Android/iOS). Pour le Web, ajoute aussi l’URL exacte du site. Dans
   **SQL Editor**, exécute le contenu de
   `supabase/migrations/20261116000000_initial_schema.sql`. Cette migration crée
   les profils, les règles d’accès, le bucket privé KYC et la table de suivi.
2. Connecte-toi à la CLI Supabase et lie le projet avec son Project Ref :

```shell
npx supabase login
npx supabase link --project-ref PROJECT_REF
npx supabase functions deploy submit-kyc
```

La fonction utilise les secrets fournis automatiquement par Supabase et exige
une session valide. Ne copie jamais la clé `service_role` dans l’application.
Pour examiner un dossier, un administrateur peut consulter
`public.kyc_submissions` dans le tableau de bord et modifier son statut en
`verified` ou `rejected`; les règles empêchent un utilisateur de le faire
lui-même.

3. Copie `supabase_config.example.json` vers `supabase_config.json`, remplace
   l’URL et la clé `publishable` par celles de **Project Settings → API Keys**,
   puis lance :

```shell
flutter run --dart-define-from-file=supabase_config.json
```

Le fichier local `supabase_config.json` est ignoré par Git. La clé `publishable`
est prévue pour l’application; garde toute clé secrète côté serveur. Les
documents d’identité sont des données sensibles : applique une politique de
conservation et de suppression conforme aux obligations de Tamleek.

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
