import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/libelles.dart';
import '../commun/widgets.dart';
import '../donnees/base.dart';
import '../donnees/depot.dart';
import '../donnees/fournisseurs.dart';

/// Saisie d'une commande.
///
/// La sortie de stock est écrite ici, au moment où la commande est confiée à un
/// dépositaire : c'est le seul endroit où elle se saisit, sinon le stock
/// affiché finit par ne plus rien vouloir dire.
class FicheCommande extends ConsumerStatefulWidget {
  const FicheCommande({super.key});

  @override
  ConsumerState<FicheCommande> createState() => _FicheCommandeState();
}

class _FicheCommandeState extends ConsumerState<FicheCommande> {
  final _cliente = TextEditingController();
  final _telephone = TextEditingController();
  final _adresse = TextEditingController();
  final _note = TextEditingController();

  ModeRemise _mode = ModeRemise.livraison;
  ModePaiement _paiement = ModePaiement.aLaLivraison;
  ZoneLivraison? _zone;
  Depositaire? _depositaire;
  bool _dejaServie = false;
  DateTime _date = DateTime.now();
  final Map<int, int> _quantites = {};

  bool _initialise = false;
  bool _enregistre = false;

  @override
  void dispose() {
    _cliente.dispose();
    _telephone.dispose();
    _adresse.dispose();
    _note.dispose();
    super.dispose();
  }

  void _initialiser(Instantane i) {
    if (_initialise) return;
    _initialise = true;
    _zone = i.zones.isEmpty ? null : i.zones.first;
    _depositaire = _depositairePour(_mode, i.depositaires);
  }

  /// Une livraison part chez les coursiers, un retrait chez la cousine.
  /// Elle peut toujours corriger juste en dessous.
  Depositaire? _depositairePour(ModeRemise mode, List<Depositaire> tous) {
    if (tous.isEmpty) return null;
    final voulu = mode == ModeRemise.livraison
        ? TypeDepositaire.coursier
        : TypeDepositaire.cousine;
    for (final d in tous) {
      if (d.type == voulu) return d;
    }
    return tous.first;
  }

  List<NouvelleLigne> _lignes(Instantane i) {
    final lignes = <NouvelleLigne>[];
    for (final produit in i.produits) {
      final quantite = _quantites[produit.id] ?? 0;
      if (quantite > 0) {
        lignes.add(NouvelleLigne(produit: produit, quantite: quantite));
      }
    }
    return lignes;
  }

