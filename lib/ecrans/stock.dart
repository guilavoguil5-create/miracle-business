import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/widgets.dart';
import '../donnees/fournisseurs.dart';

class EcranStock extends ConsumerWidget {
  const EcranStock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instantane = ref.watch(instantaneProvider);
    final lignes = ref.watch(stockProvider);
    final totaux = ref.watch(stockParProduitProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: instantane == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              children: [
                Bloc(
                  titre: 'Ce qui reste, en tout',
                  enfant: Column(
                    children: [
                      for (final produit in instantane.produits)
                        _LigneStock(
                          libelle: produit.nom,
                          quantite: totaux[produit.id] ?? 0,
                          gras: true,
                        ),
                    ],
                  ),
                ),
                for (final depositaire in instantane.depositaires)
                  Bloc(
                    titre: depositaire.nom,
                    enfant: Column(
                      children: [
                        for (final ligne in lignes.where(
                            (l) => l.depositaire.id == depositaire.id))
                          _LigneStock(
                            libelle: ligne.produit.nom,
                            quantite: ligne.quantite,
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'Le stock bouge tout seul : il descend quand une commande '
                    'est enregistrée, et remonte quand elle est annulée. '
                    'L\'arrivage et l\'inventaire arrivent dans la prochaine '
                    'version.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LigneStock extends StatelessWidget {
  final String libelle;
  final int quantite;
  final bool gras;

  const _LigneStock({
    required this.libelle,
    required this.quantite,
    this.gras = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = gras
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    final epuise = quantite <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(libelle, style: style)),
          Text(
            epuise ? 'épuisé' : '$quantite',
            style: style?.copyWith(
              color: epuise ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
