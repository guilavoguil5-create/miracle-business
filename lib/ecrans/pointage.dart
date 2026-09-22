import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/widgets.dart';
import '../donnees/base.dart';
import '../donnees/fournisseurs.dart';
import 'fiche_commande.dart';

/// Pointage du soir.
///
/// Le rapport du coursier mélange ses commandes avec celles d'une collègue.
/// L'app ne reprend donc jamais les totaux du bas du rapport : elle part des
/// commandes qu'elle a saisies, lui fait cocher celles qui figurent bien sur le
/// rapport, et recalcule le dû à partir de ces seules lignes. Le surplus se
/// déduit ensuite de ce que le dépositaire a réellement versé.
class EcranPointage extends ConsumerStatefulWidget {
  final int? depositaireId;

  const EcranPointage({this.depositaireId, super.key});

  @override
  ConsumerState<EcranPointage> createState() => _EcranPointageState();
}

class _EcranPointageState extends ConsumerState<EcranPointage> {
  Depositaire? _depositaire;
  DateTime _date = DateTime.now();
  final Set<int> _retenues = {};
  final Map<int, int> _montants = {};
  final _verse = TextEditingController();
  bool _initialise = false;
  bool _enregistre = false;

  @override
  void dispose() {
    _verse.dispose();
    super.dispose();
  }

  void _initialiser(Instantane i) {
    if (_initialise) return;
    _initialise = true;
    if (widget.depositaireId != null) {
      _depositaire = i.depositairesParId[widget.depositaireId];
    }
    _depositaire ??= i.depositaires.isEmpty ? null : i.depositaires.first;
  }

  List<CommandeVue> _candidats(List<CommandeVue> toutes) {
    final depositaire = _depositaire;
    if (depositaire == null) return const [];
    final candidats = toutes
        .where((v) =>
            v.commande.depositaireId == depositaire.id &&
            (v.commande.etat == EtatCommande.confiee ||
                v.commande.etat == EtatCommande.livree))
        .toList();
    candidats.sort((a, b) => b.commande.date.compareTo(a.commande.date));
    return candidats;
  }

  /// Par défaut on coche les commandes du jour pointé : ce sont celles qui ont
  /// toutes les chances de figurer sur le rapport du soir.
  void _cocherParDefaut(List<CommandeVue> candidats) {
    _retenues
      ..clear()
      ..addAll(candidats
          .where((v) => memeJour(v.commande.date, _date))
          .map((v) => v.id));
    _montants.clear();
  }

  int _attendu(CommandeVue vue) => vue.calcul.encaisse;

  int _montantRapport(CommandeVue vue) => _montants[vue.id] ?? _attendu(vue);

  int _net(CommandeVue vue) =>
      _montantRapport(vue) - vue.commande.tarifCoursier;

