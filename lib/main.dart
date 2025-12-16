import 'dart:collection';
import 'ad_helper.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  
  // Load dark mode preference
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('darkMode') ?? false;
  
  runApp(MyApp(isDarkMode: isDarkMode));
}

class MyApp extends StatefulWidget {
  final bool isDarkMode;
  
  const MyApp({super.key, required this.isDarkMode});

  @override
  State<MyApp> createState() => _MyAppState();
  
  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

// Global key for ScaffoldMessenger to show snackbars reliably
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  void toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Colors.deepOrange,
          onPrimary: Colors.white,
          secondary: Colors.deepOrange.shade700,
          onSecondary: Colors.white,
          tertiary: Colors.orange.shade300,
          onTertiary: Colors.black87,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
          surfaceContainerHighest: Colors.grey.shade100,
          primaryContainer: Colors.deepOrange.shade50,
          onPrimaryContainer: Colors.deepOrange.shade900,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: Colors.deepOrange,
          onPrimary: Colors.white,
          secondary: Colors.deepOrange.shade300,
          onSecondary: Colors.black87,
          tertiary: Colors.orange.shade700,
          onTertiary: Colors.white,
          error: Colors.red.shade300,
          onError: Colors.white,
          surface: Colors.grey.shade900,
          onSurface: Colors.white,
          surfaceContainerHighest: Colors.grey.shade800,
          primaryContainer: Colors.deepOrange.shade900,
          onPrimaryContainer: Colors.deepOrange.shade100,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const FuelCostCalculator(),
    );
  }
}

class FuelCostCalculator extends StatefulWidget {
  const FuelCostCalculator({super.key});

  @override
  State<FuelCostCalculator> createState() => _FuelCostCalculatorState();
}

class Region {
  String name;
  String fuelPriceUnits;
  String fuelConsumptionUnits;
  String distanceUnits;
  String costUnits;

  Region(this.name, this.fuelPriceUnits, this.fuelConsumptionUnits, this.distanceUnits, this.costUnits);
}

