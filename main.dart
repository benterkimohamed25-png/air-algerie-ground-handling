import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AirAlgerieApp());

class AirAlgerieApp extends StatelessWidget {
  const AirAlgerieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Air Algérie Ground Handling',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, primary: Colors.red.shade800),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const FlightsHomePage(),
    );
  }
}

class Flight {
  String id;
  String number;
  String route;
  String category;
  String arrival;
  String departure;
  String notes;

  Flight({
    required this.id,
    required this.number,
    required this.route,
    required this.category,
    required this.arrival,
    required this.departure,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'number': number, 'route': route, 'category': category,
    'arrival': arrival, 'departure': departure, 'notes': notes,
  };

  factory Flight.fromJson(Map<String, dynamic> json) => Flight(
    id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
    number: json['number'] ?? '',
    route: json['route'] ?? '',
    category: json['category'] ?? 'Intérieure',
    arrival: json['arrival'] ?? '',
    departure: json['departure'] ?? '',
    notes: json['notes'] ?? '',
  );
}

class FlightsHomePage extends StatefulWidget {
  const FlightsHomePage({super.key});

  @override
  State<FlightsHomePage> createState() => _FlightsHomePageState();
}

class _FlightsHomePageState extends State<FlightsHomePage> {
  final List<Flight> _flights = [];
  final TextEditingController _search = TextEditingController();
  int _tab = 0;
  bool _loading = true;

  static const _storageKey = 'air_algerie_flights_v1';

  @override
  void initState() {
    super.initState();
    _loadFlights();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFlights() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _flights
          ..clear()
          ..addAll(decoded.map((e) => Flight.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {
        // Ignore a damaged local record and let the user continue.
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveFlights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_flights.map((f) => f.toJson()).toList()));
  }

  List<Flight> get _visibleFlights {
    final q = _search.text.trim().toLowerCase();
    return _flights.where((f) {
      final matchesTab = _tab == 0 ||
          (_tab == 1 && f.category == 'Intérieure') ||
          (_tab == 2 && f.category == 'Internationale') ||
          (_tab == 3 && f.category == 'Cargo');
      final matchesSearch = q.isEmpty ||
          f.number.toLowerCase().contains(q) ||
          f.route.toLowerCase().contains(q) ||
          f.notes.toLowerCase().contains(q);
      return matchesTab && matchesSearch;
    }).toList()
      ..sort((a, b) => a.departure.compareTo(b.departure));
  }

  Future<void> _openFlightForm({Flight? existing}) async {
    final result = await showDialog<Flight>(
      context: context,
      builder: (_) => FlightFormDialog(flight: existing),
    );
    if (result == null) return;
    setState(() {
      final index = _flights.indexWhere((f) => f.id == result.id);
      if (index >= 0) {
        _flights[index] = result;
      } else {
        _flights.add(result);
      }
    });
    await _saveFlights();
  }

  Future<void> _deleteFlight(Flight flight) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le vol ?'),
        content: Text('Voulez-vous supprimer ${flight.number} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _flights.removeWhere((f) => f.id == flight.id));
      await _saveFlights();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Tous les vols', 'Vols intérieurs', 'Vols internationaux', 'Cargo'];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        title: const Text('Air Algérie • Ground Handling', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Ajouter un vol',
            onPressed: () => _openFlightForm(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                color: Colors.red.shade900,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flight_takeoff, color: Colors.white, size: 42),
                    SizedBox(height: 12),
                    Text('Gestion Sol & Vols', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Application personnelle', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Ajouter un vol'),
                onTap: () { Navigator.pop(context); _openFlightForm(); },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('À propos'),
                subtitle: const Text('Les vols sont enregistrés sur ce téléphone.'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Air Algérie Ground Handling',
                  applicationVersion: '1.0.0',
                  children: const [Text('Version initiale : saisie manuelle et stockage local.')],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un vol, une destination...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(titles[_tab], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      Text('${_visibleFlights.length} vol(s)', style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                Expanded(
                  child: _visibleFlights.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flight, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Aucun vol enregistré', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                const Text('Appuyez sur + pour ajouter votre premier vol.', textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                FilledButton.icon(onPressed: () => _openFlightForm(), icon: const Icon(Icons.add), label: const Text('Ajouter un vol')),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _visibleFlights.length,
                          itemBuilder: (context, index) {
                            final flight = _visibleFlights[index];
                            return Card(
                              color: Colors.white,
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.shade50,
                                  child: Icon(flight.category == 'Cargo' ? Icons.inventory_2 : Icons.flight, color: Colors.red.shade800),
                                ),
                                title: Text('${flight.number} • ${flight.route}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${flight.category}\nArrivée : ${flight.arrival.isEmpty ? '—' : flight.arrival}   |   Départ : ${flight.departure.isEmpty ? '—' : flight.departure}'
                                    '${flight.notes.isEmpty ? '' : '\nNote : ${flight.notes}'}',
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') _openFlightForm(existing: flight);
                                    if (value == 'delete') _deleteFlight(flight);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        onPressed: () => _openFlightForm(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Tous'),
          NavigationDestination(icon: Icon(Icons.flight_land), label: 'Intérieur'),
          NavigationDestination(icon: Icon(Icons.public), label: 'International'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Cargo'),
        ],
      ),
    );
  }
}

class FlightFormDialog extends StatefulWidget {
  final Flight? flight;
  const FlightFormDialog({super.key, this.flight});

  @override
  State<FlightFormDialog> createState() => _FlightFormDialogState();
}

class _FlightFormDialogState extends State<FlightFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _route;
  late final TextEditingController _arrival;
  late final TextEditingController _departure;
  late final TextEditingController _notes;
  late String _category;

  @override
  void initState() {
    super.initState();
    final f = widget.flight;
    _number = TextEditingController(text: f?.number ?? '');
    _route = TextEditingController(text: f?.route ?? '');
    _arrival = TextEditingController(text: f?.arrival ?? '');
    _departure = TextEditingController(text: f?.departure ?? '');
    _notes = TextEditingController(text: f?.notes ?? '');
    _category = f?.category ?? 'Intérieure';
  }

  @override
  void dispose() {
    _number.dispose(); _route.dispose(); _arrival.dispose(); _departure.dispose(); _notes.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.flight == null ? 'Ajouter un vol' : 'Modifier le vol'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _number,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _decoration('Numéro du vol *', 'Ex. AH1003'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Saisissez le numéro du vol' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _route,
                  decoration: _decoration('Trajet / destination *', 'Ex. Alger - Oran'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Saisissez la destination' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: _decoration('Catégorie', ''),
                  items: const [
                    DropdownMenuItem(value: 'Intérieure', child: Text('Intérieure')),
                    DropdownMenuItem(value: 'Internationale', child: Text('Internationale')),
                    DropdownMenuItem(value: 'Cargo', child: Text('Cargo')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'Intérieure'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _arrival,
                  decoration: _decoration('Heure d’arrivée', 'Ex. 16:00'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _departure,
                  decoration: _decoration('Heure de départ', 'Ex. 18:30'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: _decoration('Notes (facultatif)', 'Porte, remarques...'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, Flight(
              id: widget.flight?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
              number: _number.text.trim().toUpperCase(),
              route: _route.text.trim(),
              category: _category,
              arrival: _arrival.text.trim(),
              departure: _departure.text.trim(),
              notes: _notes.text.trim(),
            ));
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
