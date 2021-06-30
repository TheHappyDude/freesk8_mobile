
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:freesk8_mobile/components/databaseAssistant.dart';
import 'package:freesk8_mobile/components/userSettings.dart';
import 'package:freesk8_mobile/globalUtilities.dart';

import 'package:uuid/uuid.dart';

class VehicleManagerArguments {
  final String connectedDeviceID;
  final NavigatorState navigatorState;

  VehicleManagerArguments(this.connectedDeviceID, this.navigatorState);
}

class VehicleManager extends StatefulWidget {
  @override
  VehicleManagerState createState() => VehicleManagerState();

  static const String routeName = "/vehiclemanager";
}

class VehicleManagerState extends State<VehicleManager> {
  static Widget bodyWidget;
  VehicleManagerArguments myArguments;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    bodyWidget = null;
    super.dispose();
  }

  void _retireVehicle(String deviceID) async {
    await genericConfirmationDialog(myArguments.navigatorState.context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(myArguments.navigatorState.context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        var uuid = Uuid();
        Navigator.of(myArguments.navigatorState.context).pop();
        String newID = "R*${uuid.v4().toString()}"; // Generate unique retirement ID
        await DatabaseAssistant.dbAssociateVehicle(deviceID, newID);
        await UserSettings.associateDevice(deviceID, newID);
        _reloadBody();
      },
    ), "Retire Vehicle", Text("Are you sure you want to retire the selected vehicle? The connected bluetooth device will no longer be associated with this vehicle. Nothing will be erased."));
  }

  void _recruitVehicle(String deviceID) async {
    await genericConfirmationDialog(myArguments.navigatorState.context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(myArguments.navigatorState.context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        Navigator.of(myArguments.navigatorState.context).pop();
        String newID = myArguments.connectedDeviceID;
        await DatabaseAssistant.dbAssociateVehicle(deviceID, newID);
        await UserSettings.associateDevice(deviceID, newID);
        _reloadBody();
      },
    ), "Adopt Vehicle", Text("Assign connected bluetooth device to selected vehicle?"));
  }

  void _removeVehicle(String deviceID) async {
    await genericConfirmationDialog(myArguments.navigatorState.context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(myArguments.navigatorState.context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        Navigator.of(myArguments.navigatorState.context).pop();
        await DatabaseAssistant.dbRemoveVehicle(deviceID);
        await UserSettings.removeDevice(deviceID);
        _reloadBody();
      },
    ), "Remove Vehicle", Text("Remove the selected vehicle and all of it's data?"));
  }

  void _buildBody(BuildContext context) async {
    List<Widget> listChildren = [];


    List<String> knownDevices = await UserSettings.getKnownDevices();
    bool currentDeviceKnown = knownDevices.contains(myArguments.connectedDeviceID);
    globalLogger.w("connected device is in known devices? $currentDeviceKnown Connected device: ${myArguments.connectedDeviceID}");

    listChildren.add(SizedBox(height: 10));
    listChildren.add(
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(image: AssetImage("assets/dri_icon.png"),height: 100),
              Column(children: [
                Text("Actions available:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Row(children: [
                  Icon(Icons.remove_circle),
                  Text("Retire"),
                  SizedBox(width: 3),
                  Icon(Icons.bedtime_outlined, color: Colors.grey),
                  Text("Retired"),
                  SizedBox(width: 4),
                  Icon(Icons.family_restroom),
                  Text("Adopt")
                ],),
                Row(children: [
                  Icon(Icons.delete_forever),
                  Text("Erase"),
                ])
              ])
            ])
    );

    if (!currentDeviceKnown && myArguments.connectedDeviceID != null) {
      listChildren.add(Center(child: Text("Warning, connected device does not belong to a vehicle!", style: TextStyle(color: Colors.yellow),),));
      listChildren.add(Center(child: Text("Please adopt a vehicle below", style: TextStyle(color: Colors.yellow),),));
    }
    List<UserSettingsStructure> settings = [];
    List<double> distances = [];
    List<double> consumptions = [];
    UserSettings mySettings = new UserSettings();
    for (int i=0; i<knownDevices.length; ++i) {
      if (await mySettings.loadSettings(knownDevices[i])) {
        settings.add(new UserSettingsStructure.fromValues(mySettings.settings));
        distances.add(await  DatabaseAssistant.dbGetOdometer(knownDevices[i]));
        consumptions.add(await  DatabaseAssistant.dbGetConsumption(knownDevices[i],false));
        // Add a Row for each Vehicle we load
        listChildren.add(Row(
          children: [
            //TODO: Editable board avatar
            FutureBuilder<String>(
                future: UserSettings.getBoardAvatarPath(knownDevices[i]),
                builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                  return CircleAvatar(
                      backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                      radius: 42,
                      backgroundColor: Colors.white);
                }),
            SizedBox(width: 10),
            Column(children: [
              Text("${settings[i].boardAlias}"), //TODO: Editable board name
              Text("${settings[i].batterySeriesCount}S ${settings[i].wheelDiameterMillimeters}mm ${settings[i].gearRatio}:1"),
              Text("${settings[i].deviceID}", style: TextStyle(fontSize: 4),),
            ],
            crossAxisAlignment: CrossAxisAlignment.start),


            Spacer(),
            Column(children: [
              Text("${doublePrecision(distances[i], 2)} km"),
              Text("${doublePrecision(consumptions[i], 2)} wh/km"),
            ],crossAxisAlignment: CrossAxisAlignment.end),

            SizedBox(width: 10),
            // Show if the listed device is the one we are connected to
            myArguments.connectedDeviceID == settings[i].deviceID ? Icon(Icons.bluetooth_connected) : Container(),
            myArguments.connectedDeviceID == settings[i].deviceID ? GestureDetector(child: Icon(Icons.remove_circle), onTap: (){_retireVehicle(settings[i].deviceID);}) : Container(),

            // Show if vehicle has been retired from service
            settings[i].deviceID.startsWith("R*") ? Icon(Icons.bedtime_outlined, color: Colors.grey) : Container(),

            // Allow any vehicle to be adopted/recruited if we are not currently connected to a known device
            !currentDeviceKnown && myArguments.connectedDeviceID != null ? GestureDetector(child: Icon(Icons.family_restroom), onTap: (){_recruitVehicle(settings[i].deviceID);}) : Container(),

            // Allow any disconnected vehicle to be removed
            myArguments.connectedDeviceID != settings[i].deviceID ? GestureDetector(child: Icon(Icons.delete_forever), onTap: (){_removeVehicle(settings[i].deviceID);}) : Container(),
            SizedBox(width: 10),
          ],
        ));
      } else {
        globalLogger.e("help!");
      }
    }
    bodyWidget = ListView.separated(
      separatorBuilder: (BuildContext context, int index) {
        return SizedBox(
          height: 5,
        );
      },
      itemCount: listChildren.length,
      itemBuilder: (_, i) => listChildren[i],
    );
    globalLogger.wtf("hi");
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (BuildContext context) => VehicleManager(), settings: RouteSettings(arguments: myArguments)));
    return;
  }

  void _reloadBody() {
    bodyWidget = null;
    // Reload view, tricky eh?
    myArguments.navigatorState.pushReplacement(MaterialPageRoute(builder: (BuildContext context) => VehicleManager(), settings: RouteSettings(arguments: myArguments)));
  }

  @override
  Widget build(BuildContext context) {
    print("Building vehicleManager");

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No Arguments"));
    }

    if (bodyWidget == null) {
      _buildBody(context);
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(children: <Widget>[
          Icon( Icons.list_alt,
            size: 35.0,
            color: Colors.blue,
          ),
          SizedBox(width: 3),
          Text("FreeSK8 Garage"),
        ],),
      ),
      body: bodyWidget == null ? Container(child: Text("Loading")) : bodyWidget,
    );
  }
}
