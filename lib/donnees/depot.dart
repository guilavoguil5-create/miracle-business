import 'package:drift/drift.dart';

import 'base.dart';

/// Un article que l'on ajoute à une commande en cours de saisie.
class NouvelleLigne {
  final Produit produit;
  final int quantite;

  const NouvelleLigne({required this.produit, required this.quantite});

  int get total => produit.prixVente * quantite;
}

/// Toutes les écritures de l'app passent par ici.
class Depot {
  final BaseMiracle base;

  Depot(this.base);

  /// Frais que la cliente paie pour cette commande.
  ///
  /// Dès qu'un seul article de la commande est en livraison offerte, toute la
  /// commande part en livraison offerte : la cliente ne paie rien.
  static int fraisPourCliente({
    required ModeRemise mode,
    required ZoneLivraison? zone,
    required List<NouvelleLigne> lignes,
  }) {
    if (mode == ModeRemise.retrait || zone == null) return 0;
    final offerte = lignes.any((l) => l.produit.livraisonOfferte);
    return offerte ? 0 : zone.fraisCliente;
  }

  /// Ce que le coursier réclame. Il se paie par livraison, même quand la
  /// livraison est offerte à la cliente. Un retrait ne coûte rien.
  static int tarifPourCoursier({
    required ModeRemise mode,
    required ZoneLivraison? zone,
  }) {
    if (mode == ModeRemise.retrait || zone == null) return 0;
    return zone.tarifCoursier;
  }

  /// Enregistre une commande et sort la marchandise du stock du dépositaire
  /// dans le même geste : c'est ce qui empêche le stock de dériver.
  Future<int> creerCommande({
    required DateTime date,
    required String cliente,
    required String telephone,
    required String adresse,
    required Depositaire depositaire,
    required ZoneLivraison? zone,
    required ModeRemise mode,
    required ModePaiement paiement,
    required bool dejaServie,
    required List<NouvelleLigne> lignes,
    String note = '',
  }) {
    return base.transaction(() async {
      final commandeId = await base.into(base.commandes).insert(
            CommandesCompanion.insert(
              date: date,
              cliente: cliente,
              telephone: Value(telephone),
              adresse: Value(adresse),
              zoneId: Value(zone?.id),
              depositaireId: depositaire.id,
              mode: mode,
              // Une commande enregistrée après coup est déjà entre les mains de
              // la cliente : elle entre directement en livrée.
              etat: dejaServie ? EtatCommande.livree : EtatCommande.confiee,
              paiement: paiement,
              dejaServie: Value(dejaServie),
              fraisCliente: Value(
                fraisPourCliente(mode: mode, zone: zone, lignes: lignes),
              ),
              tarifCoursier: Value(
                tarifPourCoursier(mode: mode, zone: zone),
              ),
              note: Value(note),
            ),
          );

      for (final ligne in lignes) {
        await base.into(base.lignesCommande).insert(
              LignesCommandeCompanion.insert(
                commandeId: commandeId,
                produitId: ligne.produit.id,
                quantite: ligne.quantite,
                prixUnitaire: ligne.produit.prixVente,
                prixAchatUnitaire: Value(ligne.produit.prixAchat),
              ),
            );

        await base.into(base.mouvementsStock).insert(
              MouvementsStockCompanion.insert(
                date: date,
                depositaireId: depositaire.id,
                produitId: ligne.produit.id,
                quantite: -ligne.quantite,
                type: TypeMouvement.sortie,
                commandeId: Value(commandeId),
              ),
            );
      }

      return commandeId;
    });
  }

  Future<void> changerEtat(int commandeId, EtatCommande etat) {
    return (base.update(base.commandes)..where((c) => c.id.equals(commandeId)))
        .write(CommandesCompanion(etat: Value(etat)));
  }

  /// Annuler remet la marchandise dans le stock du dépositaire.
  Future<void> annulerCommande(int commandeId) {
    return base.transaction(() async {
      final commande = await (base.select(base.commandes)
            ..where((c) => c.id.equals(commandeId)))
          .getSingle();
      if (commande.etat == EtatCommande.annulee) return;

      final lignes = await (base.select(base.lignesCommande)
            ..where((l) => l.commandeId.equals(commandeId)))
          .get();

      for (final ligne in lignes) {
        await base.into(base.mouvementsStock).insert(
              MouvementsStockCompanion.insert(
                date: DateTime.now(),
                depositaireId: commande.depositaireId,
                produitId: ligne.produitId,
                quantite: ligne.quantite,
                type: TypeMouvement.retour,
                commandeId: Value(commandeId),
                note: const Value('Commande annulée'),
              ),
            );
      }

      await (base.update(base.commandes)..where((c) => c.id.equals(commandeId)))
          .write(const CommandesCompanion(etat: Value(EtatCommande.annulee)));
    });
  }

