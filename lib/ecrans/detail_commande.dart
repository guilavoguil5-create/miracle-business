import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/libelles.dart';
import '../commun/widgets.dart';
import '../donnees/base.dart';
import '../donnees/fournisseurs.dart';

class DetailCommande extends ConsumerWidget {
  final int commandeId;

  const DetailCommande({required this.commandeId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vues = ref.watch(commandesVuesProvider);
    CommandeVue? vue;
    for (final v in vues) {
      if (v.id == commandeId) {
        vue = v;
        break;
      }
    }

    if (vue == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final commande = vue.commande;
    final calcul = vue.calcul;
    final theme = Theme.of(context);
    final offerte = commande.mode == ModeRemise.livraison &&
        commande.fraisCliente == 0 &&
        commande.tarifCoursier > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(commande.cliente),
        actions: [PuceEtat(commande.etat), const SizedBox(width: 16)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Bloc(
            titre: 'La cliente',
            enfant: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(commande.cliente, style: theme.textTheme.bodyLarge),
                if (commande.telephone.isNotEmpty) Text(commande.telephone),
                if (commande.adresse.isNotEmpty) Text(commande.adresse),
                const SizedBox(height: 8),
                Text(
                  '${commande.mode.libelle} · '
                  '${vue.depositaire?.nom ?? 'dépositaire supprimé'}'
                  '${vue.zone != null ? ' · ${vue.zone!.nom}' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  commande.paiement.libelle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (commande.dejaServie)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Commande passée directement auprès du dépositaire, '
                      'enregistrée après coup.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.secondary),
                    ),
                  ),
                if (commande.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(commande.note),
                  ),
              ],
            ),
          ),
          Bloc(
            titre: 'Articles',
            enfant: Column(
              children: [
                for (final ligne in vue.lignes)
                  LigneMontant(
                    libelle: vue.produits[ligne.produitId]?.nom ??
                        'Produit supprimé',
                    montant: ligne.prixUnitaire * ligne.quantite,
                    precision: ligne.quantite > 1
                        ? '${ligne.quantite} × ${gnf(ligne.prixUnitaire)}'
                        : null,
                  ),
              ],
            ),
          ),
          Bloc(
            titre: 'L\'argent',
            enfant: Column(
              children: [
                LigneMontant(libelle: 'Produits', montant: vue.totalProduits),
                LigneMontant(
                  libelle: offerte
                      ? 'Livraison offerte à la cliente'
                      : 'Livraison payée par la cliente',
                  montant: commande.fraisCliente,
                ),
                const Divider(),
                LigneMontant(
                  libelle: 'Ce que la cliente paie',
                  montant: vue.totalCliente,
                  gras: true,
                ),
                const SizedBox(height: 8),
                LigneMontant(
                  libelle: 'Course du coursier',
                  montant: -commande.tarifCoursier,
                  precision: commande.tarifCoursier == 0
                      ? 'aucune course à payer'
                      : 'due même quand la livraison est offerte',
                ),
                if (calcul.prepayee)
                  LigneMontant(
                    libelle: 'Déjà réglé en mobile money',
                    montant: -vue.totalCliente,
                    precision: 'le dépositaire n\'a rien encaissé',
                  ),
                const Divider(),
                LigneMontant(
                  libelle: calcul.netAReverser >= 0
                      ? 'À vous reverser'
                      : 'Que vous devez au coursier',
                  montant: calcul.netAReverser.abs(),
                  gras: true,
                ),
                const SizedBox(height: 8),
                LigneMontant(
                  libelle: 'Marge',
                  montant: calcul.marge,
                  precision: 'une fois la marchandise et la course payées',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._actions(context, ref, commande),
        ],
      ),
    );
  }

  List<Widget> _actions(
      BuildContext context, WidgetRef ref, Commande commande) {
    final depot = ref.read(depotProvider);

    Future<void> changer(EtatCommande etat) async {
      await depot.changerEtat(commande.id, etat);
    }

    Future<void> annuler() async {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Annuler cette commande ?'),
          content: const Text(
            'La marchandise revient dans le stock du dépositaire.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Non'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Oui, annuler'),
            ),
          ],
        ),
      );
      if (confirme == true) {
        await depot.annulerCommande(commande.id);
      }
    }

    return [
      if (commande.etat == EtatCommande.confiee)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: FilledButton.icon(
            onPressed: () => changer(EtatCommande.livree),
            icon: const Icon(Icons.check),
            label: const Text('La cliente a été servie'),
          ),
        ),
      if (commande.etat == EtatCommande.livree)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: FilledButton.icon(
            onPressed: () => changer(EtatCommande.reversee),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('J\'ai reçu l\'argent'),
          ),
        ),
      if (commande.etat != EtatCommande.annulee)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: OutlinedButton.icon(
            onPressed: annuler,
            icon: const Icon(Icons.close),
            label: const Text('Annuler la commande'),
          ),
        ),
    ];
  }
}
