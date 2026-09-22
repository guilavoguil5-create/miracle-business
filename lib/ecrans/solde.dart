import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/libelles.dart';
import '../commun/widgets.dart';
import '../donnees/fournisseurs.dart';
import 'pointage.dart';

/// Solde d'un dépositaire : ce qu'il doit aujourd'hui, et l'histoire des
/// pointages déjà clôturés.
class EcranSolde extends ConsumerWidget {
  final int depositaireId;

  const EcranSolde({required this.depositaireId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instantane = ref.watch(instantaneProvider);
    if (instantane == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final depositaire = instantane.depositairesParId[depositaireId];
    if (depositaire == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final soldes = ref.watch(soldesProvider);
    SoldeVue? solde;
    for (final s in soldes) {
      if (s.depositaire.id == depositaireId) {
        solde = s;
        break;
      }
    }

    final pointages = ref
        .watch(pointagesVuesProvider)
        .where((p) => p.pointage.depositaireId == depositaireId)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(depositaire.nom)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EcranPointage(depositaireId: depositaireId),
          ),
        ),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Pointer'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          Bloc(
            titre: 'En ce moment',
            enfant: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chiffre(
                  valeur: gnf(solde?.montant ?? 0),
                  libelle: 'encaissé et pas encore reversé',
                  couleur: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  depositaire.reversement.libelle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Bloc(
            titre: 'En attente',
            enfant: (solde == null || solde.enAttente.isEmpty)
                ? Text(
                    'Rien en attente.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: [
                      for (final vue in solde.enAttente)
                        LigneMontant(
                          libelle: vue.commande.cliente,
                          montant: vue.calcul.netAReverser,
                          precision: '${dateCourte(vue.commande.date)} · '
                              '${vue.libelleProduits}',
                        ),
                    ],
                  ),
          ),
          Bloc(
            titre: 'Pointages clôturés',
            enfant: pointages.isEmpty
                ? Text(
                    'Aucun pointage pour l\'instant.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: [
                      for (final p in pointages) _LignePointage(vue: p),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LignePointage extends StatelessWidget {
  final PointageVue vue;

  const _LignePointage({required this.vue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ecart = vue.ecart;
    final (libelle, couleur) = switch (ecart) {
      0 => ('le compte est tombé juste', theme.colorScheme.onSurfaceVariant),
      > 0 => ('versé en trop : ${gnf(ecart)}', theme.colorScheme.primary),
      _ => ('restait dû : ${gnf(-ecart)}', theme.colorScheme.error),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateAvecJour(vue.pointage.date),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(gnf(vue.verse)),
            ],
          ),
          Text(
            '${vue.lignes.length} commande'
            '${vue.lignes.length > 1 ? 's' : ''} · dû ${gnf(vue.du)} · '
            '$libelle',
            style: theme.textTheme.bodySmall?.copyWith(color: couleur),
          ),
        ],
      ),
    );
  }
}
