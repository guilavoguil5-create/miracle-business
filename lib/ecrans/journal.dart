import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commun/format.dart';
import '../commun/libelles.dart';
import '../commun/widgets.dart';
import '../donnees/base.dart';
import '../donnees/fournisseurs.dart';
import 'detail_commande.dart';

class EcranJournal extends ConsumerStatefulWidget {
  const EcranJournal({super.key});

  @override
  ConsumerState<EcranJournal> createState() => _EcranJournalState();
}

class _EcranJournalState extends ConsumerState<EcranJournal> {
  EtatCommande? _filtre;
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final charge = ref.watch(instantaneProvider) != null;
    final toutes = ref.watch(commandesVuesProvider);

    final visibles = toutes.where((v) {
      if (_filtre != null && v.commande.etat != _filtre) return false;
      if (_recherche.isEmpty) return true;
      final terme = _recherche.toLowerCase();
      return v.commande.cliente.toLowerCase().contains(terme) ||
          v.libelleProduits.toLowerCase().contains(terme);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Chercher une cliente, un produit',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _recherche = v),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _Filtre(
                      libelle: 'Toutes',
                      actif: _filtre == null,
                      onTap: () => setState(() => _filtre = null),
                    ),
                    for (final etat in EtatCommande.values)
                      _Filtre(
                        libelle: etat.libelle,
                        actif: _filtre == etat,
                        onTap: () => setState(() => _filtre = etat),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: !charge
          ? const Center(child: CircularProgressIndicator())
          : visibles.isEmpty
              ? Vide(
                  icone: Icons.receipt_long_outlined,
                  titre: toutes.isEmpty
                      ? 'Aucune commande enregistrée'
                      : 'Rien ne correspond',
                  detail: toutes.isEmpty
                      ? 'Le bouton + en bas enregistre la première.'
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: visibles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final vue = visibles[i];
                    return ListTile(
                      title: Text(vue.commande.cliente),
                      subtitle: Text(
                        '${dateCourte(vue.commande.date)} · '
                        '${vue.libelleProduits}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(gnf(vue.totalCliente)),
                          const SizedBox(height: 4),
                          PuceEtat(vue.commande.etat),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DetailCommande(commandeId: vue.id),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _Filtre extends StatelessWidget {
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  const _Filtre({
    required this.libelle,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(libelle),
        selected: actif,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
