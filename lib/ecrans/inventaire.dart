import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/widgets.dart';
import '../donnees/base.dart';
import '../donnees/fournisseurs.dart';

/// Inventaire d'un dépositaire : on compte ce qu'il a vraiment, et l'écart
/// avec ce que l'app calculait est écrit comme un mouvement, pour qu'on sache
/// plus tard d'où venait la correction.
class EcranInventaire extends ConsumerStatefulWidget {
  final int? depositaireId;

  const EcranInventaire({this.depositaireId, super.key});

  @override
  ConsumerState<EcranInventaire> createState() => _EcranInventaireState();
}

class _EcranInventaireState extends ConsumerState<EcranInventaire> {
  Depositaire? _depositaire;
  final Map<int, int> _comptes = {};
  bool _initialise = false;
  bool _enregistre = false;

  void _initialiser(Instantane i) {
    if (_initialise) return;
    _initialise = true;
    if (widget.depositaireId != null) {
      _depositaire = i.depositairesParId[widget.depositaireId];
    }
    _depositaire ??= i.depositaires.isEmpty ? null : i.depositaires.first;
  }

  int _calcule(int produitId) {
    final depositaire = _depositaire;
    if (depositaire == null) return 0;
    for (final ligne in ref.read(stockProvider)) {
      if (ligne.depositaire.id == depositaire.id &&
          ligne.produit.id == produitId) {
        return ligne.quantite;
      }
    }
    return 0;
  }

  int _compte(int produitId) => _comptes[produitId] ?? _calcule(produitId);

  Future<void> _enregistrer(Instantane i) async {
    final depositaire = _depositaire;
    if (depositaire == null) return;

    setState(() => _enregistre = true);
    final depot = ref.read(depotProvider);
    for (final produit in i.produits) {
      await depot.ajusterStock(
        chez: depositaire,
        produit: produit,
        quantiteComptee: _compte(produit.id),
        quantiteCalculee: _calcule(produit.id),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final instantane = ref.watch(instantaneProvider);
    if (instantane == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventaire')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _initialiser(instantane);

    final theme = Theme.of(context);
    var ecarts = 0;
    for (final produit in instantane.produits) {
      if (_compte(produit.id) != _calcule(produit.id)) ecarts++;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Inventaire')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Bloc(
            titre: 'Chez qui',
            enfant: ChampChoix<int>(
              libelle: 'Dépositaire',
              valeur: _depositaire?.id,
              items: [
                for (final d in instantane.depositaires)
                  DropdownMenuItem(value: d.id, child: Text(d.nom)),
              ],
              onChange: (id) => setState(() {
                _depositaire = instantane.depositairesParId[id];
                _comptes.clear();
              }),
            ),
          ),
          Bloc(
            titre: 'Ce qu\'il a vraiment',
            enfant: Column(
              children: [
                for (final produit in instantane.produits)
                  _LigneInventaire(
                    nom: produit.nom,
                    calcule: _calcule(produit.id),
                    compte: _compte(produit.id),
                    onChange: (v) => setState(
                      () => _comptes[produit.id] = v < 0 ? 0 : v,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _enregistre ? null : () => _enregistrer(instantane),
              icon: const Icon(Icons.check),
              label: Text(
                _enregistre
                    ? 'Enregistrement…'
                    : ecarts == 0
                        ? 'Tout concorde'
                        : 'Corriger $ecarts ligne${ecarts > 1 ? 's' : ''}',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Les écarts sont enregistrés comme des corrections d\'inventaire, '
              'pas effacés : on peut toujours savoir d\'où venait la différence.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneInventaire extends StatelessWidget {
  final String nom;
  final int calcule;
  final int compte;
  final ValueChanged<int> onChange;

  const _LigneInventaire({
    required this.nom,
    required this.calcule,
    required this.compte,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ecart = compte - calcule;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom, style: theme.textTheme.bodyLarge),
                Text(
                  ecart == 0
                      ? 'l\'app en comptait $calcule'
                      : 'l\'app en comptait $calcule, '
                          'écart de ${ecart > 0 ? '+' : ''}$ecart',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ecart == 0
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: compte > 0 ? () => onChange(compte - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$compte',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: () => onChange(compte + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
