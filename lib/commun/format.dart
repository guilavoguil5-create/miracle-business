/// Formatage des montants et des dates, en français.
///
/// Le franc guinéen n'a pas de décimales : tous les montants de l'app sont des
/// entiers, et se lisent par tranches de trois chiffres.
library;

/// 357300 -> "357 300"
String nombre(int valeur) {
  final negatif = valeur < 0;
  final chiffres = valeur.abs().toString();
  final tampon = StringBuffer();
  for (var i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) {
      tampon.write(' '); // espace fine insécable
    }
    tampon.write(chiffres[i]);
  }
  return negatif ? '-$tampon' : '$tampon';
}

/// 357300 -> "357 300 GNF"
String gnf(int montant) => '${nombre(montant)} GNF';

const _mois = <String>[
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

const _jours = <String>[
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

String _deux(int n) => n.toString().padLeft(2, '0');

/// 18/09
String dateCourte(DateTime d) => '${_deux(d.day)}/${_deux(d.month)}';

/// 18 septembre
String dateLongue(DateTime d) => '${d.day} ${_mois[d.month - 1]}';

/// jeudi 18 septembre
String dateAvecJour(DateTime d) =>
    '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';

/// Ramène une date à minuit, pour comparer des journées entre elles.
DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);

bool memeJour(DateTime a, DateTime b) => jour(a) == jour(b);