  Future<void> _changerDate() async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (choisie != null) {
      setState(() => _date = choisie);
    }
  }

  Future<void> _corrigerMontant(CommandeVue vue) async {
    final controleur =
        TextEditingController(text: _montantRapport(vue).toString());
    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(vue.commande.cliente),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendu : ${gnf(_attendu(vue))}'),
            const SizedBox(height: 12),
            TextField(
              controller: controleur,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant porté sur le rapport (GNF)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (valide == true) {
      final valeur =
          int.tryParse(controleur.text.replaceAll(RegExp(r'[^0-9]'), ''));
      setState(() {
        if (valeur == null || valeur == _attendu(vue)) {
          _montants.remove(vue.id);
        } else {
          _montants[vue.id] = valeur;
        }
      });
    }
    controleur.dispose();
  }

  Future<void> _cloturer(List<CommandeVue> candidats) async {
    final depositaire = _depositaire;
    if (depositaire == null) return;
    final messager = ScaffoldMessenger.of(context);
    final retenues = candidats.where((v) => _retenues.contains(v.id)).toList();

    if (retenues.isEmpty) {
      messager.showSnackBar(
        const SnackBar(
          content: Text('Cochez au moins une commande du rapport.'),
        ),
      );
      return;
    }

    setState(() => _enregistre = true);
    await ref.read(depotProvider).cloturerPointage(
          date: _date,
          depositaire: depositaire,
          verseReel: _verseReel,
          retenues: [
            for (final vue in retenues)
              (
                commandeId: vue.id,
                cliente: vue.commande.cliente,
                montantRapport: _montantRapport(vue),
              ),
          ],
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  int get _verseReel =>
      int.tryParse(_verse.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final instantane = ref.watch(instantaneProvider);
    if (instantane == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pointage du soir')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _initialiser(instantane);

    final theme = Theme.of(context);
    final candidats = _candidats(ref.watch(commandesVuesProvider));
    final retenues = candidats.where((v) => _retenues.contains(v.id)).toList();
    final du = retenues.fold<int>(0, (s, v) => s + _net(v));
    final ecart = _verseReel - du;

    final oubliees = candidats
        .where((v) =>
            memeJour(v.commande.date, _date) && !_retenues.contains(v.id))
        .toList();
    final divergentes =
        retenues.where((v) => _montantRapport(v) != _attendu(v)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Pointage du soir')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Bloc(
            titre: 'Le pointage',
            enfant: Column(
              children: [
                ChampChoix<int>(
                  libelle: 'Dépositaire',
                  valeur: _depositaire?.id,
                  items: [
                    for (final d in instantane.depositaires)
                      DropdownMenuItem(value: d.id, child: Text(d.nom)),
                  ],
                  onChange: (id) => setState(() {
                    _depositaire = instantane.depositairesParId[id];
                    _initialise = true;
                    _cocherParDefaut(_candidats(
                      ref.read(commandesVuesProvider),
                    ));
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(dateAvecJour(_date)),
                  trailing: TextButton(
                    onPressed: () async {
                      await _changerDate();
                      if (!mounted) return;
                      setState(() => _cocherParDefaut(_candidats(
                            ref.read(commandesVuesProvider),
                          )));
                    },
                    child: const Text('Changer'),
                  ),
                ),
              ],
            ),
          ),
          Bloc(
            titre: 'Cochez ce qui figure sur son rapport',
            action: IconButton(
              tooltip: 'Une vente qui n\'est pas dans vos commandes',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FicheCommande(
                    depositaireInitial: _depositaire,
                    dejaServieInitial: true,
                  ),
                ),
              ),
            ),
            enfant: candidats.isEmpty
                ? Text(
                    'Aucune commande en attente chez ce dépositaire.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: [
                      for (final vue in candidats)
                        _LigneAPointer(
                          vue: vue,
                          coche: _retenues.contains(vue.id),
                          montantRapport: _montantRapport(vue),
                          attendu: _attendu(vue),
                          net: _net(vue),
                          onCoche: (v) => setState(() {
                            if (v) {
                              _retenues.add(vue.id);
                            } else {
                              _retenues.remove(vue.id);
                              _montants.remove(vue.id);
                            }
                          }),
                          onCorriger: () => _corrigerMontant(vue),
                        ),
                    ],
                  ),
          ),
          Bloc(
            titre: 'Le compte',
            enfant: Column(
              children: [
                LigneMontant(
                  libelle: 'Il devait vous reverser',
                  montant: du,
                  gras: true,
                  precision: '${retenues.length} commande'
                      '${retenues.length > 1 ? 's' : ''} retenue'
                      '${retenues.length > 1 ? 's' : ''}, '
                      'courses déjà déduites',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _verse,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Ce qu\'il a réellement versé (GNF)',
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                if (ecart == 0)
                  LigneMontant(
                    libelle: 'Le compte tombe juste',
                    montant: 0,
                    gras: true,
                  )
                else if (ecart > 0)
                  LigneMontant(
                    libelle: 'Il a versé en trop',
                    montant: ecart,
                    gras: true,
                    precision: 'à déduire de son prochain versement',
                  )
                else
                  LigneMontant(
                    libelle: 'Il vous doit encore',
                    montant: -ecart,
                    gras: true,
                  ),
              ],
            ),
          ),
          if (oubliees.isNotEmpty || divergentes.isNotEmpty)
            Bloc(
              titre: 'À vérifier',
              enfant: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final vue in oubliees)
                    _Alerte(
                      texte: '${vue.commande.cliente} : votre commande du jour '
                          'n\'apparaît pas sur son rapport.',
                    ),
                  for (final vue in divergentes)
                    _Alerte(
                      texte: '${vue.commande.cliente} : le rapport porte '
                          '${gnf(_montantRapport(vue))} au lieu de '
                          '${gnf(_attendu(vue))}.',
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed:
                  _enregistre ? null : () => _cloturer(candidats),
              icon: const Icon(Icons.check),
              label: Text(
                _enregistre ? 'Enregistrement…' : 'Clôturer le pointage',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Les commandes cochées passent en « reversée ». Les totaux écrits '
              'en bas de son rapport ne sont jamais repris : ils comptent aussi '
              'les commandes de sa collègue.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneAPointer extends StatelessWidget {
  final CommandeVue vue;
  final bool coche;
  final int montantRapport;
  final int attendu;
  final int net;
  final ValueChanged<bool> onCoche;
  final VoidCallback onCorriger;

  const _LigneAPointer({
    required this.vue,
    required this.coche,
    required this.montantRapport,
    required this.attendu,
    required this.net,
    required this.onCoche,
    required this.onCorriger,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diverge = montantRapport != attendu;

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: coche,
      onChanged: (v) => onCoche(v ?? false),
      title: Text(vue.commande.cliente),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dateCourte(vue.commande.date)} · ${vue.libelleProduits}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Rapport ${gnf(montantRapport)} · course '
            '${gnf(vue.commande.tarifCoursier)} · reste ${gnf(net)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: diverge
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      secondary: IconButton(
        tooltip: 'Corriger le montant du rapport',
        icon: const Icon(Icons.edit_outlined),
        onPressed: onCorriger,
      ),
    );
  }
}

class _Alerte extends StatelessWidget {
  final String texte;

  const _Alerte({required this.texte});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
