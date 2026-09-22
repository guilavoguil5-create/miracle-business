// Importé de façon ciblée : drift exporte un Column qui entrerait en conflit
// avec celui de Flutter.
import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../logique/argent.dart';
import 'base.dart';
import 'depot.dart';

final baseProvider = Provider<BaseMiracle>((ref) {
  final base = BaseMiracle();
  ref.onDispose(base.close);
  return base;
});

final depotProvider = Provider<Depot>((ref) => Depot(ref.watch(baseProvider)));

final produitsProvider = StreamProvider<List<Produit>>((ref) {
  final base = ref.watch(baseProvider);
  return (base.select(base.produits)..where((p) => p.actif.equals(true)))
      .watch();
});

final zonesProvider = StreamProvider<List<ZoneLivraison>>((ref) {
  final base = ref.watch(baseProvider);
  return base.select(base.zones).watch();
});

final depositairesProvider = StreamProvider<List<Depositaire>>((ref) {
  final base = ref.watch(baseProvider);
  return (base.select(base.depositaires)..where((d) => d.actif.equals(true)))
      .watch();
});

final commandesProvider = StreamProvider<List<Commande>>((ref) {
  final base = ref.watch(baseProvider);
  return (base.select(base.commandes)
        ..orderBy([
          (c) => OrderingTerm(expression: c.date, mode: OrderingMode.desc),
          (c) => OrderingTerm(expression: c.id, mode: OrderingMode.desc),
        ]))
      .watch();
});

final lignesCommandeProvider = StreamProvider<List<LigneCommande>>((ref) {
  final base = ref.watch(baseProvider);
  return base.select(base.lignesCommande).watch();
});

final mouvementsProvider = StreamProvider<List<MouvementStock>>((ref) {
  final base = ref.watch(baseProvider);
  return base.select(base.mouvementsStock).watch();
});

/// Tout ce que les écrans lisent, en un seul morceau.
///
/// Les tables sont petites (quelques commandes par jour, quatre produits) :
/// on les charge entières et on assemble en mémoire, ce qui évite des
/// jointures et garde les écrans lisibles.
class Instantane {
  final List<Produit> produits;
  final List<ZoneLivraison> zones;
  final List<Depositaire> depositaires;
  final List<Commande> commandes;
  final List<LigneCommande> lignes;
  final List<MouvementStock> mouvements;

  const Instantane({
    required this.produits,
    required this.zones,
    required this.depositaires,
    required this.commandes,
    required this.lignes,
    required this.mouvements,
  });

  Map<int, Produit> get produitsParId => {for (final p in produits) p.id: p};
  Map<int, ZoneLivraison> get zonesParId => {for (final z in zones) z.id: z};
  Map<int, Depositaire> get depositairesParId =>
      {for (final d in depositaires) d.id: d};
}

/// Null tant que tout n'est pas chargé.
final instantaneProvider = Provider<Instantane?>((ref) {
  final produits = ref.watch(produitsProvider).valueOrNull;
  final zones = ref.watch(zonesProvider).valueOrNull;
  final depositaires = ref.watch(depositairesProvider).valueOrNull;
  final commandes = ref.watch(commandesProvider).valueOrNull;
  final lignes = ref.watch(lignesCommandeProvider).valueOrNull;
  final mouvements = ref.watch(mouvementsProvider).valueOrNull;

  if (produits == null ||
      zones == null ||
      depositaires == null ||
      commandes == null ||
      lignes == null ||
      mouvements == null) {
    return null;
  }

  return Instantane(
    produits: produits,
    zones: zones,
    depositaires: depositaires,
    commandes: commandes,
    lignes: lignes,
    mouvements: mouvements,
  );
});

/// Une commande avec tout ce qu'il faut pour l'afficher et la chiffrer.
class CommandeVue {
  final Commande commande;
  final List<LigneCommande> lignes;
  final Map<int, Produit> produits;
  final Depositaire? depositaire;
  final ZoneLivraison? zone;

  const CommandeVue({
    required this.commande,
    required this.lignes,
    required this.produits,
    required this.depositaire,
    required this.zone,
  });

  int get id => commande.id;

  int get totalProduits =>
      lignes.fold(0, (s, l) => s + l.prixUnitaire * l.quantite);

  int get totalAchat =>
      lignes.fold(0, (s, l) => s + l.prixAchatUnitaire * l.quantite);

  /// Ce que la cliente paie en tout.
  int get totalCliente => totalProduits + commande.fraisCliente;

  CalculCommande get calcul => CalculCommande(
        totalProduits: totalProduits,
        totalAchat: totalAchat,
        fraisCliente: commande.fraisCliente,
        tarifCoursier: commande.tarifCoursier,
        prepayee: commande.paiement == ModePaiement.mobileMoney,
      );

  int get articles => lignes.fold(0, (s, l) => s + l.quantite);

  /// « 2 × Gel anti-vergeture, 1 × Savon Toudy »
  String get libelleProduits => lignes
      .map((l) {
        final nom = produits[l.produitId]?.nom ?? 'Produit supprimé';
        return l.quantite > 1 ? '${l.quantite} × $nom' : nom;
      })
      .join(', ');
}

List<CommandeVue> _assembler(Instantane i) {
  final parCommande = <int, List<LigneCommande>>{};
  for (final l in i.lignes) {
    parCommande.putIfAbsent(l.commandeId, () => []).add(l);
  }
  final produits = i.produitsParId;
  final zones = i.zonesParId;
  final depositaires = i.depositairesParId;

  return i.commandes
      .map((c) => CommandeVue(
            commande: c,
            lignes: parCommande[c.id] ?? const [],
            produits: produits,
            depositaire: depositaires[c.depositaireId],
            zone: c.zoneId == null ? null : zones[c.zoneId!],
          ))
      .toList();
}

