import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'base.g.dart';

/// Qui détient la marchandise : la société de coursiers, ou la cousine.
enum TypeDepositaire { coursier, cousine }

/// Rythme auquel le dépositaire reverse l'argent.
enum Reversement { quotidien, surDemande }

/// La cliente se fait livrer, ou vient retirer en main propre.
enum ModeRemise { livraison, retrait }

/// Les quatre états d'une commande.
enum EtatCommande { confiee, livree, reversee, annulee }

enum ModePaiement { aLaLivraison, mobileMoney }

/// Les quatre mouvements qui font bouger un stock, plus l'ajustement
/// d'inventaire quand le comptage ne tombe pas juste.
enum TypeMouvement { arrivage, repartition, sortie, retour, ajustement }

@DataClassName('Produit')
class Produits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nom => text()();
  IntColumn get prixVente => integer()();
  IntColumn get prixAchat => integer()();

  /// Quand c'est vrai, la cliente ne paie pas les frais de livraison : ils
  /// restent entièrement à la charge du business.
  BoolColumn get livraisonOfferte =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
}

@DataClassName('ZoneLivraison')
class Zones extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nom => text()();

  /// Ce que la cliente paie en plus du produit.
  IntColumn get fraisCliente => integer()();

  /// Ce que le coursier réclame pour la course, par livraison.
  IntColumn get tarifCoursier => integer()();
}

@DataClassName('Depositaire')
class Depositaires extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nom => text()();
  TextColumn get type => textEnum<TypeDepositaire>()();
  TextColumn get reversement => textEnum<Reversement>()();
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
}

