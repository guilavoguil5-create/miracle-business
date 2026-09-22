import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ecrans/accueil.dart';
import 'ecrans/argent.dart';
import 'ecrans/fiche_commande.dart';
import 'ecrans/journal.dart';
import 'ecrans/stock.dart';

void main() {
  runApp(const ProviderScope(child: AppMiracle()));
}

class AppMiracle extends StatelessWidget {
  const AppMiracle({super.key});

  @override
  Widget build(BuildContext context) {
    final couleurs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9C5C3C),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Miracle business',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: couleurs,
        scaffoldBackgroundColor: couleurs.surface,
        cardTheme: CardThemeData(
          elevation: 0,
          color: couleurs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: couleurs.surface,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const Coque(),
    );
  }
}

/// La coque de l'app : quatre onglets et le bouton + toujours à portée.
class Coque extends StatefulWidget {
  const Coque({super.key});

  @override
  State<Coque> createState() => _CoqueState();
}

class _CoqueState extends State<Coque> {
  int _onglet = 0;

  static const _pages = <Widget>[
    EcranAujourdhui(),
    EcranJournal(),
    EcranStock(),
    EcranArgent(),
  ];

  Future<void> _nouvelleCommande() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FicheCommande()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _onglet, children: _pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouvelleCommande,
        icon: const Icon(Icons.add),
        label: const Text('Commande'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (i) => setState(() => _onglet = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Aujourd\'hui',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Argent',
          ),
        ],
      ),
    );
  }
}