  Future<void> _choisirDate() async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (choisie != null) {
      setState(() => _date = choisie);
    }
  }

  Future<void> _enregistrer(Instantane i) async {
    final lignes = _lignes(i);
    final messager = ScaffoldMessenger.of(context);

    if (_cliente.text.trim().isEmpty) {
      messager.showSnackBar(
        const SnackBar(content: Text('Il manque le nom de la cliente.')),
      );
      return;
    }
    if (lignes.isEmpty) {
      messager.showSnackBar(
        const SnackBar(content: Text('Il manque au moins un article.')),
      );
      return;
    }
    if (_depositaire == null) {
      messager.showSnackBar(
        const SnackBar(content: Text('Il manque le dépositaire.')),
      );
      return;
    }

    setState(() => _enregistre = true);
    await ref.read(depotProvider).creerCommande(
          date: _date,
          cliente: _cliente.text.trim(),
          telephone: _telephone.text.trim(),
          adresse: _adresse.text.trim(),
          depositaire: _depositaire!,
          zone: _mode == ModeRemise.livraison ? _zone : null,
          mode: _mode,
          paiement: _paiement,
          dejaServie: _dejaServie,
          lignes: lignes,
          note: _note.text.trim(),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final instantane = ref.watch(instantaneProvider);
    if (instantane == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _initialiser(instantane);

    final theme = Theme.of(context);
    final lignes = _lignes(instantane);
    final zone = _mode == ModeRemise.livraison ? _zone : null;
    final fraisCliente = Depot.fraisPourCliente(
      mode: _mode,
      zone: zone,
      lignes: lignes,
    );
    final tarifCoursier = Depot.tarifPourCoursier(mode: _mode, zone: zone);
    final totalProduits = lignes.fold(0, (s, l) => s + l.total);
    final offerte = _mode == ModeRemise.livraison &&
        lignes.any((l) => l.produit.livraisonOfferte);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle commande'),
        actions: [
          TextButton(
            onPressed: _enregistre ? null : () => _enregistrer(instantane),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Bloc(
            titre: 'La cliente',
            enfant: Column(
              children: [
                TextField(
                  controller: _cliente,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telephone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adresse,
                  decoration: const InputDecoration(labelText: 'Adresse'),
                ),
              ],
            ),
          ),
          Bloc(
            titre: 'Articles',
            enfant: Column(
              children: [
                for (final produit in instantane.produits)
                  _ChoixProduit(
                    produit: produit,
                    quantite: _quantites[produit.id] ?? 0,
                    stock: _stockDisponible(produit.id),
                    onChange: (q) => setState(() {
                      if (q <= 0) {
                        _quantites.remove(produit.id);
                      } else {
                        _quantites[produit.id] = q;
                      }
                    }),
                  ),
              ],
            ),
          ),
          Bloc(
            titre: 'Remise',
            enfant: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ModeRemise>(
                  segments: const [
                    ButtonSegment(
                      value: ModeRemise.livraison,
                      label: Text('Livraison'),
                      icon: Icon(Icons.local_shipping_outlined),
                    ),
                    ButtonSegment(
                      value: ModeRemise.retrait,
                      label: Text('Retrait'),
                      icon: Icon(Icons.storefront_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (choix) => setState(() {
                    _mode = choix.first;
                    _depositaire =
                        _depositairePour(_mode, instantane.depositaires);
                  }),
                ),
                if (_mode == ModeRemise.livraison) ...[
                  const SizedBox(height: 16),
                  ChampChoix<int>(
                    libelle: 'Zone',
                    valeur: _zone?.id,
                    items: [
                      for (final z in instantane.zones)
                        DropdownMenuItem(value: z.id, child: Text(z.nom)),
                    ],
                    onChange: (id) => setState(() {
                      _zone = instantane.zonesParId[id];
                    }),
                  ),
                ],
                const SizedBox(height: 16),
                ChampChoix<int>(
                  libelle: 'Confiée à',
                  valeur: _depositaire?.id,
                  items: [
                    for (final d in instantane.depositaires)
                      DropdownMenuItem(value: d.id, child: Text(d.nom)),
                  ],
                  onChange: (id) => setState(() {
                    _depositaire = instantane.depositairesParId[id];
                  }),
                ),
                const SizedBox(height: 16),
                ChampChoix<ModePaiement>(
                  libelle: 'Paiement',
                  valeur: _paiement,
                  items: [
                    for (final p in ModePaiement.values)
                      DropdownMenuItem(value: p, child: Text(p.libelle)),
                  ],
                  onChange: (p) => setState(() => _paiement = p ?? _paiement),
                ),
              ],
            ),
          ),
          Bloc(
            titre: 'Déjà servie',
            enfant: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _dejaServie,
                  onChanged: (v) => setState(() => _dejaServie = v),
                  title: const Text('La cliente a déjà été servie'),
                  subtitle: const Text(
                    'Pour une commande passée directement au coursier ou à la '
                    'cousine, enregistrée après coup.',
                  ),
                ),
                if (_dejaServie)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Date réelle'),
                    subtitle: Text(dateAvecJour(_date)),
                    trailing: TextButton(
                      onPressed: _choisirDate,
                      child: const Text('Changer'),
                    ),
                  ),
              ],
            ),
          ),
          Bloc(
            titre: 'Le compte',
            enfant: Column(
              children: [
                LigneMontant(libelle: 'Produits', montant: totalProduits),
                LigneMontant(
                  libelle: offerte
                      ? 'Livraison offerte à la cliente'
                      : 'Livraison payée par la cliente',
                  montant: fraisCliente,
                  precision: offerte
                      ? 'un article au moins est en livraison offerte'
                      : null,
                ),
                const Divider(),
                LigneMontant(
                  libelle: 'Ce que la cliente paie',
                  montant: totalProduits + fraisCliente,
                  gras: true,
                ),
                const SizedBox(height: 8),
                LigneMontant(
                  libelle: 'Course du coursier',
                  montant: -tarifCoursier,
                  precision: tarifCoursier == 0
                      ? 'aucune course à payer'
                      : 'due même quand la livraison est offerte',
                ),
              ],
            ),
          ),
          Bloc(
            titre: 'Note',
            enfant: TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ce qu\'il faut se rappeler sur cette commande',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _enregistre ? null : () => _enregistrer(instantane),
              icon: const Icon(Icons.check),
              label: Text(
                _enregistre ? 'Enregistrement…' : 'Enregistrer la commande',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'La marchandise sort du stock de '
              '${_depositaire?.nom ?? 'son dépositaire'} au moment de '
              'l\'enregistrement.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  int? _stockDisponible(int produitId) {
    final depositaire = _depositaire;
    if (depositaire == null) return null;
    for (final ligne in ref.read(stockProvider)) {
      if (ligne.depositaire.id == depositaire.id &&
          ligne.produit.id == produitId) {
        return ligne.quantite;
      }
    }
    return 0;
  }
}

class _ChoixProduit extends StatelessWidget {
  final Produit produit;
  final int quantite;
  final int? stock;
  final ValueChanged<int> onChange;

  const _ChoixProduit({
    required this.produit,
    required this.quantite,
    required this.stock,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manque = stock != null && quantite > stock!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produit.nom,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight:
                        quantite > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                Text(
                  '${gnf(produit.prixVente)}'
                  '${produit.livraisonOfferte ? ' · livraison offerte' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (manque)
                  Text(
                    'Il n\'y en a que $stock à cet endroit',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: quantite > 0 ? () => onChange(quantite - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantite',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: () => onChange(quantite + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
