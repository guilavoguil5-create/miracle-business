import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/libelles.dart';
import '../commun/widgets.dart';
import '../donnees/fournisseurs.dart';

class EcranArgent extends ConsumerWidget {
  const EcranArgent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instantane = ref.watch(instantaneProvider);
    final soldes = ref.watch(soldesProvider);
    final theme = Theme.of(context);
    final total = soldes.fold<int>(0, (s, x) => s + x.montant);

    return Scaffold(
      appBar: AppBar(title: const Text('Argent')),
      body: instantane == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              children: [
                Bloc(
                  titre: 'Dehors, en ce moment',
                  enfant: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chiffre(
                        valeur: gnf(total),
                        libelle: 'encaissé par vos dépositaires, '
                            'pas encore reversé',
                        couleur: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                for (final solde in soldes)
                  Bloc(
                    titre: solde.depositaire.nom,
                    action: Text(
                      solde.depositaire.reversement.libelle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    enfant: Column(
                      children: [
                        LigneMontant(
                          libelle: 'Doit vous reverser',
                          montant: solde.montant,
                          gras: true,
                        ),
                        if (solde.coutLivraisons > 0)
                          LigneMontant(
                            libelle: 'Dont courses déjà déduites',
                            montant: solde.coutLivraisons,
                          ),
                        const SizedBox(height: 8),
                        if (solde.enAttente.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Rien en attente.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          for (final vue in solde.enAttente)
                            LigneMontant(
                              libelle: vue.commande.cliente,
                              montant: vue.calcul.netAReverser,
                              precision:
                                  '${dateCourte(vue.commande.date)} · '
                                  '${vue.libelleProduits}',
                            ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'Le pointage du soir, qui compare le rapport du coursier à '
                    'vos commandes et met de côté les lignes de sa collègue, '
                    'arrive dans la prochaine version.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
    );
  }
}
