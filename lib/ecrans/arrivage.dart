import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/widgets.dart';
import '../donnees/base.dart';
import '../donnees/fournisseurs.dart';

/// Arrivage et répartition.
///
/// Elle ne garde pas de stock chez elle : dès qu'un arrivage arrive, il part
/// chez les dépositaires. La saisie se fait donc directement par dépositaire,
/// et ce qui est reçu est la somme de ce qui a été réparti.
class EcranArrivage extends ConsumerStatefulWidget {
  const EcranArrivage({super.key});

  @override
  ConsumerState<EcranArrivage> createState() => _EcranArrivageState();
}

class _EcranArrivageState extends ConsumerState<EcranArrivage> {
  DateTime _date = DateTime.now();
  final Map<({int produit, int depositaire}), int> _repartition = {};
  int _boosts = 0;
  final _note = TextEditingController();
  bool _enregistre = false;

  static const montantBoost = 200000;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int _quantite(int produitId, int depositaireId) =>
      _repartition[(produit: produitId, depositaire: depositaireId)] ?? 0;

  int _recu(int produitId, List<Depositaire> depositaires) => depositaires.fold(
        0,
        (somme, d) => somme + _quantite(produitId, d.id),
      );

  Future<void> _choisirDate() async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (choisie != null) setState(() => _date = choisie);
  }

  Future<void> _enregistrer(Instantane i) async {
    final messager = ScaffoldMessenger.of(context);

    final lignes = <({Produit produit, int quantite, int coutAchat})>[];
    final repartition = <({Depositaire chez, Produit produit, int quantite})>[];

    for (final produit in i.produits) {
      final recu = _recu(produit.id, i.depositaires);
      if (recu == 0) continue;
      lignes.add((
        produit: produit,
        quantite: recu,
        coutAchat: produit.prixAchat * recu,
      ));
      for (final d in i.depositaires) {
        final quantite = _quantite(produit.id, d.id);
        if (quantite > 0) {
          repartition.add((chez: d, produit: produit, quantite: quantite));
        }
      }
    }

    if (lignes.isEmpty) {
      messager.showSnackBar(
        const SnackBar(content: Text('Il manque la marchandise reçue.')),
      );
      return;
    }

    setState(() => _enregistre = true);
    await ref.read(depotProvider).creerArrivage(
          date: _date,
          lignes: lignes,
          repartition: repartition,
          boosts: List.filled(_boosts, montantBoost),
          note: _note.text.trim(),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final instantane = ref.watch(instantaneProvider);
    if (instantane == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Arrivage')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    var coutMarchandise = 0;
    for (final produit in instantane.produits) {
      coutMarchandise +=
          produit.prixAchat * _recu(produit.id, instantane.depositaires);
    }
    final coutBoosts = _boosts * montantBoost;

    return Scaffold(
      appBar: AppBar(title: const Text('Arrivage et répartition')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Bloc(
            titre: 'Quand',
            enfant: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(dateAvecJour(_date)),
              trailing: TextButton(
                onPressed: _choisirDate,
                child: const Text('Changer'),
              ),
            ),
          ),
          for (final produit in instantane.produits)
            Bloc(
              titre: produit.nom,
              action: Text(
                '${_recu(produit.id, instantane.depositaires)} reçu'
                '${_recu(produit.id, instantane.depositaires) > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              enfant: Column(
                children: [
                  for (final d in instantane.depositaires)
                    _Compteur(
                      libelle: d.nom,
                      valeur: _quantite(produit.id, d.id),
                      onChange: (v) => setState(() {
                        final cle =
                            (produit: produit.id, depositaire: d.id);
                        if (v <= 0) {
                          _repartition.remove(cle);
                        } else {
                          _repartition[cle] = v;
                        }
                      }),
                    ),
                ],
              ),
            ),
          Bloc(
            titre: 'Boosts Facebook',
            enfant: Column(
              children: [
                _Compteur(
                  libelle: '${gnf(montantBoost)} la semaine',
                  valeur: _boosts,
                  onChange: (v) => setState(() => _boosts = v < 0 ? 0 : v),
                ),
              ],
            ),
          ),
          Bloc(
            titre: 'Ce que cet arrivage coûte',
            enfant: Column(
              children: [
                LigneMontant(
                  libelle: 'Marchandise',
                  montant: coutMarchandise,
                ),
                LigneMontant(libelle: 'Boosts', montant: coutBoosts),
                const Divider(),
                LigneMontant(
                  libelle: 'Total',
                  montant: coutMarchandise + coutBoosts,
                  gras: true,
                  precision: 'à rentrer avant de gagner quoi que ce soit',
                ),
              ],
            ),
          ),
          Bloc(
            titre: 'Note',
            enfant: TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ce qu\'il faut se rappeler sur cet arrivage',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _enregistre ? null : () => _enregistrer(instantane),
              icon: const Icon(Icons.check),
              label: Text(
                _enregistre ? 'Enregistrement…' : 'Enregistrer l\'arrivage',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  final String libelle;
  final int valeur;
  final ValueChanged<int> onChange;

  const _Compteur({
    required this.libelle,
    required this.valeur,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(libelle, style: theme.textTheme.bodyMedium)),
        IconButton(
          onPressed: valeur > 0 ? () => onChange(valeur - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$valeur',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: () => onChange(valeur + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
