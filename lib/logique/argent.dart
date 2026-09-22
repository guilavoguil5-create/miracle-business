/// Les calculs d'argent de Miracle business.
///
/// Tout est en francs guinéens entiers. Ce fichier ne dépend ni de Flutter ni
/// de la base : il se teste seul.
///
/// Règle centrale du pointage : le rapport quotidien du coursier mélange les
/// commandes de Miracle business avec celles d'une collègue qui partage le même
/// abonnement. Les totaux imprimés en bas du rapport couvrent les deux
/// commerces, donc on ne les reprend JAMAIS. Tout est recalculé à partir des
/// seules lignes qui lui appartiennent, et le surplus se déduit de ce que le
/// dépositaire a réellement versé.
library;

/// Ce qu'une commande fait entrer et sortir.
class CalculCommande {
  /// Prix de vente cumulé des articles.
  final int totalProduits;

  /// Prix d'achat cumulé des mêmes articles, pour la marge.
  final int totalAchat;

  /// Frais de livraison payés par la cliente. Zéro si la livraison est offerte
  /// sur le produit, ou si la cliente vient retirer en main propre.
  final int fraisCliente;

  /// Tarif réclamé par le coursier. Il se paie par livraison et non par
  /// produit, et reste dû même quand la livraison est offerte à la cliente.
  /// Zéro pour un retrait chez la cousine.
  final int tarifCoursier;

  /// Commande déjà réglée d'avance en mobile money : le dépositaire n'a rien
  /// encaissé en main propre.
  final bool prepayee;

  const CalculCommande({
    required this.totalProduits,
    this.totalAchat = 0,
    this.fraisCliente = 0,
    this.tarifCoursier = 0,
    this.prepayee = false,
  });

  /// Ce que le dépositaire a réellement encaissé de la cliente.
  int get encaisse => prepayee ? 0 : totalProduits + fraisCliente;

  /// Ce que le dépositaire doit reverser pour cette commande.
  ///
  /// Le montant est négatif quand la commande était prépayée : le coursier n'a
  /// rien encaissé mais a quand même livré, donc c'est elle qui lui doit le
  /// tarif de la course.
  int get netAReverser => encaisse - tarifCoursier;

  /// Ce que la commande laisse une fois la marchandise et la course payées.
  int get marge => totalProduits + fraisCliente - totalAchat - tarifCoursier;
}

/// Résultat d'un pointage : ce que le dépositaire devait, ce qu'il a versé.
class ResultatPointage {
  /// Somme des nets des seules lignes retenues comme étant les siennes.
  final int duDuJour;

  /// Ce que le dépositaire a réellement versé.
  final int verseReel;

  const ResultatPointage({required this.duDuJour, required this.verseReel});

  /// Positif : il a versé plus que dû, le trop-versé est reporté en crédit.
  /// Négatif : il reste redevable.
  int get ecart => verseReel - duDuJour;

  bool get estSurplus => ecart > 0;
  bool get estResteDu => ecart < 0;
  bool get tombeJuste => ecart == 0;

  /// Trop-versé à reporter sur le prochain pointage.
  int get surplus => ecart > 0 ? ecart : 0;

  /// Ce qu'il doit encore.
  int get resteDu => ecart < 0 ? -ecart : 0;
}

/// Recalcule le pointage à partir des seules lignes retenues.
///
/// [lignesRetenues] ne contient que les commandes reconnues comme étant les
/// siennes : les lignes du rapport portant un produit hors de son catalogue ont
/// déjà été écartées en amont.
ResultatPointage calculerPointage({
  required Iterable<CalculCommande> lignesRetenues,
  required int verseReel,
}) {
  final du = lignesRetenues.fold<int>(0, (somme, l) => somme + l.netAReverser);
  return ResultatPointage(duDuJour: du, verseReel: verseReel);
}

/// Solde courant d'un dépositaire : ce qu'il doit encore, tous pointages
/// confondus. Positif = il lui doit de l'argent.
int soldeDepositaire({required int cumulDu, required int cumulVerse}) =>
    cumulDu - cumulVerse;

/// Les trois écarts qu'un pointage doit faire remonter.
enum TypeEcart {
  /// Une commande saisie dans l'app n'apparaît pas dans le rapport.
  absenteDuRapport,

