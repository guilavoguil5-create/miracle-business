import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_business/logique/argent.dart';

// Le vrai catalogue et le vrai barème, tels qu'ils ont été relevés avec elle.
const gelVente = 70000, gelAchat = 8000;
const savonVente = 60000, savonAchat = 27500;
const gammeVente = 180000, gammeAchat = 75600;
const kitVente = 250000, kitAchat = 150000;

const conakryFrais = 15000, conakryTarif = 33900;
const coyahFrais = 30000, coyahTarif = 33900;
const interieurFrais = 15000, interieurTarif = 40000;

void main() {
  group('marge d\'une commande d\'un seul article', () {
    // Ces quatre lignes reprennent le tableau de marges établi avec lucien.
    // Si un prix ou un tarif bouge, c'est ici que ça doit casser.
    test('gel anti-vergeture (livraison facturée)', () {
      int marge(int frais, int tarif) => CalculCommande(
            totalProduits: gelVente,
            totalAchat: gelAchat,
            fraisCliente: frais,
            tarifCoursier: tarif,
          ).marge;

      expect(marge(0, 0), 62000, reason: 'avant livraison');
      expect(marge(conakryFrais, conakryTarif), 43100, reason: 'Conakry');
      expect(marge(coyahFrais, coyahTarif), 58100, reason: 'Coyah et Dubréka');
      expect(marge(interieurFrais, interieurTarif), 37000, reason: 'intérieur');
    });

    test('savon Toudy (livraison facturée)', () {
      int marge(int frais, int tarif) => CalculCommande(
            totalProduits: savonVente,
            totalAchat: savonAchat,
            fraisCliente: frais,
            tarifCoursier: tarif,
          ).marge;

      expect(marge(0, 0), 32500);
      expect(marge(conakryFrais, conakryTarif), 13600);
      expect(marge(coyahFrais, coyahTarif), 28600);
      expect(marge(interieurFrais, interieurTarif), 7500);
    });

    test('gamme Toudy (livraison offerte : la cliente ne paie rien)', () {
      int marge(int tarif) => CalculCommande(
            totalProduits: gammeVente,
            totalAchat: gammeAchat,
            fraisCliente: 0,
            tarifCoursier: tarif,
          ).marge;

      expect(marge(0), 104400);
      expect(marge(conakryTarif), 70500);
      expect(marge(coyahTarif), 70500);
      expect(marge(interieurTarif), 64400);
    });

    test('kit fessier (livraison offerte)', () {
      int marge(int tarif) => CalculCommande(
            totalProduits: kitVente,
            totalAchat: kitAchat,
            fraisCliente: 0,
            tarifCoursier: tarif,
          ).marge;

      expect(marge(0), 100000);
      expect(marge(conakryTarif), 66100);
      expect(marge(coyahTarif), 66100);
      expect(marge(interieurTarif), 60000);
    });

    test('le savon seul ne porte pas sa livraison', () {
      // Constat retenu au cadrage : c'est un produit d'appoint.
      final savon = CalculCommande(
        totalProduits: savonVente,
        totalAchat: savonAchat,
        fraisCliente: conakryFrais,
        tarifCoursier: conakryTarif,
      );
      final gel = CalculCommande(
        totalProduits: gelVente,
        totalAchat: gelAchat,
        fraisCliente: conakryFrais,
        tarifCoursier: conakryTarif,
      );
      expect(savon.marge, lessThan(gel.marge ~/ 3));
    });
  });

  group('ce que le coursier encaisse et doit reverser', () {
    test('livraison payée à la cliente : produit plus frais, moins sa course',
        () {
      const c = CalculCommande(
        totalProduits: gelVente,
        fraisCliente: conakryFrais,
        tarifCoursier: conakryTarif,
      );
      expect(c.encaisse, 85000);
      expect(c.netAReverser, 51100);
    });

    test('commande prépayée en mobile money : c\'est elle qui doit la course',
        () {
      const c = CalculCommande(
        totalProduits: gelVente,
        fraisCliente: conakryFrais,
        tarifCoursier: conakryTarif,
        prepayee: true,
      );
      expect(c.encaisse, 0);
      expect(c.netAReverser, -conakryTarif);
    });

    test('retrait en main propre : pas de course à payer', () {
      const c = CalculCommande(totalProduits: gammeVente);
      expect(c.encaisse, gammeVente);
      expect(c.netAReverser, gammeVente);
    });

    test('la course se paie par livraison, pas par article', () {
      // Deux articles dans une même commande : un seul tarif coursier.
      const c = CalculCommande(
        totalProduits: gelVente + savonVente,
        fraisCliente: conakryFrais,
        tarifCoursier: conakryTarif,
      );
      expect(c.netAReverser, gelVente + savonVente + conakryFrais - conakryTarif);
    });
  });

  group('pointage du soir', () {
    test('le total des frais du rapport du 18/09 se retrouve', () {
      // 357 300 sur le rapport = 7 courses en ville + 3 vers l'intérieur.
      final frais = 7 * conakryTarif + 3 * interieurTarif;
      expect(frais, 357300);
    });

    test('il a versé pile ce qu\'il devait', () {
      const lignes = [
        CalculCommande(
            totalProduits: gelVente,
            fraisCliente: conakryFrais,
            tarifCoursier: conakryTarif),
        CalculCommande(
            totalProduits: gammeVente, tarifCoursier: conakryTarif),
      ];
      final du = 51100 + 146100;
      final r = calculerPointage(lignesRetenues: lignes, verseReel: du);
      expect(r.duDuJour, du);
      expect(r.tombeJuste, isTrue);
      expect(r.surplus, 0);
      expect(r.resteDu, 0);
    });

    test('il a versé trop : le surplus part en crédit', () {
      const lignes = [
        CalculCommande(
            totalProduits: gelVente,
            fraisCliente: conakryFrais,
            tarifCoursier: conakryTarif),
      ];
      final r = calculerPointage(lignesRetenues: lignes, verseReel: 61100);
      expect(r.duDuJour, 51100);
      expect(r.estSurplus, isTrue);
      expect(r.surplus, 10000);
      expect(r.resteDu, 0);
    });

    test('il a versé trop peu : il reste redevable', () {
      const lignes = [
        CalculCommande(
            totalProduits: gelVente,
            fraisCliente: conakryFrais,
            tarifCoursier: conakryTarif),
      ];
      final r = calculerPointage(lignesRetenues: lignes, verseReel: 40000);
      expect(r.estResteDu, isTrue);
      expect(r.resteDu, 11100);
      expect(r.surplus, 0);
    });

    test('les lignes de la collègue ne comptent pas dans son dû', () {
      // Seules les lignes retenues entrent dans le calcul : c'est tout l'enjeu
      // du rapport partagé.
      const sesLignes = [
        CalculCommande(
            totalProduits: gelVente,
            fraisCliente: conakryFrais,
            tarifCoursier: conakryTarif),
      ];
      final r = calculerPointage(lignesRetenues: sesLignes, verseReel: 51100);
      expect(r.duDuJour, 51100);
      expect(r.tombeJuste, isTrue);
    });
  });

  group('rapprochement commandes / rapport', () {
    test('tout concorde : aucun écart', () {
      final ecarts = rapprocher(
        commandes: const [
          CommandeAPointer(id: 1, cliente: 'Aminata', encaisse: 85000),
        ],
        lignes: const [
          LigneRapportAPointer(
              id: 10, cliente: 'Aminata', encaisse: 85000, commandeId: 1),
        ],
      );
      expect(ecarts, isEmpty);
    });

    test('une commande saisie manque au rapport', () {
      final ecarts = rapprocher(
        commandes: const [
          CommandeAPointer(id: 1, cliente: 'Aminata', encaisse: 85000),
        ],
        lignes: const [],
      );
      expect(ecarts, hasLength(1));
      expect(ecarts.single.type, TypeEcart.absenteDuRapport);
      expect(ecarts.single.cliente, 'Aminata');
    });

    test('une ligne du rapport n\'a jamais été saisie', () {
      final ecarts = rapprocher(
        commandes: const [],
        lignes: const [
          LigneRapportAPointer(id: 10, cliente: 'Fatou', encaisse: 85000),
        ],
      );
      expect(ecarts, hasLength(1));
      expect(ecarts.single.type, TypeEcart.absenteDesCommandes);
    });

    test('les montants ne se rejoignent pas', () {
      final ecarts = rapprocher(
        commandes: const [
          CommandeAPointer(id: 1, cliente: 'Aminata', encaisse: 85000),
        ],
        lignes: const [
          LigneRapportAPointer(
              id: 10, cliente: 'Aminata', encaisse: 70000, commandeId: 1),
        ],
      );
      expect(ecarts, hasLength(1));
      expect(ecarts.single.type, TypeEcart.montantDivergent);
      expect(ecarts.single.difference, -15000);
    });

    test('une ligne écartée ne produit aucun écart', () {
      final ecarts = rapprocher(
        commandes: const [],
        lignes: const [
          LigneRapportAPointer(
              id: 10, cliente: 'Cliente de la collègue', encaisse: 120000,
              incluse: false),
        ],
      );
      expect(ecarts, isEmpty);
    });
  });

  group('rentabilité d\'un arrivage', () {
    test('trois boosts pèsent autant que quatorze gels livrés à Conakry', () {
      // Repère donné à lucien : 600 000 de boosts = 14 gels à Conakry.
      const margeGelConakry = 43100;
      expect((600000 / margeGelConakry).ceil(), 14);
    });

    test('un arrivage pas encore rentabilisé', () {
      const b = BilanArrivage(
        coutMarchandise: 2000000,
        coutBoosts: 600000,
        encaisse: 1500000,
      );
      expect(b.coutTotal, 2600000);
      expect(b.rentabilise, isFalse);
      expect(b.resteAEncaisser, 1100000);
    });

    test('un arrivage rentabilisé', () {
      const b = BilanArrivage(
        coutMarchandise: 1000000,
        coutBoosts: 400000,
        encaisse: 1800000,
      );
      expect(b.rentabilise, isTrue);
      expect(b.resultat, 400000);
      expect(b.resteAEncaisser, 0);
    });
  });
}
