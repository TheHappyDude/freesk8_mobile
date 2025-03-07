import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../hardwareSupport/dieBieMSHelper.dart';
import '../hardwareSupport/escHelper/escHelper.dart';

import '../globalUtilities.dart';
import '../components/userSettings.dart';

import 'package:flutter_thermometer/label.dart';
import 'package:flutter_thermometer/scale.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';


import '../widgets/flutterMap.dart'; import 'package:latlong/latlong.dart';

import 'package:flutter_gauge/flutter_gauge.dart';
import 'package:flutter_thermometer/thermometer_widget.dart';
import 'package:responsive_grid/responsive_grid.dart';

import 'package:oscilloscope/oscilloscope.dart';

///
/// Asymmetric sigmoidal approximation
/// https://www.desmos.com/calculator/oyhpsu8jnw
///
/// c - c / [1 + (k*x/v)^4.5]^3
///
double sigmoidal(double voltage, double minVoltage, double maxVoltage) {

  double result = 101 - (101 / pow(1 + pow(1.33 * (voltage - minVoltage)/(maxVoltage - minVoltage) ,4.5), 3));

  double normalized = result >= 100 ? 1.0 : result / 100;
  if (normalized.isNaN) {
    globalLogger.d("realTimeData::sigmoidal: Returning Zero: $voltage V, $minVoltage min, $maxVoltage max");
    normalized = 0;
  }
  return normalized;
}

class RealTimeData extends StatefulWidget {

  RealTimeData(
      { this.routeTakenLocations,
        this.telemetryMap,
        @required this.currentSettings,
        this.startStopTelemetryFunc,
        this.showDieBieMS,
        this.dieBieMSTelemetry,
        this.closeDieBieMSFunc,
        this.changeSmartBMSID,
        this.smartBMSID,
        this.deviceIsConnected,
      });

  final List<LatLng> routeTakenLocations;
  final UserSettings currentSettings;
  final Map<int, ESCTelemetry> telemetryMap;
  final ValueChanged<bool> startStopTelemetryFunc;
  final bool showDieBieMS;
  final DieBieMSTelemetry dieBieMSTelemetry;
  final ValueChanged<bool> closeDieBieMSFunc;
  final ValueChanged<int> changeSmartBMSID;
  final int smartBMSID;
  final bool deviceIsConnected;

  RealTimeDataState createState() => new RealTimeDataState();

  static const String routeName = "/realtime";
}

class RealTimeDataState extends State<RealTimeData> {

  static List<double> motorCurrentGraphPoints = [];

  static double doubleItemWidth = 150; //This changes on widget build

  static double averageVoltageInput;

  static ESCTelemetry escTelemetry;

  double batteryRemaining;

