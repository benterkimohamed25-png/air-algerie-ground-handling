import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AirAlgerieApp());
}

// =====================================================
// APPLICATION
// =====================================================

class AirAlgerieApp extends StatelessWidget {
  const AirAlgerieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Algérie Ground Handling',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00843D),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00843D),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF00843D),
          foregroundColor: Colors.white,
        ),
      ),
      home: const FlightsHomePage(),
    );
  }
}

// =====================================================
// FLIGHT MODEL
// =====================================================

class Flight {
  final String id;
  final String number;
  final String route;
  final String category;
  final String arrival;
  final String departure;
  final String notes;

  const Flight({
    required this.id,
    required this.number,
    required this.route,
    required this.category,
    required this.arrival,
    required this.departure,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'route': route,
      'category': category,
      'arrival': arrival,
      'departure': departure,
      'notes': notes,
    };
  }

  factory Flight.fromJson(Map<String, dynamic> json) {
    return Flight(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Arrivée',
      arrival: json['arrival']?.toString() ?? '',
      departure: json['departure']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

// =====================================================
// HOME PAGE
// =====================================================

class FlightsHomePage extends StatefulWidget {
  const FlightsHomePage({super.key});

  @override
  State<FlightsHomePage> createState() => _FlightsHomePageState();
}

class _FlightsHomePageState extends State<FlightsHomePage> {
  static const String _storageKey = 'air_algerie_flights';

  List<Flight> _flights = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFilter = 'Tous';

  final List<String> _filters = [
    'Tous',
    'Arrivée',
    'Départ',
  ];

  @override
  void initState() {
    super.initState();
    _loadFlights();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===================================================
  // LOAD FLIGHTS
  // ===================================================

  Future<void> _loadFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString(_storageKey);

      List<Flight> loadedFlights = [];

      if (savedData != null && savedData.isNotEmpty) {
        final decoded = jsonDecode(savedData);

        if (decoded is List) {
          loadedFlights = decoded
              .whereType<Map>()
              .map(
                (item) => Flight.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
      }

      if (!mounted) return;

      setState(() {
        _flights = loadedFlights;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _flights = [];
        _isLoading = false;
      });

      _showMessage('Erreur lors du chargement des vols.');
    }
  }

  // ===================================================
  // SAVE FLIGHTS
  // ===================================================

  Future<void> _saveFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String encodedData = jsonEncode(
        _flights.map((flight) => flight.toJson()).toList(),
      );

      await prefs.setString(_storageKey, encodedData);
    } catch (e) {
      _showMessage('Erreur lors de la sauvegarde des vols.');
    }
  }

  // ===================================================
  // SEARCH AND FILTER
  // ===================================================

  List<Flight> get _filteredFlights {
    final query = _searchQuery.toLowerCase().trim();

    return _flights.where((flight) {
      final matchesSearch =
          flight.number.toLowerCase().contains(query) ||
          flight.route.toLowerCase().contains(query) ||
          flight.category.toLowerCase().contains(query) ||
          flight.arrival.toLowerCase().contains(query) ||
          flight.departure.toLowerCase().contains(query) ||
          flight.notes.toLowerCase().contains(query);

      final matchesFilter = _selectedFilter == 'Tous' ||
          flight.category == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aTime = a.arrival.isNotEmpty ? a.arrival : a.departure;
        final bTime = b.arrival.isNotEmpty ? b.arrival : b.departure;

        return aTime.compareTo(bTime);
      });
  }

  // ===================================================
  // ADD FLIGHT
  // ===================================================

  Future<void> _addFlight() async {
    final Flight? flight = await showDialog<Flight>(
      context: context,
      builder: (context) => const FlightFormDialog(),
    );

    if (flight == null || !mounted) return;

    setState(() {
      _flights.add(flight);
    });

    await _saveFlights();

    if (!mounted) return;

    _showMessage('Vol ajouté avec succès.');
  }

  // ===================================================
  // EDIT FLIGHT
  // ===================================================

  Future<void> _editFlight(Flight flight) async {
    final Flight? updatedFlight = await showDialog<Flight>(
      context: context,
      builder: (context) => FlightFormDialog(
        flight: flight,
      ),
    );

    if (updatedFlight == null || !mounted) return;

    setState(() {
      final index = _flights.indexWhere(
        (item) => item.id == flight.id,
      );

      if (index != -1) {
        _flights[index] = updatedFlight;
      }
    });

    await _saveFlights();

    if (!mounted) return;

    _showMessage('Vol modifié avec succès.');
  }

  // ===================================================
  // DELETE FLIGHT
  // ===================================================

  Future<void> _deleteFlight(Flight flight) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer le vol'),
          content: Text(
            'Voulez-vous vraiment supprimer le vol ${flight.number} ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _flights.removeWhere(
        (item) => item.id == flight.id,
      );
    });

    await _saveFlights();

    if (!mounted) return;

