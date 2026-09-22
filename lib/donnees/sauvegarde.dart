import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'base.dart';

String _deux(int n) => n.toString().padLeft(2, '0');

/// Prépare une copie de la base, prête à être envoyée.
///
/// La base tourne en mode WAL : une partie de ce qui vient d'être écrit peut
/// encore être dans le journal et pas dans le fichier principal. On force donc
/// l'écriture avant de recopier, sinon la sauvegarde serait en retard sur la
/// réalité.
Future<XFile> preparerSauvegarde(BaseMiracle base) async {
  await base.customStatement('PRAGMA wal_checkpoint(FULL)');

  final source = await fichierBase();
  if (!source.existsSync()) {
    throw const SauvegardeImpossible(
      'La base n\'a pas encore été créée sur ce téléphone.',
    );
  }

  final maintenant = DateTime.now();
  final nom = 'miracle-business-'
      '${maintenant.year}-${_deux(maintenant.month)}-${_deux(maintenant.day)}'
      '.sqlite';

  final dossier = await getTemporaryDirectory();
  final copie = await source.copy(p.join(dossier.path, nom));
  return XFile(copie.path, name: nom);
}

/// Ouvre le partage d'Android avec la sauvegarde en pièce jointe, pour qu'elle
/// puisse se l'envoyer là où elle veut.
Future<void> partagerSauvegarde(BaseMiracle base) async {
  final fichier = await preparerSauvegarde(base);
  await SharePlus.instance.share(
    ShareParams(
      files: [fichier],
      text: 'Sauvegarde Miracle business',
      subject: 'Sauvegarde Miracle business',
    ),
  );
}

class SauvegardeImpossible implements Exception {
  final String message;

  const SauvegardeImpossible(this.message);

  @override
  String toString() => message;
}
