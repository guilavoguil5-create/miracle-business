import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/libelles.dart';
import '../commun/widgets.dart';
import '../donnees/base.dart';
import '../donnees/depot.dart';
import '../donnees/fournisseurs.dart';

int _entier(String texte) =>
    int.tryParse(texte.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

class EcranReglages extends ConsumerWidget {
  const EcranReglages({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instantane = ref.watch(instantaneProvider);
    final depot = ref.read(depotProvider);
    final theme = Theme.of(context);

    if (instantane == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Réglages')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Bloc(
            titre: 'Produits',
            action: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Ajouter un produit',
              onPressed: () => _ouvrirProduit(context, depot, null),
            ),
            enfant: Column(
              children: [
                for (final produit in instantane.produits)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(produit.nom),
                    subtitle: Text(
                      'Vendu ${gnf(produit.prixVente)} · '
                      'acheté ${gnf(produit.prixAchat)} · '
                      'marge ${gnf(produit.prixVente - produit.prixAchat)}'
                      '${produit.livraisonOfferte ? '\nLivraison offerte' : ''}',
                    ),
                    isThreeLine: produit.livraisonOfferte,
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _ouvrirProduit(context, depot, produit),
                  ),
              ],
            ),
          ),
          Bloc(
            titre: 'Zones de livraison',
            action: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Ajouter une zone',
              onPressed: () => _ouvrirZone(context, depot, null),
            ),
            enfant: Column(
              children: [
                for (final zone in instantane.zones)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(zone.nom),
                    subtitle: Text(
                      'La cliente paie ${gnf(zone.fraisCliente)} · '
                      'le coursier prend ${gnf(zone.tarifCoursier)}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _ouvrirZone(context, depot, zone),
                  ),
              ],
            ),
          ),
          Bloc(
            titre: 'Dépositaires',
            action: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Ajouter un dépositaire',
              onPressed: () => _ouvrirDepositaire(context, depot, null),
            ),
            enfant: Column(
              children: [
                for (final d in instantane.depositaires)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(d.nom),
                    subtitle: Text(
                      '${d.type.libelle} · ${d.reversement.libelle}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _ouvrirDepositaire(context, depot, d),
                  ),
              ],
            ),
          ),
          Bloc(
            titre: 'Vos données',
            enfant: Text(
              'Tout est enregistré sur ce téléphone, et l\'app marche sans '
              'connexion. La sauvegarde et l\'export arrivent dans la '
              'prochaine version.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _ouvrirProduit(
  BuildContext context,
  Depot depot,
  Produit? produit,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _DialogueProduit(depot: depot, produit: produit),
  );
}

Future<void> _ouvrirZone(
  BuildContext context,
  Depot depot,
  ZoneLivraison? zone,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _DialogueZone(depot: depot, zone: zone),
  );
}

Future<void> _ouvrirDepositaire(
  BuildContext context,
  Depot depot,
  Depositaire? depositaire,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _DialogueDepositaire(depot: depot, depositaire: depositaire),
  );
}

class _DialogueProduit extends StatefulWidget {
  final Depot depot;
  final Produit? produit;

  const _DialogueProduit({required this.depot, this.produit});

  @override
  State<_DialogueProduit> createState() => _DialogueProduitState();
}

class _DialogueProduitState extends State<_DialogueProduit> {
  late final _nom = TextEditingController(text: widget.produit?.nom ?? '');
  late final _vente = TextEditingController(
    text: widget.produit?.prixVente.toString() ?? '',
  );
  late final _achat = TextEditingController(
    text: widget.produit?.prixAchat.toString() ?? '',
  );
  late bool _offerte = widget.produit?.livraisonOfferte ?? false;

  @override
  void dispose() {
    _nom.dispose();
    _vente.dispose();
    _achat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.produit == null ? 'Nouveau produit' : 'Produit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nom,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vente,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Prix de vente (GNF)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _achat,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Prix d\'achat (GNF)'),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _offerte,
              onChanged: (v) => setState(() => _offerte = v),
              title: const Text('Livraison offerte'),
              subtitle: const Text(
                'La cliente ne paie pas les frais, le coursier prend quand '
                'même sa course.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () async {
            final navigateur = Navigator.of(context);
            await widget.depot.enregistrerProduit(
              id: widget.produit?.id,
              nom: _nom.text.trim(),
              prixVente: _entier(_vente.text),
              prixAchat: _entier(_achat.text),
              livraisonOfferte: _offerte,
            );
            navigateur.pop();
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _DialogueZone extends StatefulWidget {
  final Depot depot;
  final ZoneLivraison? zone;

  const _DialogueZone({required this.depot, this.zone});

  @override
  State<_DialogueZone> createState() => _DialogueZoneState();
}

class _DialogueZoneState extends State<_DialogueZone> {
  late final _nom = TextEditingController(text: widget.zone?.nom ?? '');
  late final _frais = TextEditingController(
    text: widget.zone?.fraisCliente.toString() ?? '',
  );
  late final _tarif = TextEditingController(
    text: widget.zone?.tarifCoursier.toString() ?? '',
  );

  @override
  void dispose() {
    _nom.dispose();
    _frais.dispose();
    _tarif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.zone == null ? 'Nouvelle zone' : 'Zone'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nom,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _frais,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ce que la cliente paie (GNF)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tarif,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ce que le coursier prend (GNF)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () async {
            final navigateur = Navigator.of(context);
            await widget.depot.enregistrerZone(
              id: widget.zone?.id,
              nom: _nom.text.trim(),
              fraisCliente: _entier(_frais.text),
              tarifCoursier: _entier(_tarif.text),
            );
            navigateur.pop();
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _DialogueDepositaire extends StatefulWidget {
  final Depot depot;
  final Depositaire? depositaire;

  const _DialogueDepositaire({required this.depot, this.depositaire});

  @override
  State<_DialogueDepositaire> createState() => _DialogueDepositaireState();
}

class _DialogueDepositaireState extends State<_DialogueDepositaire> {
  late final _nom = TextEditingController(text: widget.depositaire?.nom ?? '');
  late TypeDepositaire _type =
      widget.depositaire?.type ?? TypeDepositaire.coursier;
  late Reversement _reversement =
      widget.depositaire?.reversement ?? Reversement.quotidien;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.depositaire == null ? 'Nouveau dépositaire' : 'Dépositaire',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nom,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 16),
            ChampChoix<TypeDepositaire>(
              libelle: 'Type',
              valeur: _type,
              items: [
                for (final t in TypeDepositaire.values)
                  DropdownMenuItem(value: t, child: Text(t.libelle)),
              ],
              onChange: (t) => setState(() => _type = t ?? _type),
            ),
            const SizedBox(height: 16),
            ChampChoix<Reversement>(
              libelle: 'Reversement',
              valeur: _reversement,
              items: [
                for (final r in Reversement.values)
                  DropdownMenuItem(value: r, child: Text(r.libelle)),
              ],
              onChange: (r) => setState(() => _reversement = r ?? _reversement),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () async {
            final navigateur = Navigator.of(context);
            await widget.depot.enregistrerDepositaire(
              id: widget.depositaire?.id,
              nom: _nom.text.trim(),
              type: _type,
              reversement: _reversement,
            );
            navigateur.pop();
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
