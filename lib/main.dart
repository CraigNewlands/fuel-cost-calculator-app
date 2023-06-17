import 'dart:collection';
import 'ad_helper.dart';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize(); //<-- SEE HERE
  runApp(MaterialApp(
    debugShowCheckedModeBanner:false,
    theme: ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.deepOrange,
      primaryColor: Colors.deepOrange,
    ),
    home: FuelCostCalculator(),
  ));
}

class FuelCostCalculator extends StatefulWidget {
  @override
  _FuelCostCalculatorState createState() => _FuelCostCalculatorState();
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
          backgroundColor: Colors.deepOrange,
          title: const Text("Fuel Cost Calculator"),
        ),
        body: Column(
          children: [
            // First row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Expanded(
                    flex: 6,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        "Fuel Price",
                        style: TextStyle(fontSize: 20),
                      ),
                    )
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: TextField(
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                          hintText: 'e.g. 1.74'
                      ),
                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                      controller: fuelPriceTextEditingController,
                      onChanged: (String? newValue) {
                        computeCost();
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton(
                        isExpanded: true,
                        style: const TextStyle(fontSize: 20, color: Colors.black),
                        value: fuelPriceDropDownValue,
                        items: fuelPriceDropDownValues.map((String items) {
                          return DropdownMenuItem(
                            value: items,
                            child: Text(items),
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
                  ),
                ),
              ],
            ),
            // Second row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Expanded(
                    flex: 6,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        "Fuel Consumption",
                        style: TextStyle(fontSize: 20),
                      ),
                    )
                ),
                Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: TextField(
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 20),
                        decoration: const InputDecoration(
                            hintText: 'e.g. 52.5'
                        ),
                        keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                        controller: fuelConsumptionTextEditingController,
                        onChanged: (String? newValue) {
                          computeCost();
                        },
                      ),
                    )
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton(
                        isExpanded: true,
                        style: const TextStyle(fontSize: 20, color: Colors.black),
                        value: fuelConsumptionDropDownValue,
                        items: fuelConsumptionDropDownValues.map((String items) {
                          return DropdownMenuItem(
                            value: items,
                            child: Text(items),
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
                  ),
                ),
              ],
            ),
            // Third row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Expanded(
                    flex: 6,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        "Distance",
                        style: TextStyle(fontSize: 20),
                      ),
                    )
                ),
                Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: TextField(
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 20),
                        decoration: const InputDecoration(
                            hintText: 'e.g. 100'
                        ),
                        keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                        controller: distanceTextEditingController,
                        onChanged: (String? newValue) {
                          computeCost();
                        },
                      ),
                    )
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton(
                        isExpanded: true,
                        style: const TextStyle(fontSize: 20, color: Colors.black),
                        value: distanceDropDownValue,
                        items: distanceDropDownValues.map((String items) {
                          return DropdownMenuItem(
                            value: items,
                            child: Text(items),
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
                  ),
                ),
              ],
            ),
            // Fourth row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Expanded(
                    flex: 13,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        "Cost",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    )
                ),
                Expanded(
                  flex: 17,
                  child: TextField(
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    enabled: false,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                    controller: costTextEditingController,
                  ),
                ),
                const Expanded(
                    flex: 0,
                    child: Text("")
                ),
              ],
            ),
            // Fifth row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ElevatedButton(
                        onPressed: () {
                          Widget cancelButton = TextButton(
                            child: const Text("No"),
                            onPressed:  () {Navigator.pop(context);},
                          );
                          Widget continueButton = TextButton(
                            child: const Text("Yes"),
                            onPressed:  () {
                              fuelPriceTextEditingController.clear();
                              fuelConsumptionTextEditingController.clear();
                              distanceTextEditingController.clear();
                              costTextEditingController.clear();
                              Navigator.pop(context);
                            },
                          );
                          AlertDialog alert = AlertDialog(
                            contentPadding: const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 0),
                            title: const Text("Clear values?"),
                            content: const Text("Are you sure you want to clear the values?"),
                            actions: [
                              cancelButton,
                              continueButton,
                            ],
                          );
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return alert;
                            },
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(7.0),
                          child: Text(
                            textAlign: TextAlign.center,
                            'CLEAR VALUES',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    )
                ),
                Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ElevatedButton(
                        onPressed: () {
                          saveState();
                          const snackBar = SnackBar(
                              content: Text(
                                "Details saved successfully!",
                              ));
                          scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(7.0),
                          child: Text(
                            textAlign: TextAlign.center,
                            'SAVE DETAILS',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    )
                ),
              ],
            ),
            // Add the banner ad code at the bottom
            if (_isBannerAdReady)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: _bannerAd.size.width.toDouble(),
                  height: _bannerAd.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd),
                ),
              ),
          ],
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
              contentPadding: const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 0),
              title: const Text("How to use"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("1. "),
                      Expanded(
                        child: Text("Select your units of choice from the drop down menus."),
                      ),
                    ],
                  ),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("2. "),
                      Expanded(
                        child: Text("Fill in the values for fuel price, fuel consumption and distance."),
                      ),
                    ],
                  ),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text("\nNote: values and units can be saved between sessions by using the \"save details\" button."),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Text("Don't show again"),
                      Checkbox(
                        value: check,
                        onChanged: (bool? value){
                          setState(() {
                            check = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("Ok"),
                  onPressed: () {
                    saveSwitchValue();
                    Navigator.pop(context);
                  },
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

