import 'package:flutter/material.dart';

import '../donnees/base.dart';
import 'format.dart';
import 'libelles.dart';

/// Pastille d'état d'une commande.
class PuceEtat extends StatelessWidget {
  final EtatCommande etat;

  const PuceEtat(this.etat, {super.key});

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final (fond, texte) = switch (etat) {
      EtatCommande.confiee => (couleurs.secondaryContainer, couleurs.onSecondaryContainer),
      EtatCommande.livree => (couleurs.tertiaryContainer, couleurs.onTertiaryContainer),
      EtatCommande.reversee => (couleurs.primaryContainer, couleurs.onPrimaryContainer),
      EtatCommande.annulee => (couleurs.surfaceContainerHighest, couleurs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etat.libelle,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: texte, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Un chiffre mis en avant, avec ce qu'il veut dire en dessous.
class Chiffre extends StatelessWidget {
  final String valeur;
  final String libelle;
  final Color? couleur;

  const Chiffre({
    required this.valeur,
    required this.libelle,
    this.couleur,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valeur,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: couleur,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          libelle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Carte sobre, utilisée partout pour grouper quelques lignes.
class Bloc extends StatelessWidget {
  final String? titre;
  final Widget enfant;
  final Widget? action;

  const Bloc({required this.enfant, this.titre, this.action, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titre != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      titre!,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            enfant,
          ],
        ),
      ),
    );
  }
}

/// Message affiché quand il n'y a rien à montrer.
class Vide extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String? detail;

  const Vide({
    required this.icone,
    required this.titre,
    this.detail,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(titre, style: theme.textTheme.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé ... montant ».
class LigneMontant extends StatelessWidget {
  final String libelle;
  final int montant;
  final bool gras;
  final String? precision;

  const LigneMontant({
    required this.libelle,
    required this.montant,
    this.gras = false,
    this.precision,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = gras
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelle, style: style),
                if (precision != null)
                  Text(
                    precision!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(gnf(montant), style: style),
        ],
      ),
    );
  }
}

/// Liste déroulante avec un libellé, posée sur le même cadre que les champs
/// de texte.
class ChampChoix<T> extends StatelessWidget {
  final String libelle;
  final T? valeur;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChange;

  const ChampChoix({
    required this.libelle,
    required this.valeur,
    required this.items,
    required this.onChange,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: libelle,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: valeur,
          items: items,
          onChanged: onChange,
        ),
      ),
    );
  }
}