  double calculateSpeedKph(double eRpm) {
    double ratio = 1.0 / widget.currentSettings.settings.gearRatio;
    int minutesToHour = 60;
    double ratioRpmSpeed = (ratio * minutesToHour * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / ((widget.currentSettings.settings.motorPoles / 2) * 1000000);
    double speed = eRpm * ratioRpmSpeed;
    return double.parse((speed).toStringAsFixed(2));
  }

  double calculateDistanceKm(double eCount) {
    double ratio = 1.0 / widget.currentSettings.settings.gearRatio;
    double ratioPulseDistance = (ratio * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / ((widget.currentSettings.settings.motorPoles * 3) * 1000000);
    double distance = eCount * ratioPulseDistance;
    return double.parse((distance).toStringAsFixed(2));
  }

  double calculateEfficiencyKm(double kmTraveled) {
    double whKm = (escTelemetry.watt_hours - escTelemetry.watt_hours_charged) / kmTraveled;
    if (whKm.isNaN || whKm.isInfinite) {
      whKm = 0;
    }
    return double.parse((whKm).toStringAsFixed(2));

  }

  double kphToMph(double kph) {
    double speed = 0.621371 * kph;
    return double.parse((speed).toStringAsFixed(2));
  }

  double kmToMile(double km) {
    double distance = 0.621371 * km;
    return double.parse((distance).toStringAsFixed(2));
  }

  double mmToFeet(double mm) {
    double distance = 0.00328084 * mm;
    return double.parse((distance).toStringAsFixed(2));
  }

  @override
  void initState() {
    super.initState();
    globalLogger.d("initState: realTimeData");
    widget.startStopTelemetryFunc(false); //Start the telemetry timer
  }

  @override
  void dispose() {
    widget.startStopTelemetryFunc(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: RealTimeData");
    if(widget.showDieBieMS) {
      var formatTriple = new NumberFormat("##0.000", "en_US");
      return SlidingUpPanel(
        color: Theme.of(context).primaryColor,
        minHeight: 40,
        maxHeight: MediaQuery.of(context).size.height - 150,
        panel: Column(
          children: <Widget>[
            Container(
              height: 25,
              color: Theme.of(context).highlightColor,
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.arrow_drop_up),
                  Icon(Icons.arrow_drop_down),
                ]),
            ),
            Expanded(
                child: ListView.builder(
                  primary: false,
                  padding: EdgeInsets.all(5),
                  itemCount: widget.dieBieMSTelemetry.noOfCells,
                  itemBuilder: (context, i) {
                    Widget rowIcon;
                    if (widget.dieBieMSTelemetry.cellVoltage[i] == widget.dieBieMSTelemetry.cellVoltageAverage){
                      rowIcon = Transform.rotate(
                        angle: 1.5707,
                        child: Icon(Icons.pause_circle_outline),
                      );
                    } else if (widget.dieBieMSTelemetry.cellVoltage[i] < widget.dieBieMSTelemetry.cellVoltageAverage){
                      rowIcon = Icon(Icons.remove_circle_outline);
                    } else {
                      rowIcon = Icon(Icons.add_circle_outline);
                    }

                    //Sometimes we get a bad parse or bad data from DieBieMS and slider value will not be in min/max range
                    double voltage = widget.dieBieMSTelemetry.cellVoltage[i] - widget.dieBieMSTelemetry.cellVoltageAverage;
                    if (voltage < -widget.dieBieMSTelemetry.cellVoltageMismatch || voltage > widget.dieBieMSTelemetry.cellVoltageMismatch) {
                      return Container();
                    }
                    else return Row(

                      children: <Widget>[
                        rowIcon,
                        Text(" Cell ${i + 1}"),

                        Expanded(child: Slider(
                          onChanged: (newValue){},
                          inactiveColor: Colors.red,
                          value: widget.dieBieMSTelemetry.cellVoltage[i] - widget.dieBieMSTelemetry.cellVoltageAverage,
                          min: -widget.dieBieMSTelemetry.cellVoltageMismatch,
                          max: widget.dieBieMSTelemetry.cellVoltageMismatch,
                        ),),
                        Text("${formatTriple.format(widget.dieBieMSTelemetry.cellVoltage[i])}"),
                      ],


                    );
                  },
                )
            ),
          ],
        ),
        body: Stack(children: <Widget>[

          Center(child:
            Column(children: <Widget>[
              Table(children: [
                TableRow(children: [
                  Text("Pack Voltage: ", textAlign: TextAlign.right,textScaleFactor: 1.25,),
                  //TODO: Hiding SOC if value is 50% because the FlexiBMS always reports 50
                  Text(" ${widget.dieBieMSTelemetry.packVoltage} ${widget.dieBieMSTelemetry.soc != 50 ? "(${widget.dieBieMSTelemetry.soc}%)" : ""}", textScaleFactor: 1.25,)
                ]),
                TableRow(children: [
                  Text("Pack Current: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.packCurrent)} A")
                ]),
                TableRow(children: [
                  Text("Cell Voltage Average: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltageAverage)} V")
                ]),
                TableRow(children: [
                  Text("Cell Voltage High: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltageHigh)} V")
                ]),

                TableRow(children: [
                  Text("Cell Voltage Low: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltageLow)} V")
                ]),
                TableRow(children: [
                  Text("Cell Voltage Mismatch: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltageMismatch)} V")
                ]),
                TableRow(children: [
                  Text("Battery Temp High: ", textAlign: TextAlign.right,),
                  Text(" ${widget.dieBieMSTelemetry.tempBatteryHigh} C")
                ]),
                TableRow(children: [
                  Text("Battery Temp Average: ", textAlign: TextAlign.right,),
                  Text(" ${widget.dieBieMSTelemetry.tempBatteryAverage} C")
                ]),
                TableRow(children: [
                  Text("BMS Temp High: ", textAlign: TextAlign.right,),
                  Text(" ${widget.dieBieMSTelemetry.tempBMSHigh} C")
                ]),
                TableRow(children: [
                  Text("BMS Temp Average: ", textAlign: TextAlign.right,),
                  Text(" ${widget.dieBieMSTelemetry.tempBMSAverage} C")
                ]),
              ],),

              Expanded(child: GridView.builder(
                primary: false,
                itemCount: widget.dieBieMSTelemetry.noOfCells,
                gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3, crossAxisSpacing: 1, mainAxisSpacing: 1),
                itemBuilder: (BuildContext context, int index) {
                  return new Card(
                    shadowColor: Colors.transparent,
                    child: new GridTile(
                        child: new Stack(children: <Widget>[
                          new SizedBox(height: 42,

                              child: new ClipRRect(
                                borderRadius: new BorderRadius.only(topLeft: new Radius.circular(10), topRight: new Radius.circular(10)),
                                child: new LinearProgressIndicator(
                                    backgroundColor: Colors.grey,
                                    valueColor: widget.dieBieMSTelemetry.cellVoltage[index] < 0 ?
                                    new AlwaysStoppedAnimation<Color>(Colors.orangeAccent) :
                                    new AlwaysStoppedAnimation<Color>(Colors.lightGreen),
                                    value: sigmoidal(
                                        widget.dieBieMSTelemetry.cellVoltage[index].abs(),
                                        widget.currentSettings.settings.batteryCellMinVoltage,
                                        widget.currentSettings.settings.batteryCellMaxVoltage)
                                ),
                              )
                          ),
                          new Positioned(
                              top: 5, child: new Text(
                            "  ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltage[index].abs())} V",
                            style: TextStyle(color: Colors.black),
                            textScaleFactor: 1.25,)),
                          new Positioned(bottom: 2, child: new Text("  Cell ${index + 1}")),
                          new ClipRRect(
                              borderRadius: new BorderRadius.circular(10),
                              child: new Container(
                                decoration: new BoxDecoration(
                                  color: Colors.transparent,
                                  border: new Border.all(color: Theme.of(context).accentColor, width: 3.0),
                                  borderRadius: new BorderRadius.circular(10.0),
                                ),
                              )
                          ),
                          /*
                          new Positioned(
                            right: -5,
                            top: 15,
                            child: new SizedBox(
                              height: 30,
                              width: 10,
                              child: new Container(
                                decoration: new BoxDecoration(
                                  color: Colors.red,
                                  border: new Border.all(color: Colors.red, width: 3.0),
                                  borderRadius: new BorderRadius.circular(10.0),
                                ),
                              )
                            ),
                          )
                          */
                        ],)

                    ),
                  );
                },
              )),
              SizedBox(
                height: 25, //NOTE: We want empty space below the gridView for the SlidingUpPanel's handle
              )
            ])
          ),

          Positioned(
              right: 0,
              top: 0,
              child: IconButton(onPressed: (){widget.closeDieBieMSFunc(true);},icon: Icon(Icons.clear),)
          ),
          Positioned(
              left: 0,
              top: 0,
              child: SizedBox(
                width: 42,
                child: GestureDetector(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.device_hub),
                        Text("CAN"),
                        Text("ID ${widget.smartBMSID}")
                      ]
                  ),
                  onTap: (){
                    widget.changeSmartBMSID(widget.smartBMSID == 10 ? 11 : 10);
                  },
                )
              )
          ),
        ],)
      );
    }

    //TODO: Using COMM_GET_VALUE_SETUP for RT so map is not actually needed
    if (widget.telemetryMap.length == 0) {
      escTelemetry = new ESCTelemetry();
    } else {
      escTelemetry = widget.telemetryMap.values.first;
    }

    doubleItemWidth = MediaQuery.of(context).size.width /2 - 10;

    //TODO: testing oscilloscope package
    motorCurrentGraphPoints.add( escTelemetry.current_motor );
    if(motorCurrentGraphPoints.length > doubleItemWidth * 0.75) motorCurrentGraphPoints.removeAt(0);

    double tempMosfet = widget.currentSettings.settings.useFahrenheit ? cToF(escTelemetry.temp_mos) : escTelemetry.temp_mos;
    double tempMotor = widget.currentSettings.settings.useFahrenheit ? cToF(escTelemetry.temp_motor) : escTelemetry.temp_motor;
    // The gauges don't like to display outside their coded range
    if (tempMotor < 0) { tempMotor = 0; }

    String temperatureMosfet = widget.currentSettings.settings.useFahrenheit ? "$tempMosfet F" : "$tempMosfet C";
    //String temperatureMosfet1 = widget.currentSettings.settings.useFahrenheit ? "${cToF(escTelemetry.temp_mos_1)} F" : "${escTelemetry.temp_mos_1} C";
    //String temperatureMosfet2 = widget.currentSettings.settings.useFahrenheit ? "${cToF(escTelemetry.temp_mos_2)} F" : "${escTelemetry.temp_mos_2} C";
    //String temperatureMosfet3 = widget.currentSettings.settings.useFahrenheit ? "${cToF(escTelemetry.temp_mos_3)} F" : "${escTelemetry.temp_mos_3} C";
    String temperatureMotor = widget.currentSettings.settings.useFahrenheit ? "$tempMotor F" : "$tempMotor C";

    double speedMaxFromERPM = calculateSpeedKph(widget.currentSettings.settings.maxERPM);
    double speedMax = widget.currentSettings.settings.useImperial ? kphToMph(speedMaxFromERPM<80?speedMaxFromERPM:80) : speedMaxFromERPM<80?speedMaxFromERPM:80;
    double speedNow = widget.currentSettings.settings.useImperial ? kphToMph(calculateSpeedKph(escTelemetry.rpm)) : calculateSpeedKph(escTelemetry.rpm);
    //String speed = widget.currentSettings.settings.useImperial ? "$speedNow mph" : "$speedNow kph";

    //String distance = widget.currentSettings.settings.useImperial ? "${kmToMile(escTelemetry.tachometer_abs / 1000.0)} miles" : "${escTelemetry.tachometer_abs / 1000.0} km";
    double distanceTraveled = doublePrecision(escTelemetry.tachometer_abs / 1000.0, 2);
    String distance = widget.currentSettings.settings.useImperial ? "${kmToMile(distanceTraveled)} mi" : "$distanceTraveled km";


    double efficiencyKm = calculateEfficiencyKm(distanceTraveled);
    double efficiencyGauge = widget.currentSettings.settings.useImperial ? kmToMile(efficiencyKm) : efficiencyKm;
    String efficiencyGaugeLabel = widget.currentSettings.settings.useImperial ? "Efficiency Wh/Mi" : "Efficiency Wh/Km";
    //String efficiency = widget.currentSettings.settings.useImperial ? "${kmToMile(efficiencyKm)} Wh/Mi" : "$efficiencyKm Wh/Km";

    double powerMax = widget.currentSettings.settings.batteryCellMaxVoltage;
    double powerMinimum = widget.currentSettings.settings.batteryCellMinVoltage;

    if (widget.deviceIsConnected) {
      averageVoltageInput ??= escTelemetry.v_in / widget.currentSettings.settings.batterySeriesCount; // Set to current value if null
      if (averageVoltageInput == 0.0) { // Set to minimum if zero
        averageVoltageInput = powerMinimum;
      } else {
        // Smooth voltage input value from ESC
        averageVoltageInput = (0.25 * doublePrecision(escTelemetry.v_in / widget.currentSettings.settings.batterySeriesCount, 1)) + (0.75 * averageVoltageInput);
      }
    } else {
      averageVoltageInput = 0; // Set to zero when disconnected
    }

    // Set initial batteryRemaining value
    if (batteryRemaining == null) {
      if (escTelemetry.battery_level != null) {
        batteryRemaining = escTelemetry.battery_level * 100;
      } else {
        batteryRemaining = 0;
      }
    }

    // Smooth battery remaining from ESC
    if (escTelemetry.battery_level != null) {
      batteryRemaining = (0.25 * escTelemetry.battery_level * 100) + (0.75 * batteryRemaining);
      if (batteryRemaining < 0.0) {
        globalLogger.e("Battery Remaining $batteryRemaining battery_level ${escTelemetry.battery_level} v_in ${escTelemetry.v_in}");
        batteryRemaining = 0;
      }
      if(batteryRemaining > 100.0) {
        batteryRemaining = 100.0;
      }
    }



    FlutterGauge _gaugeDutyCycle = FlutterGauge(activeColor: Colors.black, handSize: 30,index: escTelemetry.duty_now * 100,fontFamily: "Courier", start:-100, end: 100,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));
    //TODO: if speed is less than start value of gauge this will error
    FlutterGauge _gaugeSpeed = FlutterGauge(numberInAndOut: NumberInAndOut.inside, index: speedNow, start: -5, end: speedMax.ceil().toInt(),counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.none,number: Number.all);

    FlutterGauge _gaugePowerRemaining = FlutterGauge(inactiveColor: Colors.red,activeColor: Colors.black,numberInAndOut: NumberInAndOut.inside, index: batteryRemaining,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.secondsAndMinute,number: Number.all);
    FlutterGauge _gaugeVolts = FlutterGauge(inactiveColor: Colors.red,activeColor: Colors.black,hand: Hand.short,index: averageVoltageInput,fontFamily: "Courier",start: powerMinimum.floor().toInt(), end: powerMax.ceil().toInt(),number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));
    //TODO: scale efficiency and adjust end value for imperial users
    FlutterGauge _gaugeEfficiency = FlutterGauge(reverseDial: true, reverseDigits: true, hand: Hand.short,index: efficiencyGauge,fontFamily: "Courier",start: 0, end: 100,number: Number.endAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));

    Oscilloscope scopeOne = Oscilloscope(
      backgroundColor: Colors.transparent,
      traceColor: Theme.of(context).accentColor,
      showYAxis: true,
      yAxisMax: 25.0,
      yAxisMin: -25.0,
      dataSet: motorCurrentGraphPoints,
    );
    TextStyle speedStyle = TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 148, fontWeight: FontWeight.bold);
    TextStyle medStyle = TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold);
    TextStyle minorStyle = TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold);
    //globalLogger.wtf(MediaQuery.of(context).size.height);
    //globalLogger.wtf(MediaQuery.of(context).size.width);

    // Build widget
    return Container(
      child: Center(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: <Widget>[
            ResponsiveGridRow(
              children: [
                ResponsiveGridCol(lg: 6, md: 6, sm: 6, xs: 6,
                    child: Container(
                      child:
                        Column(children: <Widget>[
                          Column(children: <Widget>[
                            Center(child:Text("Speed")),
                            Container(child: Center(child: Text("${speedNow.round()}", style: speedStyle)))
                          ]),
                          ResponsiveGridRow(
                            children: [
                              ResponsiveGridCol(lg: 4, md: 4, sm: 4, xs: 4,
                                  child: Container(
                                      child:
                                      Column(children: <Widget>[
                                        Center(child: Text("M Current")),
                                        Text("${doublePrecision(escTelemetry.current_motor, 1)} A", style: minorStyle),
                                      ])
                                  )
                              ),
                              ResponsiveGridCol(lg: 4, md: 4, sm: 4, xs: 4,
                                  child: Container(
                                      child:
                                      Column(children: <Widget>[
                                        Center(child:Text("Duty Cycle")),
                                        Container(child: Center(child: Text("${doublePrecision(escTelemetry.duty_now * 100, 0).round()}" + '%', style: minorStyle)))
                                      ])
                                  )
                              ),
                              ResponsiveGridCol(lg: 4, md: 4, sm: 4, xs: 4,
                                  child: Container(
                                      child:
                                      Column(children: <Widget>[
                                        Center(child: Text("B Current")),
                                        Center(child: Text(" ${doublePrecision(escTelemetry.current_in, 1)} A", style: minorStyle))
                                      ])
                                  )
                              ),
                            ]
                          )
                        ])
                    )

                ),

                ResponsiveGridCol(lg: 6, md: 6, sm: 6, xs: 6,
                  child: Container(
                    alignment: Alignment(0, 0),
                    child:
                      Column(children: <Widget>[
                        Column(children: <Widget>[
                          Center(child:Text("Voltage")),
                          // Container(width: doubleItemWidth, child: _gaugeVolts)
                          Center(child: Text("${doublePrecision(averageVoltageInput, 2)}" + 'V', style: medStyle))
                        ]),
                        Column(children: <Widget>[
                          Center(child:Text("Odometer")),
                          // Container(width: doubleItemWidth, child: _gaugeVolts)
                          Center(child: Text('$distance', style: medStyle))
                        ]),
                        Column(children: <Widget>[
                          Center(child: Text("ESC Temp")),
                          Text(temperatureMosfet, style: medStyle),
                        ]),
                        Column(children: <Widget>[
                          Center(child: Text("Motor Temp")),
                          Center(child: Text(temperatureMotor, style: medStyle))
                        ])
                      ])
                  )
                ),

              ]
            ),

            Table(children: [
              TableRow(children: [
                Text("Distance Traveled: ", textAlign: TextAlign.right,),
                Text(" $distance")
              ]),
              TableRow(children: [
                Text("Watt Hours: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.watt_hours, 2)} Wh")
              ]),
              TableRow(children: [
                Text("Watt Hours Charged: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.watt_hours_charged, 2)} Wh")
              ]),
              TableRow(children: [
                Text("Wh/mi: ", textAlign: TextAlign.right,),
                Text("${doublePrecision(efficiencyGauge, 0)}")
              ]),

              TableRow(children: [
                Text("Amp Hours: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.amp_hours, 2)} Ah")
              ]),
              TableRow(children: [
                Text("Amp Hours Charged: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.amp_hours_charged, 2)} Ah")
              ]),

              /*
              TableRow(children: [
                Text("Mosfet 1 Temperature: ", textAlign: TextAlign.right,),
                Text(" $temperatureMosfet1")
              ]),
              TableRow(children: [
                Text("Mosfet 2 Temperature: ", textAlign: TextAlign.right,),
                Text(" $temperatureMosfet2")
              ]),
              TableRow(children: [
                Text("Mosfet 3 Temperature: ", textAlign: TextAlign.right,),
                Text(" $temperatureMosfet3")
              ]),
              */
              TableRow(children: [
                Text("Battery Current Now: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.current_in, 2)} A")
              ]),
              TableRow(children: [
                Text("ESC ID: ", textAlign: TextAlign.right,),
                Text(" ${escTelemetry.vesc_id}")
              ]),
              TableRow(children: [
                Text("Fault Now: ", textAlign: TextAlign.right,),
                Text("${escTelemetry.fault_code.index == 0 ? " 0":" Code ${escTelemetry.fault_code.index}"}")
              ]),
            ],),
            escTelemetry.fault_code.index != 0 ? Center(child: Text("${escTelemetry.fault_code.toString().split('.')[1]}")) : Container(),
            SizedBox(height: 10),

            ///FlutterMapWidget
            Text("Mobile device position:"),
            Container(
              height: MediaQuery.of(context).size.height / 2,
              child: Center(
                  child: new FlutterMapWidget(routeTakenLocations: widget.routeTakenLocations,)
                    //child: googleMapPage,
                )
              ),


          ],
        ),
      ),
    );
  }
}
