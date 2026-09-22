import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/widgets.dart';
import '../donnees/fournisseurs.dart';
import 'detail_commande.dart';
import 'reglages.dart';

class EcranAujourdhui extends ConsumerWidget {
  const EcranAujourdhui({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = ref.watch(instantaneProvider) != null;
    final resume = ref.watch(resumeDuJourProvider);
    final soldes = ref.watch(soldesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aujourd\'hui'),
            Text(
              dateAvecJour(DateTime.now()),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EcranReglages()),
            ),
          ),
        ],
      ),
      body: !charge
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              children: [
                Bloc(
                  titre: 'La journée',
                  enfant: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Chiffre(
                          valeur: '${resume.nombre}',
                          libelle: resume.nombre > 1
                              ? 'commandes'
                              : 'commande',
                        ),
                      ),
                      Expanded(
                        child: Chiffre(
                          valeur: nombre(resume.encaisseAttendu),
                          libelle: 'à encaisser (GNF)',
                        ),
                      ),
                      Expanded(
                        child: Chiffre(
                          valeur: nombre(resume.marge),
                          libelle: 'de marge (GNF)',
                          couleur: resume.marge >= 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                if (resume.aConfier > 0)
                  Bloc(
                    enfant: Row(
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            color: theme.colorScheme.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${resume.aConfier} commande${resume.aConfier > 1 ? 's' : ''} '
                            'encore chez un dépositaire, pas encore remise'
                            '${resume.aConfier > 1 ? 's' : ''}.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                Bloc(
                  titre: 'Commandes du jour',
                  enfant: resume.commandes.isEmpty
                      ? Text(
                          'Rien pour l\'instant. Le bouton + en bas enregistre '
                          'une commande.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Column(
                          children: [
                            for (final vue in resume.commandes)
                              _LigneCommande(vue: vue),
                          ],
                        ),
                ),
                Bloc(
                  titre: 'Ce qu\'on vous doit',
                  enfant: Column(
                    children: [
                      for (final solde in soldes)
                        LigneMontant(
                          libelle: solde.depositaire.nom,
                          montant: solde.montant,
                          precision: solde.enAttente.isEmpty
                              ? 'rien en attente'
                              : '${solde.enAttente.length} commande'
                                  '${solde.enAttente.length > 1 ? 's' : ''} livrée'
                                  '${solde.enAttente.length > 1 ? 's' : ''}',
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LigneCommande extends StatelessWidget {
  final CommandeVue vue;

  const _LigneCommande({required this.vue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailCommande(commandeId: vue.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vue.commande.cliente,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vue.libelleProduits,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  gnf(vue.totalCliente),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                PuceEtat(vue.commande.etat),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
