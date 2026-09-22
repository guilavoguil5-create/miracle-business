# Miracle business

Application de gestion pour Miracle business : vente de produits de soin de la
peau, commandes reçues sur Facebook, WhatsApp et par téléphone, marchandise
confiée à une société de coursiers et à une cousine.

L'app est faite pour une seule personne, sur son téléphone Android. Tout est
enregistré sur l'appareil, et rien n'a besoin de connexion. Les montants sont en
francs guinéens, sans décimales.

## Ce que l'app suit

- **Les commandes.** Une commande porte sa cliente, ses articles, la façon dont
  elle est remise (livraison ou retrait), le dépositaire à qui elle est confiée
  et son état : confiée, livrée, reversée, annulée.
- **Qui détient quoi.** Elle ne garde pas de stock chez elle : la marchandise est
  répartie entre les dépositaires. La sortie de stock est écrite au moment où la
  commande est saisie, jamais dans un deuxième écran, pour que le stock affiché
  reste vrai.
- **L'argent.** Ce que chaque dépositaire a encaissé et pas encore reversé.

## Les deux montants de la livraison

Ils ne sont jamais les mêmes et ne vont pas au même endroit :

- ce que **la cliente** paie en plus du produit, selon la zone ;
- ce que **le coursier** prend pour la course, selon la zone aussi.

Certains produits sont en livraison offerte : la cliente ne paie rien, mais le
coursier prend quand même sa course, qui reste à la charge du business. Dès
qu'un article de la commande est en livraison offerte, toute la commande l'est.
La course se paie par livraison et non par article.

## Le pointage du soir

Le rapport quotidien du coursier mélange les commandes de Miracle business avec
celles d'une collègue qui partage le même abonnement. Les totaux imprimés en bas
du rapport couvrent les deux commerces : **l'app ne les reprend jamais.** Elle
recalcule les totaux à partir des seules lignes qui lui appartiennent, écarte
d'office les lignes portant un produit hors catalogue, et déduit le surplus de
ce que le coursier a réellement versé.

Cette logique est écrite dans `lib/logique/argent.dart` et couverte par les
tests de `test/argent_test.dart`, qui reprennent les vrais prix et le vrai
barème.

## Organisation du code

```
lib/
  commun/     formatage des montants et des dates, libellés, widgets partagés
  donnees/    base SQLite (drift), écritures, providers Riverpod
  logique/    les calculs d'argent, sans Flutter ni base : testables seuls
  ecrans/     les écrans
test/         tests des calculs
```

## Construire l'APK

Le dossier `android/` n'est pas versionné : il est régénéré à chaque
construction, ce qui évite de garder des dizaines de fichiers de plateforme dans
le dépôt.

L'APK se construit tout seul à chaque envoi sur `main`, dans l'onglet
**Actions** de GitHub. L'APK installable est attaché à la construction, sous le
nom `miracle-business-apk`.

Pour construire à la main, avec Flutter installé :

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter create --platforms=android --project-name miracle_business \
  --org com.miraclebusiness .
flutter build apk --release
```