final commandesVuesProvider = Provider<List<CommandeVue>>((ref) {
  final i = ref.watch(instantaneProvider);
  return i == null ? const [] : _assembler(i);
});

final commandesDuJourProvider = Provider<List<CommandeVue>>((ref) {
  final maintenant = DateTime.now();
  return ref
      .watch(commandesVuesProvider)
      .where((v) => memeJour(v.commande.date, maintenant))
      .toList();
});

/// Ce qu'un dépositaire détient d'un produit.
class StockLigne {
  final Depositaire depositaire;
  final Produit produit;
  final int quantite;

  const StockLigne({
    required this.depositaire,
    required this.produit,
    required this.quantite,
  });
}

final stockProvider = Provider<List<StockLigne>>((ref) {
  final i = ref.watch(instantaneProvider);
  if (i == null) return const [];

  final cumuls = <({int depositaire, int produit}), int>{};
  for (final m in i.mouvements) {
    final cle = (depositaire: m.depositaireId, produit: m.produitId);
    cumuls[cle] = (cumuls[cle] ?? 0) + m.quantite;
  }

  final depositaires = i.depositairesParId;
  final produits = i.produitsParId;
  final lignes = <StockLigne>[];

  for (final d in i.depositaires) {
    for (final p in i.produits) {
      final quantite = cumuls[(depositaire: d.id, produit: p.id)] ?? 0;
      lignes.add(StockLigne(
        depositaire: depositaires[d.id] ?? d,
        produit: produits[p.id] ?? p,
        quantite: quantite,
      ));
    }
  }
  return lignes;
});

/// Stock total d'un produit, tous dépositaires confondus.
final stockParProduitProvider = Provider<Map<int, int>>((ref) {
  final total = <int, int>{};
  for (final l in ref.watch(stockProvider)) {
    total[l.produit.id] = (total[l.produit.id] ?? 0) + l.quantite;
  }
  return total;
});

/// Ce qu'un dépositaire doit encore : les commandes livrées mais pas encore
/// reversées.
class SoldeVue {
  final Depositaire depositaire;
  final List<CommandeVue> enAttente;

  const SoldeVue({required this.depositaire, required this.enAttente});

  int get montant =>
      enAttente.fold(0, (s, v) => s + v.calcul.netAReverser);

  int get coutLivraisons =>
      enAttente.fold(0, (s, v) => s + v.commande.tarifCoursier);
}

final soldesProvider = Provider<List<SoldeVue>>((ref) {
  final i = ref.watch(instantaneProvider);
  if (i == null) return const [];
  final vues = ref.watch(commandesVuesProvider);

  return i.depositaires.map((d) {
    final enAttente = vues
        .where((v) =>
            v.commande.depositaireId == d.id &&
            v.commande.etat == EtatCommande.livree)
        .toList();
    return SoldeVue(depositaire: d, enAttente: enAttente);
  }).toList();
});

/// Chiffres du jour affichés sur l'accueil.
class ResumeDuJour {
  final List<CommandeVue> commandes;

  const ResumeDuJour(this.commandes);

  List<CommandeVue> get vivantes => commandes
      .where((v) => v.commande.etat != EtatCommande.annulee)
      .toList();

  int get nombre => vivantes.length;

  int get encaisseAttendu =>
      vivantes.fold(0, (s, v) => s + v.calcul.encaisse);

  int get marge => vivantes.fold(0, (s, v) => s + v.calcul.marge);

  int get aConfier => commandes
      .where((v) => v.commande.etat == EtatCommande.confiee)
      .length;
}

final resumeDuJourProvider = Provider<ResumeDuJour>(
  (ref) => ResumeDuJour(ref.watch(commandesDuJourProvider)),
);

final pointagesProvider = StreamProvider<List<Pointage>>((ref) {
  final base = ref.watch(baseProvider);
  return (base.select(base.pointages)
        ..orderBy([
          (p) => OrderingTerm(expression: p.date, mode: OrderingMode.desc),
          (p) => OrderingTerm(expression: p.id, mode: OrderingMode.desc),
        ]))
      .watch();
});

final lignesRapportProvider = StreamProvider<List<LigneRapport>>((ref) {
  final base = ref.watch(baseProvider);
  return base.select(base.lignesRapport).watch();
});

/// Un pointage déjà clôturé, rechiffré depuis ses propres lignes.
class PointageVue {
  final Pointage pointage;
  final List<LigneRapport> lignes;
  final Map<int, Commande> commandes;

  const PointageVue({
    required this.pointage,
    required this.lignes,
    required this.commandes,
  });

  /// Recalculé, jamais recopié du bas du rapport.
  int get du => lignes.fold(0, (somme, l) {
        final tarif = l.commandeId == null
            ? 0
            : commandes[l.commandeId!]?.tarifCoursier ?? 0;
        return somme + l.prix - tarif;
      });

  int get verse => pointage.verseReel;
  int get ecart => verse - du;
}

final pointagesVuesProvider = Provider<List<PointageVue>>((ref) {
  final pointages = ref.watch(pointagesProvider).valueOrNull;
  final lignes = ref.watch(lignesRapportProvider).valueOrNull;
  final instantane = ref.watch(instantaneProvider);
  if (pointages == null || lignes == null || instantane == null) {
    return const [];
  }

  final parPointage = <int, List<LigneRapport>>{};
  for (final l in lignes) {
    parPointage.putIfAbsent(l.pointageId, () => []).add(l);
  }
  final commandes = {for (final c in instantane.commandes) c.id: c};

  return pointages
      .map((p) => PointageVue(
            pointage: p,
            lignes: parPointage[p.id] ?? const [],
            commandes: commandes,
          ))
      .toList();
});