@DataClassName('Commande')
class Commandes extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get cliente => text()();
  TextColumn get telephone => text().withDefault(const Constant(''))();
  TextColumn get adresse => text().withDefault(const Constant(''))();
  IntColumn get zoneId => integer().nullable().references(Zones, #id)();
  IntColumn get depositaireId => integer().references(Depositaires, #id)();
  TextColumn get mode => textEnum<ModeRemise>()();
  TextColumn get etat => textEnum<EtatCommande>()();
  TextColumn get paiement => textEnum<ModePaiement>()();

  /// Commande passée hors circuit, directement auprès du dépositaire, et
  /// enregistrée après coup.
  BoolColumn get dejaServie => boolean().withDefault(const Constant(false))();

  /// Les deux montants de la livraison, figés au moment de la commande pour
  /// qu'un changement de barème ne réécrive pas le passé.
  IntColumn get fraisCliente => integer().withDefault(const Constant(0))();
  IntColumn get tarifCoursier => integer().withDefault(const Constant(0))();

  TextColumn get note => text().withDefault(const Constant(''))();
}

@DataClassName('LigneCommande')
class LignesCommande extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get commandeId =>
      integer().references(Commandes, #id, onDelete: KeyAction.cascade)();
  IntColumn get produitId => integer().references(Produits, #id)();
  IntColumn get quantite => integer()();

  /// Prix figé au moment de la commande.
  IntColumn get prixUnitaire => integer()();
  IntColumn get prixAchatUnitaire => integer().withDefault(const Constant(0))();
}

@DataClassName('MouvementStock')
class MouvementsStock extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get depositaireId => integer().references(Depositaires, #id)();
  IntColumn get produitId => integer().references(Produits, #id)();

  /// Signé : positif quand la marchandise arrive chez le dépositaire, négatif
  /// quand elle en sort.
  IntColumn get quantite => integer()();
  TextColumn get type => textEnum<TypeMouvement>()();
  IntColumn get commandeId => integer().nullable().references(Commandes, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
}

@DataClassName('Arrivage')
class Arrivages extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

@DataClassName('LigneArrivage')
class LignesArrivage extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get arrivageId =>
      integer().references(Arrivages, #id, onDelete: KeyAction.cascade)();
  IntColumn get produitId => integer().references(Produits, #id)();
  IntColumn get quantite => integer()();

  /// Prix d'achat total de la ligne.
  IntColumn get coutAchat => integer()();
}

@DataClassName('BoostArrivage')
class BoostsArrivage extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get arrivageId =>
      integer().references(Arrivages, #id, onDelete: KeyAction.cascade)();
  IntColumn get montant => integer().withDefault(const Constant(200000))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

@DataClassName('Pointage')
class Pointages extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get depositaireId => integer().references(Depositaires, #id)();

  /// Ce que le dépositaire a réellement versé ce jour-là.
  IntColumn get verseReel => integer().withDefault(const Constant(0))();
  BoolColumn get cloture => boolean().withDefault(const Constant(false))();
}

@DataClassName('LigneRapport')
class LignesRapport extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pointageId =>
      integer().references(Pointages, #id, onDelete: KeyAction.cascade)();
  TextColumn get cliente => text().withDefault(const Constant(''))();

  /// Le produit tel qu'il est écrit sur le rapport, avant reconnaissance.
  TextColumn get produitTexte => text().withDefault(const Constant(''))();
  IntColumn get produitId => integer().nullable().references(Produits, #id)();
  IntColumn get quantite => integer().withDefault(const Constant(1))();
  IntColumn get prix => integer().withDefault(const Constant(0))();
  IntColumn get zoneId => integer().nullable().references(Zones, #id)();
  IntColumn get frais => integer().withDefault(const Constant(0))();

  /// Faux quand le produit ne figure pas à son catalogue : la ligne est alors
  /// présumée appartenir à la collègue et écartée d'office.
  BoolColumn get dansCatalogue =>
      boolean().withDefault(const Constant(false))();

  /// Ce qu'elle a finalement décidé de retenir. Modifiable à la main.
  BoolColumn get incluse => boolean().withDefault(const Constant(false))();
  IntColumn get commandeId => integer().nullable().references(Commandes, #id)();
}

@DriftDatabase(tables: [
  Produits,
  Zones,
  Depositaires,
  Commandes,
  LignesCommande,
  MouvementsStock,
  Arrivages,
  LignesArrivage,
  BoostsArrivage,
  Pointages,
  LignesRapport,
])
class BaseMiracle extends _$BaseMiracle {
  BaseMiracle() : super(_ouvrir());

  /// Base en mémoire, pour les tests.
  BaseMiracle.enMemoire(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await amorcer();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Le catalogue, le barème et les deux dépositaires, tels qu'ils existent
  /// aujourd'hui. Tout reste modifiable dans les réglages.
  Future<void> amorcer() async {
    await batch((b) {
      b.insertAll(produits, const [
        ProduitsCompanion(
          nom: Value('Gel anti-vergeture'),
          prixVente: Value(70000),
          prixAchat: Value(8000),
          livraisonOfferte: Value(false),
        ),
        ProduitsCompanion(
          nom: Value('Savon Toudy'),
          prixVente: Value(60000),
          prixAchat: Value(27500),
          livraisonOfferte: Value(false),
        ),
        ProduitsCompanion(
          nom: Value('Gamme Toudy'),
          prixVente: Value(180000),
          prixAchat: Value(75600),
          livraisonOfferte: Value(true),
        ),
        ProduitsCompanion(
          nom: Value('Kit fessier'),
          prixVente: Value(250000),
          prixAchat: Value(150000),
          livraisonOfferte: Value(true),
        ),
      ]);

      b.insertAll(zones, const [
        ZonesCompanion(
          nom: Value('Conakry'),
          fraisCliente: Value(15000),
          tarifCoursier: Value(33900),
        ),
        ZonesCompanion(
          nom: Value('Coyah et Dubréka'),
          fraisCliente: Value(30000),
          tarifCoursier: Value(33900),
        ),
        ZonesCompanion(
          nom: Value('Intérieur (gare d\'embarquement)'),
          fraisCliente: Value(15000),
          tarifCoursier: Value(40000),
        ),
      ]);

      b.insertAll(depositaires, const [
        DepositairesCompanion(
          nom: Value('Société de coursiers'),
          type: Value(TypeDepositaire.coursier),
          reversement: Value(Reversement.quotidien),
        ),
        DepositairesCompanion(
          nom: Value('Cousine'),
          type: Value(TypeDepositaire.cousine),
          reversement: Value(Reversement.surDemande),
        ),
      ]);
    });
  }
}

LazyDatabase _ouvrir() {
  return LazyDatabase(() async {
    final dossier = await getApplicationDocumentsDirectory();
    final fichier = File(p.join(dossier.path, 'miracle.sqlite'));
    return NativeDatabase.createInBackground(fichier);
  });
}