  /// Enregistre un arrivage et le répartit entre les dépositaires.
  ///
  /// [repartition] dit combien de chaque produit part chez qui.
  Future<int> creerArrivage({
    required DateTime date,
    required List<({Produit produit, int quantite, int coutAchat})> lignes,
    required List<({Depositaire chez, Produit produit, int quantite})>
        repartition,
    required List<int> boosts,
    String note = '',
  }) {
    return base.transaction(() async {
      final arrivageId = await base.into(base.arrivages).insert(
            ArrivagesCompanion.insert(date: date, note: Value(note)),
          );

      for (final ligne in lignes) {
        await base.into(base.lignesArrivage).insert(
              LignesArrivageCompanion.insert(
                arrivageId: arrivageId,
                produitId: ligne.produit.id,
                quantite: ligne.quantite,
                coutAchat: ligne.coutAchat,
              ),
            );
      }

      for (final part in repartition) {
        await base.into(base.mouvementsStock).insert(
              MouvementsStockCompanion.insert(
                date: date,
                depositaireId: part.chez.id,
                produitId: part.produit.id,
                quantite: part.quantite,
                type: TypeMouvement.repartition,
              ),
            );
      }

      for (final montant in boosts) {
        await base.into(base.boostsArrivage).insert(
              BoostsArrivageCompanion.insert(
                arrivageId: arrivageId,
                montant: Value(montant),
                date: date,
              ),
            );
      }

      return arrivageId;
    });
  }

  /// Remet le stock compté en face du stock calculé, et écrit l'écart.
  Future<void> ajusterStock({
    required Depositaire chez,
    required Produit produit,
    required int quantiteComptee,
    required int quantiteCalculee,
    String note = '',
  }) async {
    final ecart = quantiteComptee - quantiteCalculee;
    if (ecart == 0) return;
    await base.into(base.mouvementsStock).insert(
          MouvementsStockCompanion.insert(
            date: DateTime.now(),
            depositaireId: chez.id,
            produitId: produit.id,
            quantite: ecart,
            type: TypeMouvement.ajustement,
            note: Value(note.isEmpty ? 'Inventaire' : note),
          ),
        );
  }

  Future<void> enregistrerProduit({
    int? id,
    required String nom,
    required int prixVente,
    required int prixAchat,
    required bool livraisonOfferte,
  }) async {
    if (id == null) {
      await base.into(base.produits).insert(
            ProduitsCompanion.insert(
              nom: nom,
              prixVente: prixVente,
              prixAchat: prixAchat,
              livraisonOfferte: Value(livraisonOfferte),
            ),
          );
    } else {
      await (base.update(base.produits)..where((p) => p.id.equals(id))).write(
        ProduitsCompanion(
          nom: Value(nom),
          prixVente: Value(prixVente),
          prixAchat: Value(prixAchat),
          livraisonOfferte: Value(livraisonOfferte),
        ),
      );
    }
  }

  Future<void> enregistrerZone({
    int? id,
    required String nom,
    required int fraisCliente,
    required int tarifCoursier,
  }) async {
    if (id == null) {
      await base.into(base.zones).insert(
            ZonesCompanion.insert(
              nom: nom,
              fraisCliente: fraisCliente,
              tarifCoursier: tarifCoursier,
            ),
          );
    } else {
      await (base.update(base.zones)..where((z) => z.id.equals(id))).write(
        ZonesCompanion(
          nom: Value(nom),
          fraisCliente: Value(fraisCliente),
          tarifCoursier: Value(tarifCoursier),
        ),
      );
    }
  }

  Future<void> enregistrerDepositaire({
    int? id,
    required String nom,
    required TypeDepositaire type,
    required Reversement reversement,
  }) async {
    if (id == null) {
      await base.into(base.depositaires).insert(
            DepositairesCompanion.insert(
              nom: nom,
              type: type,
              reversement: reversement,
            ),
          );
    } else {
      await (base.update(base.depositaires)..where((d) => d.id.equals(id)))
          .write(
        DepositairesCompanion(
          nom: Value(nom),
          type: Value(type),
          reversement: Value(reversement),
        ),
      );
    }
  }
}