    _showMessage('Vol supprimé.');
  }

  // ===================================================
  // MESSAGE
  // ===================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ===================================================
  // FLIGHT COLOR
  // ===================================================

  Color _categoryColor(String category) {
    if (category == 'Arrivée') {
      return Colors.blue;
    }

    if (category == 'Départ') {
      return Colors.deepOrange;
    }

    return Colors.green;
  }

  // ===================================================
  // FLIGHT CARD
  // ===================================================

  Widget _buildFlightCard(Flight flight) {
    final Color categoryColor = _categoryColor(flight.category);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editFlight(flight),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: categoryColor.withValues(alpha: 0.12),
                    child: Icon(
                      flight.category == 'Arrivée'
                          ? Icons.flight_land
                          : Icons.flight_takeoff,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flight.number,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          flight.route,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      flight.category,
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Options',
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editFlight(flight);
                      } else if (value == 'delete') {
                        _deleteFlight(flight);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('Supprimer'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInfo(
                      icon: Icons.flight_land,
                      label: 'Arrivée',
                      time: flight.arrival,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimeInfo(
                      icon: Icons.flight_takeoff,
                      label: 'Départ',
                      time: flight.departure,
                    ),
                  ),
                ],
              ),
              if (flight.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.notes,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(flight.notes),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required String label,
    required String time,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                time.isEmpty ? '--:--' : time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================================================
  // HOME PAGE BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final flights = _filteredFlights;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Air Algérie',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Ground Handling',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loadFlights,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF00843D),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestion des vols',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Nombre total de vols : ${_flights.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher un vol...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();

                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _filters.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _selectedFilter == filter,
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : flights.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadFlights,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(
                            top: 4,
                            bottom: 90,
                          ),
                          itemCount: flights.length,
                          itemBuilder: (context, index) {
                            return _buildFlightCard(flights[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlight,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un vol'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flight_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun vol trouvé',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                    ? 'Essayez de modifier votre recherche.'
                    : 'Appuyez sur le bouton pour ajouter un vol.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// FLIGHT FORM DIALOG
// =====================================================

class FlightFormDialog extends StatefulWidget {
  final Flight? flight;

  const FlightFormDialog({
    super.key,
    this.flight,
  });

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

  String _category = 'Arrivée';

  @override
  void initState() {
    super.initState();

    final flight = widget.flight;

    _number = TextEditingController(
      text: flight?.number ?? '',
    );

    _route = TextEditingController(
      text: flight?.route ?? '',
    );

    _arrival = TextEditingController(
      text: flight?.arrival ?? '',
    );

    _departure = TextEditingController(
      text: flight?.departure ?? '',
    );

    _notes = TextEditingController(
      text: flight?.notes ?? '',
    );

    _category = flight?.category ?? 'Arrivée';
  }

  @override
  void dispose() {
    _number.dispose();
    _route.dispose();
    _arrival.dispose();
    _departure.dispose();
    _notes.dispose();

    super.dispose();
  }

  // ===================================================
  // TIME PICKER
  // ===================================================

  Future<void> _selectTime(
    TextEditingController controller,
  ) async {
    final TimeOfDay initialTime = _parseTime(controller.text);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  TimeOfDay _parseTime(String value) {
    try {
      final parts = value.split(':');

      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        if (hour >= 0 &&
            hour <= 23 &&
            minute >= 0 &&
            minute <= 59) {
          return TimeOfDay(
            hour: hour,
            minute: minute,
          );
        }
      }
    } catch (_) {
      // Utiliser l'heure par défaut si la valeur est invalide.
    }

    return TimeOfDay.now();
  }

  // ===================================================
  // TEXT FIELD
  // ===================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    bool requiredField = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ce champ est obligatoire';
                }

                return null;
              }
            : null,
      ),
    );
  }

  // ===================================================
  // FORM BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.flight != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Modifier le vol' : 'Ajouter un vol',
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: _number,
                  label: 'Numéro du vol',
                  hint: 'Exemple : AH1010',
                  icon: Icons.confirmation_number_outlined,
                  requiredField: true,
                ),
                _buildTextField(
                  controller: _route,
                  label: 'Trajet',
                  hint: 'Exemple : ALG - CDG',
                  icon: Icons.route,
                  requiredField: true,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: 'Catégorie du vol',
                      prefixIcon: const Icon(Icons.flight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Arrivée',
                        child: Text('Arrivée'),
                      ),
                      DropdownMenuItem(
                        value: 'Départ',
                        child: Text('Départ'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _category = value;
                        });
                      }
                    },
                  ),
                ),
                _buildTextField(
                  controller: _arrival,
                  label: 'Heure d’arrivée',
                  hint: 'HH:MM',
                  icon: Icons.flight_land,
                  readOnly: true,
                  onTap: () => _selectTime(_arrival),
                ),
                _buildTextField(
                  controller: _departure,
                  label: 'Heure de départ',
                  hint: 'HH:MM',
                  icon: Icons.flight_takeoff,
                  readOnly: true,
                  onTap: () => _selectTime(_departure),
                ),
                _buildTextField(
                  controller: _notes,
                  label: 'Notes',
                  hint: 'Informations supplémentaires...',
                  icon: Icons.notes,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            final flight = Flight(
              id: widget.flight?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              number: _number.text.trim().toUpperCase(),
              route: _route.text.trim(),
              category: _category,
              arrival: _arrival.text.trim(),
              departure: _departure.text.trim(),
              notes: _notes.text.trim(),
            );

            Navigator.pop(context, flight);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
