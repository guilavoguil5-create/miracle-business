import '../donnees/base.dart';

extension LibelleEtat on EtatCommande {
  String get libelle => switch (this) {
        EtatCommande.confiee => 'Confiée',
        EtatCommande.livree => 'Livrée',
        EtatCommande.reversee => 'Reversée',
        EtatCommande.annulee => 'Annulée',
      };

  /// Ce que l'état veut dire pour elle, en une ligne.
  String get explication => switch (this) {
        EtatCommande.confiee => 'Chez le dépositaire, pas encore remise',
        EtatCommande.livree => 'Remise à la cliente, argent pas encore reversé',
        EtatCommande.reversee => 'Argent reçu',
        EtatCommande.annulee => 'Annulée, stock remis',
      };
}

extension LibelleMode on ModeRemise {
  String get libelle => switch (this) {
        ModeRemise.livraison => 'Livraison',
        ModeRemise.retrait => 'Retrait en main propre',
      };
}

extension LibellePaiement on ModePaiement {
  String get libelle => switch (this) {
        ModePaiement.aLaLivraison => 'À la livraison',
        ModePaiement.mobileMoney => 'Mobile money',
      };
}

extension LibelleTypeDepositaire on TypeDepositaire {
  String get libelle => switch (this) {
        TypeDepositaire.coursier => 'Société de coursiers',
        TypeDepositaire.cousine => 'Cousine',
      };
}

extension LibelleReversement on Reversement {
  String get libelle => switch (this) {
        Reversement.quotidien => 'Reverse tous les jours',
        Reversement.surDemande => 'Reverse sur demande',
      };
}

extension LibelleMouvement on TypeMouvement {
  String get libelle => switch (this) {
        TypeMouvement.arrivage => 'Arrivage',
        TypeMouvement.repartition => 'Répartition',
        TypeMouvement.sortie => 'Sortie sur commande',
        TypeMouvement.retour => 'Retour',
        TypeMouvement.ajustement => 'Ajustement d\'inventaire',
      };
}
