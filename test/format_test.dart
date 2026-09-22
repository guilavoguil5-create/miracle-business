import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_business/commun/format.dart';

void main() {
  test('les montants se lisent par tranches de trois', () {
    expect(nombre(0), '0');
    expect(nombre(900), '900');
    expect(nombre(70000), '70 000');
    expect(nombre(357300), '357 300');
    expect(nombre(2600000), '2 600 000');
    expect(nombre(-11100), '-11 100');
  });

  test('un montant s\'affiche en francs guinéens, sans décimales', () {
    expect(gnf(250000), '250 000 GNF');
  });

  test('les dates s\'écrivent en français', () {
    final d = DateTime(2026, 9, 18);
    expect(dateCourte(d), '18/09');
    expect(dateLongue(d), '18 septembre');
    expect(dateAvecJour(d), 'vendredi 18 septembre');
  });

  test('deux moments de la même journée sont le même jour', () {
    expect(memeJour(DateTime(2026, 9, 18, 8), DateTime(2026, 9, 18, 22)), isTrue);
    expect(memeJour(DateTime(2026, 9, 18), DateTime(2026, 9, 19)), isFalse);
  });
}