  /// Une ligne du rapport n'a jamais été saisie comme commande.
  absenteDesCommandes,

  /// Les deux existent mais les montants ne se rejoignent pas.
  montantDivergent,
}

class Ecart {
  final TypeEcart type;
  final String cliente;
  final int? commandeId;
  final int? ligneRapportId;
  final int? montantCommande;
  final int? montantRapport;

  const Ecart({
    required this.type,
    required this.cliente,
    this.commandeId,
    this.ligneRapportId,
    this.montantCommande,
    this.montantRapport,
  });

  int get difference => (montantRapport ?? 0) - (montantCommande ?? 0);
}

/// Une commande saisie dans l'app, réduite à ce que le pointage compare.
class CommandeAPointer {
  final int id;
  final String cliente;
  final int encaisse;

  const CommandeAPointer({
    required this.id,
    required this.cliente,
    required this.encaisse,
  });
}

/// Une ligne du rapport du coursier, réduite de même.
class LigneRapportAPointer {
  final int id;
  final String cliente;
  final int encaisse;

  /// Commande de l'app à laquelle cette ligne a été rattachée, si elle l'a été.
  final int? commandeId;

  /// Faux quand la ligne a été écartée comme appartenant à la collègue.
  final bool incluse;

  const LigneRapportAPointer({
    required this.id,
    required this.cliente,
    required this.encaisse,
    this.commandeId,
    this.incluse = true,
  });
}

/// Compare les commandes saisies du jour aux lignes retenues du rapport.
///
/// Les lignes écartées (celles de la collègue) sont ignorées : elles n'ont pas
/// à produire d'écart.
List<Ecart> rapprocher({
  required List<CommandeAPointer> commandes,
  required List<LigneRapportAPointer> lignes,
}) {
  final retenues = lignes.where((l) => l.incluse).toList();
  final ecarts = <Ecart>[];
  final commandesRattachees = <int>{};
  final parId = <int, CommandeAPointer>{
    for (final c in commandes) c.id: c,
  };

  for (final ligne in retenues) {
    final id = ligne.commandeId;
    if (id == null) {
      ecarts.add(Ecart(
        type: TypeEcart.absenteDesCommandes,
        cliente: ligne.cliente,
        ligneRapportId: ligne.id,
        montantRapport: ligne.encaisse,
      ));
      continue;
    }
    commandesRattachees.add(id);
    final commande = parId[id];
    if (commande == null) {
      ecarts.add(Ecart(
        type: TypeEcart.absenteDesCommandes,
        cliente: ligne.cliente,
        ligneRapportId: ligne.id,
        montantRapport: ligne.encaisse,
      ));
    } else if (commande.encaisse != ligne.encaisse) {
      ecarts.add(Ecart(
        type: TypeEcart.montantDivergent,
        cliente: commande.cliente,
        commandeId: commande.id,
        ligneRapportId: ligne.id,
        montantCommande: commande.encaisse,
        montantRapport: ligne.encaisse,
      ));
    }
  }

  for (final commande in commandes) {
    if (!commandesRattachees.contains(commande.id)) {
      ecarts.add(Ecart(
        type: TypeEcart.absenteDuRapport,
        cliente: commande.cliente,
        commandeId: commande.id,
        montantCommande: commande.encaisse,
      ));
    }
  }

  return ecarts;
}

/// Ce qu'un arrivage a coûté et ce qu'il a rapporté.
class BilanArrivage {
  /// Prix d'achat de la marchandise reçue.
  final int coutMarchandise;

  /// Boosts Facebook lancés pour cet arrivage.
  final int coutBoosts;

  /// Encaissé sur les commandes servies depuis cet arrivage.
  final int encaisse;

  const BilanArrivage({
    required this.coutMarchandise,
    required this.coutBoosts,
    required this.encaisse,
  });

  int get coutTotal => coutMarchandise + coutBoosts;
  int get resultat => encaisse - coutTotal;
  bool get rentabilise => resultat >= 0;

  /// Ce qu'il reste à encaisser pour rentrer dans ses frais.
  int get resteAEncaisser => resultat >= 0 ? 0 : -resultat;
}