class _FuelCostCalculatorState extends State<FuelCostCalculator> {

  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );

    _bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  final Map<String, Region> regionMap = HashMap();

  bool check = false;

  String fuelPriceDropDownValue = "£ per litre";
  String fuelConsumptionDropDownValue = "mpg";
  String distanceDropDownValue = "miles";

  var fuelPriceDropDownValues = [
    "£ per litre",
    "\$ per gallon",
    "€ per litre",
    "\$ per litre",
    "Rs. per litre",
    "¥ per litre",
  ];
  var fuelConsumptionDropDownValues = [
    "mpg",
    "mpg (US)",
    "L/100km",
    "km/L",
    "L/mile",
  ];
  var distanceDropDownValues = [
    "miles",
    "km",
  ];

  final fuelPriceTextEditingController = TextEditingController();
  final fuelConsumptionTextEditingController = TextEditingController();
  final distanceTextEditingController = TextEditingController();
  final costTextEditingController = TextEditingController();
  
  double? _totalCost;
  double? _costPerUnit;
  int _numberOfPeople = 1;
  bool _showSplitOption = true;
  bool _isDetectingLocation = false;
  String? _detectedRegion;

  @override
  void initState() {
    super.initState();
    loadState();
    _loadBannerAd();
    regionMap["UK"]        = Region("UK",        "£ per litre",    "mpg",      "miles", "Cost (£)");
    regionMap["US"]        = Region("US",        "\$ per gallon",  "mpg (US)", "miles", "Cost (\$)");
    regionMap["Europe"]    = Region("Europe",    "€ per litre",    "L/100km",  "km",    "Cost (€)");
    regionMap["Australia"] = Region("Australia", "\$ per litre",   "L/100km",  "km",    "Cost (\$)");
    regionMap["India"]     = Region("India",     "Rs. per litre",  "L/100km",  "km",    "Cost (Rs.)");
    regionMap["China"]     = Region("China",     "¥ per litre",    "L/100km",  "km",    "Cost (¥)");
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      check = prefs.getBool("checkBox") ?? false;
      if (check == false) {
        displayHowToUsePrompt();
      }

      if (prefs.getString("fuelPriceDropDownValue") != null) {
        fuelPriceDropDownValue = prefs.getString("fuelPriceDropDownValue")!;
      }
      if (prefs.getString("fuelConsumptionDropDownValue") != null) {
        fuelConsumptionDropDownValue = prefs.getString("fuelConsumptionDropDownValue")!;
      }
      if (prefs.getString("distanceDropDownValue") != null) {
        distanceDropDownValue = prefs.getString("distanceDropDownValue")!;
      }
      if (prefs.getString("fuelPriceValue") != null) {
        fuelPriceTextEditingController.text = prefs.getString("fuelPriceValue")!;
      }
      if (prefs.getString("fuelConsumptionValue") != null) {
        fuelConsumptionTextEditingController.text = prefs.getString("fuelConsumptionValue")!;
      }
      if (prefs.getString("distanceValue") != null) {
        distanceTextEditingController.text = prefs.getString("distanceValue")!;
      }
      if (prefs.getString("costValue") != null) {
        costTextEditingController.text = prefs.getString("costValue")!;
      }
      _showSplitOption = prefs.getBool("showSplitOption") ?? false;
    });
  }

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Fuel Cost Calculator"),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
                // Reload preferences when returning from settings
                loadState();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // First row - Fuel Price
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Fuel Price",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 1.74',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                controller: fuelPriceTextEditingController,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                onChanged: (String? newValue) {
                                  computeCost();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: fuelPriceDropDownValue,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                dropdownColor: Theme.of(context).colorScheme.surface,
                                items: fuelPriceDropDownValues.map((String items) {
                                  return DropdownMenuItem(
                                    value: items,
                                    child: Text(
                                      items,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    fuelPriceDropDownValue = newValue!;
                                    _detectedRegion = null; // Reset when manually changed
                                  });
                                  computeCost();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Second row - Fuel Consumption
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Fuel Consumption",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 52.5',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                controller: fuelConsumptionTextEditingController,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                onChanged: (String? newValue) {
                                  computeCost();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: fuelConsumptionDropDownValue,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                dropdownColor: Theme.of(context).colorScheme.surface,
                                items: fuelConsumptionDropDownValues.map((String items) {
                                  return DropdownMenuItem(
                                    value: items,
                                    child: Text(
                                      items,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    fuelConsumptionDropDownValue = newValue!;
                                    _detectedRegion = null; // Reset when manually changed
                                  });
                                  computeCost();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Third row - Distance
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Distance",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 100',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                controller: distanceTextEditingController,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                onChanged: (String? newValue) {
                                  computeCost();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: distanceDropDownValue,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                dropdownColor: Theme.of(context).colorScheme.surface,
                                items: distanceDropDownValues.map((String items) {
                                  return DropdownMenuItem(
                                    value: items,
                                    child: Text(
                                      items,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    distanceDropDownValue = newValue!;
                                    _detectedRegion = null; // Reset when manually changed
                                  });
                                  computeCost();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showSplitOption) ...[
                  const SizedBox(height: 12),
                  // Fourth row - Split Cost
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Split Between",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton.outlined(
                                onPressed: _numberOfPeople > 1
                                    ? () {
                                        setState(() {
                                          _numberOfPeople--;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.remove),
                              ),
                              Expanded(
                                child: Text(
                                  "$_numberOfPeople ${_numberOfPeople == 1 ? 'person' : 'people'}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton.outlined(
                                onPressed: _numberOfPeople < 20
                                    ? () {
                                        setState(() {
                                          _numberOfPeople++;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Fifth row - Cost Result
                Card(
                  elevation: 3,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Total Cost: ",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: TextField(
                                controller: costTextEditingController,
                                enabled: false,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: costTextEditingController.text.isEmpty
                                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                      : Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Enter values above",
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_showSplitOption && _totalCost != null && _totalCost! > 0 && _numberOfPeople > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Cost per person:",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _getCostPerPersonDisplay(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_costPerUnit != null && _totalCost != null && _totalCost! > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Cost per ${distanceDropDownValue == "km" ? "km" : "mile"}: ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                                  ),
                                ),
                                Text(
                                  _getCostPerUnitDisplay(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Fifth row - Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text("Clear values?"),
                                content: const Text("Are you sure you want to clear all values?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      fuelPriceTextEditingController.clear();
                                      fuelConsumptionTextEditingController.clear();
                                      distanceTextEditingController.clear();
                                      costTextEditingController.clear();
                                      setState(() {
                                        _totalCost = null;
                                        _costPerUnit = null;
                                        _numberOfPeople = 1;
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Clear"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text("Clear"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _totalCost != null && _totalCost! > 0
                            ? _shareResults
                            : null,
                        icon: const Icon(Icons.share),
                        label: const Text("Share"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          saveState();
                          scaffoldMessengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text("Details saved successfully!"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text("Save"),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Add the banner ad code at the bottom
                if (_isBannerAdReady)
                  SizedBox(
                    width: _bannerAd.size.width.toDouble(),
                    height: _bannerAd.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void displayHowToUsePrompt() {
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: const Text("How to use"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 8),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("1. ", style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text("Select your units of choice from the dropdown menus."),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("2. ", style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text("Fill in the values for fuel price, fuel consumption and distance."),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Note: Values and units can be saved between sessions using the Save button.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Checkbox(
                        value: check,
                        onChanged: (bool? value){
                          setState(() {
                            check = value!;
                          });
                        },
                      ),
                      const Text("Don't show again"),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                FilledButton(
                  onPressed: () {
                    saveSwitchValue();
                    Navigator.pop(context);
                  },
                  child: const Text("Got it"),
                ),
              ],
            );
          });
        });
  }

  Future<void> saveSwitchValue() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("checkBox", check);
  }

  void computeCost() {
    if (fuelPriceTextEditingController.text.isEmpty ||
        fuelConsumptionTextEditingController.text.isEmpty ||
        distanceTextEditingController.text.isEmpty) {
      setState(() {
        costTextEditingController.text = "";
        _totalCost = null;
        _costPerUnit = null;
      });
      return;
    }

    // Validate and parse inputs with error handling
    double? fuelPrice = _parseDouble(fuelPriceTextEditingController.text);
    double? fuelConsumption = _parseDouble(fuelConsumptionTextEditingController.text);
    double? distance = _parseDouble(distanceTextEditingController.text);

    if (fuelPrice == null || fuelConsumption == null || distance == null) {
      setState(() {
        costTextEditingController.text = "";
        _totalCost = null;
        _costPerUnit = null;
      });
      return;
    }

    // Validate positive values
    if (fuelPrice <= 0 || fuelConsumption <= 0 || distance <= 0) {
      setState(() {
        costTextEditingController.text = "";
        _totalCost = null;
        _costPerUnit = null;
      });
      return;
    }

    // Converts all distances to miles
    double kmToMile = 0.6213711922;
    if (distanceDropDownValue == "km") {
      distance = distance * kmToMile;
    }

    double usMpgToImperialMpg = 1.2009499242;
    double lPer100kmToImperialMpg = 282.4809363;
    double kmPerLToImperialMpg = 2.824809363;
    double lpmToImperialMpg = 4.54609;

    double usGallonToLitre = 1 / 3.78541;
    double litreToImperialGallon = 1 / 0.2199692483;

    // Converts all fuel consumption to mpg (imperial)
    if (fuelConsumptionDropDownValue == "mpg (US)") {
      fuelConsumption = fuelConsumption * usMpgToImperialMpg;
    }
    else if (fuelConsumptionDropDownValue == "L/100km") {
      fuelConsumption = lPer100kmToImperialMpg / fuelConsumption;
    }
    else if (fuelConsumptionDropDownValue == "km/L") {
      fuelConsumption = fuelConsumption * kmPerLToImperialMpg;
    }
    else if (fuelConsumptionDropDownValue == "L/mile") {
      fuelConsumption = lpmToImperialMpg / fuelConsumption;
    }

    // Converts all fuel prices to per litres
    if (fuelPriceDropDownValue == "\$ per gallon") {
      fuelPrice = fuelPrice * usGallonToLitre;
    }

    fuelPrice = fuelPrice * litreToImperialGallon;

    // Convert all fuel prices to imperial gallon
    double calculation = fuelPrice * distance / fuelConsumption;
    double costPerUnit = calculation / distance;

    setState(() {
      _totalCost = calculation;
      _costPerUnit = costPerUnit;

      switch(fuelPriceDropDownValue) {
        case "£ per litre":
          costTextEditingController.text = "£${calculation.toStringAsFixed(2)}";
          break;
        case "\$ per gallon":
        case "\$ per litre":
          costTextEditingController.text = "\$${calculation.toStringAsFixed(2)}";
          break;
        case "€ per litre":
          costTextEditingController.text = "€${calculation.toStringAsFixed(2)}";
          break;
        case "Rs. per litre":
          costTextEditingController.text = "Rs. ${calculation.toStringAsFixed(2)}";
          break;
        case "¥ per litre":
          costTextEditingController.text = "¥${calculation.toStringAsFixed(2)}";
          break;
      }
    });
  }

  double? _parseDouble(String value) {
    if (value.isEmpty) return null;
    try {
      final parsed = double.parse(value);
      if (parsed.isNaN || parsed.isInfinite) return null;
      return parsed;
    } catch (e) {
      return null;
    }
  }

  String _getCurrencySymbol() {
    switch(fuelPriceDropDownValue) {
      case "£ per litre":
        return "£";
      case "\$ per gallon":
      case "\$ per litre":
        return "\$";
      case "€ per litre":
        return "€";
      case "Rs. per litre":
        return "Rs. ";
      case "¥ per litre":
        return "¥";
      default:
        return "";
    }
  }

  String _getCostPerUnitDisplay() {
    if (_costPerUnit == null) return "";
    String unit = distanceDropDownValue == "km" ? "km" : "mile";
    return "${_getCurrencySymbol()}${_costPerUnit!.toStringAsFixed(3)}/$unit";
  }

  String _getCostPerPersonDisplay() {
    if (_totalCost == null || _numberOfPeople <= 0) return "";
    double costPerPerson = _totalCost! / _numberOfPeople;
    return "${_getCurrencySymbol()}${costPerPerson.toStringAsFixed(2)}";
  }

  void _shareResults() {
    if (_totalCost == null || _totalCost! <= 0) return;

    String fuelPrice = fuelPriceTextEditingController.text;
    String fuelConsumption = fuelConsumptionTextEditingController.text;
    String distance = distanceTextEditingController.text;
    String cost = costTextEditingController.text;
    String costPerUnit = _getCostPerUnitDisplay();

    String splitInfo = "";
    if (_numberOfPeople > 1) {
      splitInfo = "\nSplit between $_numberOfPeople people: ${_getCostPerPersonDisplay()} each";
    }

    String shareText = """Fuel Cost Calculation

Fuel Price: $fuelPrice $fuelPriceDropDownValue
Fuel Consumption: $fuelConsumption $fuelConsumptionDropDownValue
Distance: $distance $distanceDropDownValue

Total Cost: $cost$splitInfo
Cost per ${distanceDropDownValue == "km" ? "km" : "mile"}: $costPerUnit

Calculated by Fuel Cost Calculator""";

    Clipboard.setData(ClipboardData(text: shareText));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Results copied to clipboard!"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("fuelPriceDropDownValue", fuelPriceDropDownValue);
    prefs.setString("fuelConsumptionDropDownValue", fuelConsumptionDropDownValue);
    prefs.setString("distanceDropDownValue", distanceDropDownValue);
    prefs.setString("fuelPriceValue", fuelPriceTextEditingController.text);
    prefs.setString("fuelConsumptionValue", fuelConsumptionTextEditingController.text);
    prefs.setString("distanceValue", distanceTextEditingController.text);
    prefs.setString("costValue", costTextEditingController.text);
  }

  Future<void> _detectLocationAndSetUnits() async {
    // Prevent multiple simultaneous requests
    if (_isDetectingLocation) return;
    
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled. Please enable them in settings.');
        return;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permissions are permanently denied. Please enable them in app settings.');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Get country from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        String? countryCode = placemarks[0].isoCountryCode;
        String? countryName = placemarks[0].country;
        
        _applyRegionSettings(countryCode, countryName);
      } else {
        _showLocationError('Could not determine your location.');
      }
    } catch (e) {
      _showLocationError('Error detecting location: ${e.toString()}');
    } finally {
      // Always reset the flag, even if widget is not mounted
      _isDetectingLocation = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _applyRegionSettings(String? countryCode, String? countryName) {
    String regionKey;
    
    // Map country codes to regions
    switch (countryCode?.toUpperCase()) {
      case 'GB':
      case 'UK':
        regionKey = 'UK';
        break;
      case 'US':
        regionKey = 'US';
        break;
      case 'AU':
        regionKey = 'Australia';
        break;
      case 'IN':
        regionKey = 'India';
        break;
      case 'CN':
        regionKey = 'China';
        break;
      // European countries
      case 'DE':
      case 'FR':
      case 'IT':
      case 'ES':
      case 'NL':
      case 'BE':
      case 'AT':
      case 'CH':
      case 'PT':
      case 'PL':
      case 'SE':
      case 'NO':
      case 'DK':
      case 'FI':
      case 'IE':
      case 'GR':
      case 'CZ':
      case 'HU':
      case 'RO':
      case 'BG':
      case 'HR':
      case 'SK':
      case 'SI':
      case 'LT':
      case 'LV':
      case 'EE':
      case 'LU':
      case 'MT':
      case 'CY':
        regionKey = 'Europe';
        break;
      // Countries using miles
      case 'MM': // Myanmar
      case 'LR': // Liberia
        regionKey = 'US'; // Use US as they use miles
        break;
      default:
        // Default to Europe for metric countries
        regionKey = 'Europe';
    }

    Region? region = regionMap[regionKey];
    if (region != null) {
      setState(() {
        fuelPriceDropDownValue = region.fuelPriceUnits;
        fuelConsumptionDropDownValue = region.fuelConsumptionUnits;
        distanceDropDownValue = region.distanceUnits;
        _detectedRegion = regionKey;
      });
      
      computeCost();
      
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Units set for $regionKey (${countryName ?? countryCode})'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showLocationError(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _LocationDetectionTile extends StatefulWidget {
  const _LocationDetectionTile();

  @override
  State<_LocationDetectionTile> createState() => _LocationDetectionTileState();
}

class _LocationDetectionTileState extends State<_LocationDetectionTile> {
  bool _isDetecting = false;

  Future<void> _detectLocation() async {
    if (_isDetecting) return;
    
    setState(() {
      _isDetecting = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable them in settings.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied. Please enable them in app settings.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        String? countryCode = placemarks[0].isoCountryCode;
        String? countryName = placemarks[0].country;
        
        _applyRegionSettings(countryCode, countryName);
      } else {
        _showError('Could not determine your location.');
      }
    } catch (e) {
      _showError('Error detecting location: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }

  void _applyRegionSettings(String? countryCode, String? countryName) {
    final regionMap = {
      'UK': Region('UK', '£ per litre', 'mpg', 'miles', 'Cost (£)'),
      'US': Region('US', '\$ per gallon', 'mpg (US)', 'miles', 'Cost (\$)'),
      'Europe': Region('Europe', '€ per litre', 'L/100km', 'km', 'Cost (€)'),
      'Australia': Region('Australia', '\$ per litre', 'L/100km', 'km', 'Cost (\$)'),
      'India': Region('India', 'Rs. per litre', 'L/100km', 'km', 'Cost (Rs.)'),
      'China': Region('China', '¥ per litre', 'L/100km', 'km', 'Cost (¥)'),
    };

    String regionKey;
    switch (countryCode?.toUpperCase()) {
      case 'GB':
      case 'UK':
        regionKey = 'UK';
        break;
      case 'US':
        regionKey = 'US';
        break;
      case 'AU':
        regionKey = 'Australia';
        break;
      case 'IN':
        regionKey = 'India';
        break;
      case 'CN':
        regionKey = 'China';
        break;
      case 'DE':
      case 'FR':
      case 'IT':
      case 'ES':
      case 'NL':
      case 'BE':
      case 'AT':
      case 'CH':
      case 'PT':
      case 'PL':
      case 'SE':
      case 'NO':
      case 'DK':
      case 'FI':
      case 'IE':
      case 'GR':
      case 'CZ':
      case 'HU':
      case 'RO':
      case 'BG':
      case 'HR':
      case 'SK':
      case 'SI':
      case 'LT':
      case 'LV':
      case 'EE':
      case 'LU':
      case 'MT':
      case 'CY':
        regionKey = 'Europe';
        break;
      case 'MM':
      case 'LR':
        regionKey = 'US';
        break;
      default:
        regionKey = 'Europe';
    }

    Region? region = regionMap[regionKey];
    if (region != null) {
      // Update main screen via shared preferences
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('fuelPriceDropDownValue', region.fuelPriceUnits);
        prefs.setString('fuelConsumptionDropDownValue', region.fuelConsumptionUnits);
        prefs.setString('distanceDropDownValue', region.distanceUnits);
      });

      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Units set for $regionKey (${countryName ?? countryCode}). Return to main screen to see changes.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showError(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _isDetecting
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : const Icon(Icons.my_location),
      title: const Text("Set Units from Location"),
      subtitle: const Text("Auto-detect your region's units"),
      trailing: const Icon(Icons.chevron_right),
      onTap: _isDetecting ? null : _detectLocation,
    );
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _showSplitOption = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _showSplitOption = prefs.getBool('showSplitOption') ?? false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    
    // Update the app theme
    MyApp.of(context)?.toggleDarkMode(value);
  }

  Future<void> _toggleSplitOption(bool value) async {
    setState(() {
      _showSplitOption = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showSplitOption', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          // App Settings Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              "App Settings",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text("Dark Mode"),
              subtitle: const Text("Toggle between light and dark theme"),
              value: _isDarkMode,
              onChanged: _toggleDarkMode,
              secondary: Icon(
                _isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text("Cost Splitting"),
              subtitle: const Text("Show option to split cost between people"),
              value: _showSplitOption,
              onChanged: _toggleSplitOption,
              secondary: const Icon(Icons.people),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _LocationDetectionTile(),
          ),
          
          const SizedBox(height: 24),
          
          // About Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              "About",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text("Fuel Cost Calculator"),
                  subtitle: const Text("Version 1.0.2"),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    "Calculate fuel costs for your journey with support for multiple currencies and units.",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

