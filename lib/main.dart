import 'dart:collection';
import 'ad_helper.dart';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: Colors.deepOrange, // Vibrant orange for primary actions
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
    home: const FuelCostCalculator(),
  ));
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
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: const Text(
                            "Fuel Price",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
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
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                            dropdownColor: Colors.white,
                            items: fuelPriceDropDownValues.map((String items) {
                              return DropdownMenuItem(
                                value: items,
                                child: Text(items, style: const TextStyle(color: Colors.black87)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                fuelPriceDropDownValue = newValue!;
                              });
                              computeCost();
                            },
                          ),
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
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: const Text(
                            "Fuel Consumption",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
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
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                            dropdownColor: Colors.white,
                            items: fuelConsumptionDropDownValues.map((String items) {
                              return DropdownMenuItem(
                                value: items,
                                child: Text(items, style: const TextStyle(color: Colors.black87)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                fuelConsumptionDropDownValue = newValue!;
                              });
                              computeCost();
                            },
                          ),
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
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: const Text(
                            "Distance",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
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
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                            dropdownColor: Colors.white,
                            items: distanceDropDownValues.map((String items) {
                              return DropdownMenuItem(
                                value: items,
                                child: Text(items, style: const TextStyle(color: Colors.black87)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                distanceDropDownValue = newValue!;
                              });
                              computeCost();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Fourth row - Cost Result
                Card(
                  elevation: 3,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        const Text(
                          "Cost: ",
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
                      child: FilledButton.icon(
                        onPressed: () {
                          saveState();
                          ScaffoldMessenger.of(context).showSnackBar(
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
      costTextEditingController.text = "";
      return;
    }

    double fuelPrice = double.parse(fuelPriceTextEditingController.text);
    double fuelConsumption = double.parse(fuelConsumptionTextEditingController.text);
    double distance = double.parse(distanceTextEditingController.text);

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
}

