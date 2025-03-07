import 'dart:async';
import 'dart:io';
import 'dart:typed_data';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freesk8_mobile/components/smartSlider.dart';

import '../components/crc16.dart';
import '../widgets/throttleCurvePainter.dart';
import '../subViews/escProfileEditor.dart';
import '../subViews/vehicleManager.dart';
import '../globalUtilities.dart';

import '../components/userSettings.dart';
import '../subViews/focWizard.dart';
import '../hardwareSupport/escHelper/escHelper.dart';
import '../hardwareSupport/escHelper/appConf.dart';
import '../hardwareSupport/escHelper/mcConf.dart';
import '../hardwareSupport/escHelper/dataTypes.dart';

import 'package:esys_flutter_share/esys_flutter_share.dart';

import 'package:flutter_blue/flutter_blue.dart';

import 'package:image_picker/image_picker.dart';

import 'package:path_provider/path_provider.dart';

import 'package:archive/archive_io.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_document_picker/flutter_document_picker.dart';

class ESK8Configuration extends StatefulWidget {
  ESK8Configuration({
    @required this.myUserSettings,
    this.currentDevice,
    this.showESCProfiles,
    this.theTXCharacteristic,
    this.escMotorConfiguration,
    this.onExitProfiles,
    this.onAutoloadESCSettings, //TODO: this might be removable
    this.showESCConfigurator,
    this.discoveredCANDevices,
    this.closeESCConfigurator,
    this.updateCachedAvatar,
    this.showESCAppConfig,
    this.escAppConfiguration,
    this.closeESCApplicationConfigurator,
    this.ppmLastDuration,
    this.requestESCApplicationConfiguration,
    this.notifyStopStartPPMCalibrate,
    this.ppmCalibrateReady,
    this.escFirmwareVersion,
    this.updateComputedVehicleStatistics,
    @required this.applicationDocumentsDirectory,
    this.reloadUserSettings,
  });
  final UserSettings myUserSettings;
  final BluetoothDevice currentDevice;
  final bool showESCProfiles;
  final BluetoothCharacteristic theTXCharacteristic;
  final MCCONF escMotorConfiguration;
  final ValueChanged<bool> onExitProfiles;
  final ValueChanged<bool> onAutoloadESCSettings;
  final bool showESCConfigurator;
  final List<int> discoveredCANDevices;
  final ValueChanged<bool> closeESCConfigurator;
  final ValueChanged<bool> updateCachedAvatar;

  final bool showESCAppConfig;
  final APPCONF escAppConfiguration;
  final ValueChanged<bool> closeESCApplicationConfigurator;
  final int ppmLastDuration;
  final ValueChanged<int> requestESCApplicationConfiguration;
  final ValueChanged<bool> notifyStopStartPPMCalibrate;
  final bool ppmCalibrateReady;

  final ESC_FIRMWARE escFirmwareVersion;

  final ValueChanged<bool> updateComputedVehicleStatistics;

  final String applicationDocumentsDirectory;

  final ValueChanged<bool> reloadUserSettings;

  ESK8ConfigurationState createState() => new ESK8ConfigurationState();

  static const String routeName = "/settings";
}

class ESK8ConfigurationState extends State<ESK8Configuration> {

  final GlobalKey<State> _keyLoader = new GlobalKey<State>();

  bool _applyESCProfilePermanently;

  int _selectedCANFwdID;
  int _invalidCANID;

  bool _writeESCInProgress;

  FileImage _boardAvatar;

  bool _showAdvanced = false;

  Future getImage(bool fromUserGallery) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final imagePicker = ImagePicker();
    PickedFile temporaryImage = await imagePicker.getImage(source: fromUserGallery ? ImageSource.gallery : ImageSource.camera, maxWidth: 640, maxHeight: 640);

    if (temporaryImage != null) {
      // We have a new image, capture for display and update the settings in memory
      String newPath = "${documentsDirectory.path}/avatars/${widget.currentDevice.id}";
      File finalImage = await File(newPath).create(recursive: true);
      finalImage.writeAsBytesSync(await temporaryImage.readAsBytes());
      globalLogger.d("Board avatar file destination: ${finalImage.path}");

      // Let go of the old image that we are displaying here
      setState(() {
        _boardAvatar = null;
      });

      // Wait for the application
      await Future.delayed(Duration(milliseconds: 500),(){});

      // Clear the image cache and load the new image
      setState(() {
        //NOTE: A FileImage is the fastest way to load these images but because
        //      it's cached they will only update once. Unless you explicitly
        //      clear the imageCache
        // Clear the imageCache for FileImages used in rideLogging.dart
        imageCache.clear();
        imageCache.clearLiveImages();

        widget.myUserSettings.settings.boardAvatarPath = "/avatars/${widget.currentDevice.id}";
        _boardAvatar = new FileImage(new File("${widget.applicationDocumentsDirectory}${widget.myUserSettings.settings.boardAvatarPath}"));
      });
    }
  }

  final tecBoardAlias = TextEditingController();

  final tecBatterySeriesCount = TextEditingController();
  final tecBatteryCapacityAh = TextEditingController();
  final tecWheelDiameterMillimeters = TextEditingController();
  final tecMotorPoles = TextEditingController();
  final tecGearRatio = TextEditingController();

  final tecCurrentMax = TextEditingController();
  final tecCurrentMin = TextEditingController();
  final tecInCurrentMax = TextEditingController();
  final tecInCurrentMin = TextEditingController();
  final tecABSCurrentMax = TextEditingController();

  final tecMaxERPM = TextEditingController();
  final tecMinERPM = TextEditingController();

  final tecMinVIN = TextEditingController();
  final tecMaxVIN = TextEditingController();
  final tecBatteryCutStart = TextEditingController();
  final tecBatteryCutEnd = TextEditingController();

  final tecTempFETStart = TextEditingController();
  final tecTempFETEnd = TextEditingController();
  final tecTempMotorStart = TextEditingController();
  final tecTempMotorEnd = TextEditingController();

  final tecWattMin = TextEditingController();
  final tecWattMax = TextEditingController();
  final tecCurrentMinScale = TextEditingController();
  final tecCurrentMaxScale = TextEditingController();

  final tecDutyStart = TextEditingController();

  /// Balance stuff
  final tecIMUHz = TextEditingController();
  final tecBalanceHz = TextEditingController();
  final tecHalfSwitchFaultDelay = TextEditingController();
  final tecFullSwitchFaultDelay = TextEditingController();
  final tecHalfStateFaultERPM = TextEditingController();
  final tecKP = TextEditingController();
  final tecKI = TextEditingController();
  final tecKD = TextEditingController();
  final tecTiltbackConstantERPM = TextEditingController();


  /// APP Conf
  List<ListItem> _appModeItems = [
    ListItem(app_use.APP_NONE.index, "None"),
    //ListItem(app_use.APP_PPM.index, "PPM"), //TODO: disables uart!?! whoa
    //ListItem(app_use.APP_ADC.index, "ADC"),
    ListItem(app_use.APP_UART.index, "UART"),
    ListItem(app_use.APP_PPM_UART.index, "PPM + UART"),
    //ListItem(app_use.APP_ADC_UART.index, "ADC UART"),
    //ListItem(app_use.APP_NUNCHUK.index, "NUNCHUK"),
    //ListItem(app_use.APP_NRF.index, "NRF"),
    //ListItem(app_use.APP_CUSTOM.index, "CUSTOM"),
    ListItem(app_use.APP_BALANCE.index, "BALANCE"),
  ];
  List<DropdownMenuItem<ListItem>> _appModeDropdownItems;
  ListItem _selectedAppMode;

  List<ListItem> _ppmCtrlTypeItems = [
    ListItem(ppm_control_type.PPM_CTRL_TYPE_NONE.index, "None"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT.index, "Current"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT_NOREV.index, "Current No Reverse"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT_NOREV_BRAKE.index, "Current No Reverse with Brake"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_DUTY.index, "Duty Cycle"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_DUTY_NOREV.index, "Duty Cycle No Reverse"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_PID.index, "PID Speed Control"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_PID_NOREV.index, "PID Speed Control No Reverse"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT_BRAKE_REV_HYST.index, "Current Hysteresis Reverse with Brake"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT_SMART_REV.index, "Current Smart Reverse"),
  ];
  List<DropdownMenuItem<ListItem>> _ppmCtrlTypeDropdownItems;
  ListItem _selectedPPMCtrlType;

  List<ListItem> _thrExpModeItems = [
    ListItem(thr_exp_mode.THR_EXP_EXPO.index, "Exponential"),
    ListItem(thr_exp_mode.THR_EXP_NATURAL.index, "Natural"),
    ListItem(thr_exp_mode.THR_EXP_POLY.index, "Polynomial"),
  ];
  List<DropdownMenuItem<ListItem>> _thrExpModeDropdownItems;
  ListItem _selectedThrExpMode;

  List<ListItem> _nunchukCtrlTypeItems = [
    ListItem(chuk_control_type.CHUK_CTRL_TYPE_NONE.index, "Off"),
    ListItem(chuk_control_type.CHUK_CTRL_TYPE_CURRENT.index, "Current"),
    ListItem(chuk_control_type.CHUK_CTRL_TYPE_CURRENT_NOREV.index, "Current No Reverse"),
    ListItem(chuk_control_type.CHUK_CTRL_TYPE_CURRENT_BIDIRECTIONAL.index, "Current Bidirectional"),
  ];
  List<DropdownMenuItem<ListItem>> _nunchuckCtrlTypeDropdownItems;
  ListItem _selectedNunchukCtrlType;

  List<ListItem> _thrExpModeNunchukItems = [
    ListItem(thr_exp_mode.THR_EXP_EXPO.index, "Exponential"),
    ListItem(thr_exp_mode.THR_EXP_NATURAL.index, "Natural"),
    ListItem(thr_exp_mode.THR_EXP_POLY.index, "Polynomial"),
  ];
  List<DropdownMenuItem<ListItem>> _thrExpModeNunchukDropdownItems;
  ListItem _selectedThrExpModeNunchuk;

  static Timer ppmCalibrateTimer;
  bool ppmCalibrate = false;
  ppm_control_type ppmCalibrateControlTypeToRestore;
  int ppmMinMS;
  int ppmMaxMS;
  RangeValues _rangeSliderDiscreteValues = const RangeValues(1.5, 1.6);
  bool showAdvancedOptions = false;
  bool showPPMConfiguration = false;
  bool showNunchukConfiguration = false;
  bool showBalanceConfiguration = false;

  @override
  void initState() {
    super.initState();

    if (widget.myUserSettings.settings.boardAvatarPath != null) {
      _boardAvatar = FileImage(File("${widget.applicationDocumentsDirectory}${widget.myUserSettings.settings.boardAvatarPath}"));
    }

    _applyESCProfilePermanently = false;
    _writeESCInProgress = false;

    //TODO: these try parse can return null.. then the device will remove null because it's not a number
    tecBoardAlias.addListener(() { widget.myUserSettings.settings.boardAlias = tecBoardAlias.text; });

    // TextEditingController Listeners for Motor Configuration
    tecBatterySeriesCount.addListener(() { widget.escMotorConfiguration.si_battery_cells = int.tryParse(tecBatterySeriesCount.text); });
    tecBatteryCapacityAh.addListener(() { widget.escMotorConfiguration.si_battery_ah = doublePrecision(double.tryParse(tecBatteryCapacityAh.text.replaceFirst(',', '.')), 2); });
    tecWheelDiameterMillimeters.addListener(() {
      try {
        widget.escMotorConfiguration.si_wheel_diameter = doublePrecision(double.tryParse(tecWheelDiameterMillimeters.text.replaceFirst(',', '.')) / 1000.0, 3);
      } catch (e) {}
    });
    tecMotorPoles.addListener(() { widget.escMotorConfiguration.si_motor_poles = int.tryParse(tecMotorPoles.text); });
    tecGearRatio.addListener(() { widget.escMotorConfiguration.si_gear_ratio = doublePrecision(double.tryParse(tecGearRatio.text.replaceFirst(',', '.')), 3); });
    tecCurrentMax.addListener(() { widget.escMotorConfiguration.l_current_max = doublePrecision(double.tryParse(tecCurrentMax.text.replaceFirst(',', '.')), 1); });
    tecCurrentMin.addListener(() {
      double newValue = double.tryParse(tecCurrentMin.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
      widget.escMotorConfiguration.l_current_min = doublePrecision(newValue, 1);
    });
    tecInCurrentMax.addListener(() { widget.escMotorConfiguration.l_in_current_max = doublePrecision(double.tryParse(tecInCurrentMax.text.replaceFirst(',', '.')), 1); });
    tecInCurrentMin.addListener(() {
      double newValue = double.tryParse(tecInCurrentMin.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
      widget.escMotorConfiguration.l_in_current_min = doublePrecision(newValue, 1);
    });
    tecABSCurrentMax.addListener(() { widget.escMotorConfiguration.l_abs_current_max = doublePrecision(double.tryParse(tecABSCurrentMax.text.replaceFirst(',', '.')), 1); });
    tecMaxERPM.addListener(() { widget.escMotorConfiguration.l_max_erpm = int.tryParse(tecMaxERPM.text.replaceFirst(',', '.')).toDouble(); });
    tecMinERPM.addListener(() {
      double newValue = double.tryParse(tecMinERPM.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
      widget.escMotorConfiguration.l_min_erpm = newValue;
    });
    tecMinVIN.addListener(() { widget.escMotorConfiguration.l_min_vin = doublePrecision(double.tryParse(tecMinVIN.text.replaceFirst(',', '.')), 1); });
    tecMaxVIN.addListener(() { widget.escMotorConfiguration.l_max_vin = doublePrecision(double.tryParse(tecMaxVIN.text.replaceFirst(',', '.')), 1); });
    tecBatteryCutStart.addListener(() { widget.escMotorConfiguration.l_battery_cut_start = doublePrecision(double.tryParse(tecBatteryCutStart.text.replaceFirst(',', '.')), 1); });
    tecBatteryCutEnd.addListener(() { widget.escMotorConfiguration.l_battery_cut_end = doublePrecision(double.tryParse(tecBatteryCutEnd.text.replaceFirst(',', '.')), 1); });
    tecTempFETStart.addListener(() { widget.escMotorConfiguration.l_temp_fet_start = doublePrecision(double.tryParse(tecTempFETStart.text.replaceFirst(',', '.')), 1); });
    tecTempFETEnd.addListener(() { widget.escMotorConfiguration.l_temp_fet_end = doublePrecision(double.tryParse(tecTempFETEnd.text.replaceFirst(',', '.')), 1); });
    tecTempMotorStart.addListener(() { widget.escMotorConfiguration.l_temp_motor_start = doublePrecision(double.tryParse(tecTempMotorStart.text.replaceFirst(',', '.')), 1); });
    tecTempMotorEnd.addListener(() { widget.escMotorConfiguration.l_temp_motor_end = doublePrecision(double.tryParse(tecTempMotorEnd.text.replaceFirst(',', '.')), 1); });
    tecWattMin.addListener(() {
      double newValue = double.tryParse(tecWattMin.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
      widget.escMotorConfiguration.l_watt_min = doublePrecision(newValue, 1);
    });
    tecWattMax.addListener(() { widget.escMotorConfiguration.l_watt_max = doublePrecision(double.tryParse(tecWattMax.text.replaceFirst(',', '.')), 1); });
    tecCurrentMinScale.addListener(() {
      double newValue = double.tryParse(tecCurrentMinScale.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escMotorConfiguration.l_current_min_scale = doublePrecision(newValue, 2);
    });
    tecCurrentMaxScale.addListener(() {
      double newValue = double.tryParse(tecCurrentMaxScale.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escMotorConfiguration.l_current_max_scale = doublePrecision(newValue, 2);
    });
    tecDutyStart.addListener(() {
      double newValue = double.tryParse(tecDutyStart.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escMotorConfiguration.l_duty_start = doublePrecision(newValue, 2);
    });

    /// ESC Application Configuration
    _appModeDropdownItems = buildDropDownMenuItems(_appModeItems);
    _ppmCtrlTypeDropdownItems = buildDropDownMenuItems(_ppmCtrlTypeItems);
    _thrExpModeDropdownItems = buildDropDownMenuItems(_thrExpModeItems);
    _nunchuckCtrlTypeDropdownItems = buildDropDownMenuItems(_nunchukCtrlTypeItems);
    _thrExpModeNunchukDropdownItems = buildDropDownMenuItems(_thrExpModeNunchukItems);

    /// Balance Configuration
    tecIMUHz.addListener(() { widget.escAppConfiguration.imu_conf.sample_rate_hz = int.tryParse(tecIMUHz.text); });
    tecBalanceHz.addListener(() { widget.escAppConfiguration.app_balance_conf.hertz = int.tryParse(tecBalanceHz.text); });
    tecHalfSwitchFaultDelay.addListener(() { widget.escAppConfiguration.app_balance_conf.fault_delay_switch_half = int.tryParse(tecHalfSwitchFaultDelay.text); });
    tecFullSwitchFaultDelay.addListener(() { widget.escAppConfiguration.app_balance_conf.fault_delay_switch_full = int.tryParse(tecFullSwitchFaultDelay.text); });
    tecHalfStateFaultERPM.addListener(() { widget.escAppConfiguration.app_balance_conf.fault_adc_half_erpm = int.tryParse(tecHalfStateFaultERPM.text); });
    tecKP.addListener(() {
      double newValue = double.tryParse(tecKP.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escAppConfiguration.app_balance_conf.kp = doublePrecision(newValue, 4);
    });
    tecKI.addListener(() {
      double newValue = double.tryParse(tecKI.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escAppConfiguration.app_balance_conf.ki = doublePrecision(newValue, 4);
    });
    tecKD.addListener(() {
      double newValue = double.tryParse(tecKD.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escAppConfiguration.app_balance_conf.kd = doublePrecision(newValue, 4);
    });

    tecTiltbackConstantERPM.addListener(() { widget.escAppConfiguration.app_balance_conf.tiltback_constant_erpm = int.tryParse(tecTiltbackConstantERPM.text); });
  }


  @override
  void dispose() {
    super.dispose();

    tecBoardAlias.dispose();

    tecBatterySeriesCount.dispose();
    tecBatteryCapacityAh.dispose();
    tecWheelDiameterMillimeters.dispose();
    tecMotorPoles.dispose();
    tecGearRatio.dispose();

    tecCurrentMax.dispose();
    tecCurrentMin.dispose();
    tecInCurrentMax.dispose();
    tecInCurrentMin.dispose();
    tecABSCurrentMax.dispose();
    tecMaxERPM.dispose();
    tecMinERPM.dispose();
    tecMinVIN.dispose();
    tecMaxVIN.dispose();
    tecBatteryCutStart.dispose();
    tecBatteryCutEnd.dispose();
    tecTempFETStart.dispose();
    tecTempFETEnd.dispose();
    tecTempMotorStart.dispose();
    tecTempMotorEnd.dispose();
    tecWattMin.dispose();
    tecWattMax.dispose();
    tecCurrentMinScale.dispose();
    tecCurrentMaxScale.dispose();
    tecDutyStart.dispose();

    tecIMUHz.dispose();
    tecBalanceHz.dispose();
    tecHalfSwitchFaultDelay.dispose();
    tecFullSwitchFaultDelay.dispose();
    tecHalfStateFaultERPM.dispose();
    tecKP.dispose();
    tecKI.dispose();
    tecKD.dispose();
    tecTiltbackConstantERPM.dispose();

    // Stop ppm calibration timer if it's somehow left behind
    if (ppmCalibrateTimer != null) {
      //TODO: should we alert a user when this happens? maaayyyybe
      ppmCalibrateTimer?.cancel();
      ppmCalibrateTimer = null;
    }
  }

  void setMCCONFTemp(bool persistentChange, ESCProfile escProfile) {

    var byteData = new ByteData(42); //<start><payloadLen><payload><crc1><crc2><end>
    byteData.setUint8(0, 0x02); //Start of packet <255 in length
    byteData.setUint8(1, 37); //Payload length
    byteData.setUint8(2, COMM_PACKET_ID.COMM_SET_MCCONF_TEMP_SETUP.index);
    byteData.setUint8(3, persistentChange ? 1 : 0);
    byteData.setUint8(4, 0x01); //Forward to CAN devices =D Hooray
    byteData.setUint8(5, 0x01); //ACK = true
    byteData.setUint8(6, 0x00); //Divide By Controllers = false
    byteData.setFloat32(7, escProfile.l_current_min_scale);
    byteData.setFloat32(11, escProfile.l_current_max_scale);
    byteData.setFloat32(15, escProfile.speedKmhRev / 3.6); //kph to m/s
    byteData.setFloat32(19, escProfile.speedKmh / 3.6); //kph to m/s
    byteData.setFloat32(23, widget.escMotorConfiguration.l_min_duty);
    byteData.setFloat32(27, widget.escMotorConfiguration.l_max_duty);
    if (escProfile.l_watt_min != 0.0){
      byteData.setFloat32(31, escProfile.l_watt_min);
    } else {
      byteData.setFloat32(31, widget.escMotorConfiguration.l_watt_min);
    }
    if (escProfile.l_watt_max != 0.0){
      byteData.setFloat32(35, escProfile.l_watt_max);
    } else {
      byteData.setFloat32(35, widget.escMotorConfiguration.l_watt_max);
    }
    int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, 37);
    byteData.setUint16(39, checksum);
    byteData.setUint8(41, 0x03); //End of packet

    sendBLEData(widget.theTXCharacteristic, byteData.buffer.asUint8List(), true).then((sendResult){
      if (sendResult) globalLogger.d('COMM_SET_MCCONF_TEMP_SETUP sent');
      else globalLogger.d('COMM_SET_MCCONF_TEMP_SETUP failed to send');
    });
  }

  void requestMCCONFCAN(int canID) async {
    var byteData = new ByteData(8);
    byteData.setUint8(0, 0x02);
    byteData.setUint8(1, 0x03);
    byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
    byteData.setUint8(3, canID);
    byteData.setUint8(4, COMM_PACKET_ID.COMM_GET_MCCONF.index);
    int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, 3);
    byteData.setUint16(5, checksum);
    byteData.setUint8(7, 0x03); //End of packet

    if (!await sendBLEData(widget.theTXCharacteristic, byteData.buffer.asUint8List(), false)) {
      globalLogger.e('COMM_GET_MCCONF request failed for CAN ID $canID');
    } else {
      globalLogger.d('COMM_GET_MCCONF requested from CAN ID $canID');
    }
  }

  void saveMCCONF(int optionalCANID) async {
    if (_writeESCInProgress) {
      globalLogger.w("WARNING: esk8Configuration: saveMCCONF: _writeESCInProgress is true. Save aborted.");
      return;
    }

    // Protect from interrupting a previous write attempt
    _writeESCInProgress = true;
    ESCHelper escHelper = new ESCHelper();
    ByteData serializedMcconf = escHelper.serializeMCCONF(widget.escMotorConfiguration, widget.escFirmwareVersion);

    // Compute sizes and track buffer position
    int packetIndex = 0;
    int packetLength = 7; //<start><length><length> <command id><command data*><crc><crc><end>
    int payloadSize = serializedMcconf.lengthInBytes + 1; //<command id>
    if (optionalCANID != null) {
      packetLength += 2; //<canfwd><canid>
      payloadSize += 2;
    }
    packetLength += serializedMcconf.lengthInBytes; // Command Data

    // Prepare BLE request
    ByteData blePacket = new ByteData(packetLength);
    blePacket.setUint8(packetIndex++, 0x03); // Start of >255 byte packet
    blePacket.setUint16(packetIndex, payloadSize); packetIndex += 2; // Length of data
    if (optionalCANID != null) {
      blePacket.setUint8(packetIndex++, COMM_PACKET_ID.COMM_FORWARD_CAN.index); // CAN FWD
      blePacket.setUint8(packetIndex++, optionalCANID); // CAN ID
    }
    blePacket.setUint8(packetIndex++, COMM_PACKET_ID.COMM_SET_MCCONF.index); // Command ID
    //Copy serialized motor configuration to blePacket
    for (int i=0;i<serializedMcconf.lengthInBytes;++i) {
      blePacket.setInt8(packetIndex++, serializedMcconf.getInt8(i));
    }
    int checksum = CRC16.crc16(blePacket.buffer.asUint8List(), 3, payloadSize);
    blePacket.setUint16(packetIndex, checksum); packetIndex += 2;
    blePacket.setUint8(packetIndex, 0x03); //End of packet

    //globalLogger.wtf("packet len $packetLength, payload size $payloadSize, packet index $packetIndex");

    /*
    * TODO: determine the best way to deliver this data to the ESC
    * TODO: The ESC does not like two big chunks and sometimes small chunks fails
    * TODO: Consider buffering data at BLE module to be relayed between MCUs
    */
    // Send in small chunks?
    int bytesSent = 0;
    while (bytesSent < packetLength && widget.currentDevice != null) {
      int endByte = bytesSent + 20;
      if (endByte > packetLength) {
        endByte = packetLength;
      }
      widget.theTXCharacteristic.write(blePacket.buffer.asUint8List().sublist(bytesSent,endByte), withoutResponse: true);
      bytesSent += 20;
      await Future.delayed(const Duration(milliseconds: 30), () {});
    }
    globalLogger.d("COMM_SET_MCCONF bytes were blasted to ESC =/");

    // Finish with this save attempt
    _writeESCInProgress = false;
  }

  //TODO: very much duplicated from saveMCCONF() -> simplify & improve
  void saveAPPCONF(int optionalCANID) async {
    if (_writeESCInProgress) {
      globalLogger.w("WARNING: esk8Configuration: saveAPPCONF: _writeESCInProgress is true. Save aborted.");
      return;
    }

    // Protect from interrupting a previous write attempt
    _writeESCInProgress = true;
    ESCHelper escHelper = new ESCHelper();
    ByteData serializedAppconf = escHelper.serializeAPPCONF(widget.escAppConfiguration, widget.escFirmwareVersion);

    // Compute sizes and track buffer position
    int packetIndex = 0;
    int packetLength = 7; //<start><length><length> <command id><command data*><crc><crc><end>
    int payloadSize = serializedAppconf.lengthInBytes + 1; //<command id>
    if (optionalCANID != null) {
      packetLength += 2; //<canfwd><canid>
      payloadSize += 2;
    }
    packetLength += serializedAppconf.lengthInBytes; // Command Data

    // Prepare BLE request
    ByteData blePacket = new ByteData(packetLength);
    blePacket.setUint8(packetIndex++, 0x03); // Start of >255 byte packet
    blePacket.setUint16(packetIndex, payloadSize); packetIndex += 2; // Length of data
    if (optionalCANID != null) {
      blePacket.setUint8(packetIndex++, COMM_PACKET_ID.COMM_FORWARD_CAN.index); // CAN FWD
      blePacket.setUint8(packetIndex++, optionalCANID); // CAN ID
    }
    blePacket.setUint8(packetIndex++, COMM_PACKET_ID.COMM_SET_APPCONF.index); // Command ID
    //Copy serialized motor configuration to blePacket
    for (int i=0;i<serializedAppconf.lengthInBytes;++i) {
      blePacket.setInt8(packetIndex++, serializedAppconf.getInt8(i));
    }
    int checksum = CRC16.crc16(blePacket.buffer.asUint8List(), 3, payloadSize);
    blePacket.setUint16(packetIndex, checksum); packetIndex += 2;
    blePacket.setUint8(packetIndex, 0x03); //End of packet

    //globalLogger.wtf("packet len $packetLength, payload size $payloadSize, packet index $packetIndex");

    /*
    * TODO: determine the best way to deliver this data to the ESC
    * TODO: The ESC does not like two big chunks and sometimes small chunks fails
    * TODO: Consider buffering data at BLE module to be relayed between MCUs
    */
    // Send in small chunks?
    int bytesSent = 0;
    while (bytesSent < packetLength && widget.currentDevice != null) {
      int endByte = bytesSent + 20;
      if (endByte > packetLength) {
        endByte = packetLength;
      }
      widget.theTXCharacteristic.write(blePacket.buffer.asUint8List().sublist(bytesSent,endByte), withoutResponse: true);
      bytesSent += 20;
      await Future.delayed(const Duration(milliseconds: 30), () {});
    }
    globalLogger.d("COMM_SET_APPCONF bytes were blasted to ESC =/");

    // Finish with this save attempt
    _writeESCInProgress = false;
  }


  void requestDecodedPPM(int optionalCANID) {
    // Do nothing if we are busy writing to the ESC
    if (_writeESCInProgress || !widget.ppmCalibrateReady) {
      return;
    }

    bool sendCAN = optionalCANID != null;
    var byteData = new ByteData(sendCAN ? 8:6);
    byteData.setUint8(0, 0x02);
    byteData.setUint8(1, sendCAN ? 0x03 : 0x01);
    if (sendCAN) {
      byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
      byteData.setUint8(3, optionalCANID);
    }
    byteData.setUint8(sendCAN ? 4:2, COMM_PACKET_ID.COMM_GET_DECODED_PPM.index);
    int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, sendCAN ? 3:1);
    byteData.setUint16(sendCAN ? 5:3, checksum);
    byteData.setUint8(sendCAN ? 7:5, 0x03); //End of packet

    widget.theTXCharacteristic.write(byteData.buffer.asUint8List()).then((value){
      //globalLogger.d('COMM_GET_DECODED_PPM requested ($optionalCANID)');
    }).catchError((e){
      //globalLogger.w("COMM_GET_DECODED_PPM: Exception: $e");
    });
  }

  // Start and stop PPM streaming timer
  void startStopPPMTimer(bool disableTimer) {
    if (!disableTimer){
      globalLogger.d("Starting PPM calibration timer");
      const duration = const Duration(milliseconds:100);
      ppmCalibrateTimer = new Timer.periodic(duration, (Timer t) => requestDecodedPPM(_selectedCANFwdID));
    } else {
      globalLogger.d("Cancel PPM timer");
      if (ppmCalibrateTimer != null) {
        ppmCalibrateTimer?.cancel();
        ppmCalibrateTimer = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Build: ESK8Configuration");
    if (widget.showESCProfiles) {
      ///ESC Speed Profiles
      return Center(
        child: Column(
          children: <Widget>[
            Icon(
              Icons.timer,
              size: 60.0,
              color: Colors.blue,
            ),
            Center(child:Text("ESC Profiles")),

            Expanded(
              child: ListView.builder(
                primary: false,
                padding: EdgeInsets.all(5),
                itemCount: 3,
                itemBuilder: (context, i) {
                  //TODO: Custom icons!?!
                  Icon rowIcon;
                  switch (i) {
                    case 0:
                      rowIcon = Icon(Icons.filter_1);
                      break;
                    case 1:
                      rowIcon = Icon(Icons.filter_2);
                      break;
                    case 2:
                      rowIcon = Icon(Icons.filter_3);
                      break;
                    case 3:
                      rowIcon = Icon(Icons.filter_4);
                      break;
                    default:
                      rowIcon = Icon(Icons.filter_none);
                      break;
                  }
                  return Column(
                    children: <Widget>[

                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            rowIcon,

                            FutureBuilder<String>(
                                future: ESCHelper.getESCProfileName(i),
                                builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                  if(snapshot.connectionState == ConnectionState.waiting){
                                    return Center(
                                        child:Text("Loading...")
                                    );
                                  }
                                  return Text("${snapshot.data}");
                                }),

                            ElevatedButton(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text("Reset "),
                                  Icon(Icons.flip_camera_android),
                                ],),
                              onPressed: () async {
                                //TODO: reset values
                                await ESCHelper.setESCProfile(i, ESCHelper.getESCProfileDefaults(i));
                                setState(() {

                                });
                              },
                              style: ButtonStyle(backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return Colors.grey[100];
                                }
                                return Colors.transparent;
                              })),
                            ),
                            ElevatedButton(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text("Edit "),
                                  Icon(Icons.edit),
                                ],),
                              onPressed: () async {
                                // navigate to the editor
                                Navigator.of(context).pushNamed(ESCProfileEditor.routeName, arguments: ESCProfileEditorArguments(widget.theTXCharacteristic, await ESCHelper.getESCProfile(i), i, widget.myUserSettings.settings.useImperial));
                              },
                              style: ButtonStyle(backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return Colors.grey[100];
                                }
                                return Colors.transparent;
                              })),
                            ),
                            ElevatedButton(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text("Apply "),
                                  Icon(Icons.exit_to_app),
                                ],),
                              onPressed: () async {
                                setMCCONFTemp(_applyESCProfilePermanently, await ESCHelper.getESCProfile(i));
                              },
                              style: ButtonStyle(backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return Colors.grey[100];
                                }
                                return Colors.transparent;
                              })),
                            )
                          ]
                      ),

                      FutureBuilder<ESCProfile>(
                          future: ESCHelper.getESCProfile(i),
                          builder: (BuildContext context, AsyncSnapshot<ESCProfile> snapshot) {
                            if(snapshot.connectionState == ConnectionState.waiting){
                              return Center(
                                  child:Text("Loading...")
                              );
                            }
                            Table thisTableData = new Table(
                              children: [
                                TableRow(children: [
                                  Text("Speed Forward", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${widget.myUserSettings.settings.useImperial ? kmToMile(snapshot.data.speedKmh) : snapshot.data.speedKmh} ${widget.myUserSettings.settings.useImperial ? "mph" : "km/h"}")
                                ]),
                                TableRow(children: [
                                  Text("Speed Reverse", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${widget.myUserSettings.settings.useImperial ? kmToMile(snapshot.data.speedKmhRev) : snapshot.data.speedKmhRev} ${widget.myUserSettings.settings.useImperial ? "mph" : "km/h"}")
                                ]),
                                TableRow(children: [
                                  Text("Current Accel", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${snapshot.data.l_current_max_scale * 100} %")
                                ]),
                                TableRow(children: [
                                  Text("Current Brake", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${snapshot.data.l_current_min_scale * 100} %")
                                ]),

                              ],
                            );

                            if (snapshot.data.l_watt_max != 0.0) {
                              thisTableData.children.add(new TableRow(children: [
                                Text("Max Power Out", textAlign: TextAlign.right),
                                Text(":"),
                                Text("${snapshot.data.l_watt_max} W")
                              ]));
                            }

                            if (snapshot.data.l_watt_min != 0.0) {
                              thisTableData.children.add(new TableRow(children: [
                                Text("Max Power Regen", textAlign: TextAlign.right),
                                Text(":"),
                                Text("${snapshot.data.l_watt_min} W")
                              ]));
                            }
                            return thisTableData;
                          }),
                      SizedBox(height: 20,)
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              height: 115,
              child: ListView(
                padding: EdgeInsets.all(5),
                primary: false,
                children: <Widget>[
                  SwitchListTile(
                    title: Text("Retain profile after ESC is reset?"),
                    value: _applyESCProfilePermanently,
                    onChanged: (bool newValue) { setState((){_applyESCProfilePermanently = newValue;}); },
                    secondary: const Icon(Icons.memory),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ElevatedButton(child:
                      Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Finished"),Icon(Icons.check),],),
                          onPressed: () {
                            widget.onExitProfiles(false);
                          })
                    ],)
                ],
              ),
            )
          ],
        ),
      );
    }

    if (widget.showESCAppConfig) {
      // Check if we are building with an invalid motor configuration (signature mismatch)
      if (widget.escAppConfiguration == null || widget.escAppConfiguration.imu_conf.gyro_offset_comp_clamp == null) {
        // Invalid APPCONF received
        _invalidCANID = _selectedCANFwdID; // Store invalid ID
        _selectedCANFwdID = null; // Clear selected CAN device
        // Clear selections
        _selectedPPMCtrlType = null;
        _selectedThrExpMode = null;
        _selectedAppMode = null;
        // Request primary ESC application configuration
        widget.requestESCApplicationConfiguration(_selectedCANFwdID);
        return Column( // This view will be replaced when ESC responds with valid configuration
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(
                Icons.settings_applications_outlined,
                size: 80.0,
                color: Colors.blue,
              ),
              Text("Input\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
            ],),

            Icon(Icons.file_download),
            Text("Missing Application Configuration from the ESC"),
            Text("If this problem persists you may need to restart the application")
          ],
        );
      }

      // Select App to use
      if (_selectedAppMode == null) {
        _appModeItems.forEach((item) {
          if (item.value == widget.escAppConfiguration.app_to_use.index) {
            _selectedAppMode = item;
          }
        });
      }
      if (_selectedAppMode == null) {
        widget.escAppConfiguration.app_to_use = app_use.APP_NONE;
        _selectedAppMode = _appModeItems.first;
      }
      showPPMConfiguration = widget.escAppConfiguration.app_to_use == app_use.APP_PPM_UART;
      showNunchukConfiguration = widget.escAppConfiguration.app_to_use == app_use.APP_UART;
      showBalanceConfiguration = widget.escAppConfiguration.app_to_use == app_use.APP_BALANCE;


      // Select PPM control type
      if (_selectedPPMCtrlType == null) {
        _ppmCtrlTypeItems.forEach((item) {
          if (item.value == widget.escAppConfiguration.app_ppm_conf.ctrl_type.index) {
            _selectedPPMCtrlType = item;
          }
        });
      }

      // Select throttle exponent mode
      if (_selectedThrExpMode == null) {
        _thrExpModeItems.forEach((element) {
          if (element.value == widget.escAppConfiguration.app_ppm_conf.throttle_exp_mode.index) {
            _selectedThrExpMode = element;
          }
        });
      }

      // Select nunchuk control type
      if (_selectedNunchukCtrlType == null) {
        _nunchukCtrlTypeItems.forEach((element) {
          if (element.value == widget.escAppConfiguration.app_chuk_conf.ctrl_type.index) {
            _selectedNunchukCtrlType = element;
          }
        });
      }

      // Select nunchuk throttle exponent mode
      if (_selectedThrExpModeNunchuk == null) {
        _thrExpModeNunchukItems.forEach((element) {
          if (element.value == widget.escAppConfiguration.app_chuk_conf.throttle_exp_mode.index) {
            _selectedThrExpModeNunchuk = element;
          }
        });
      }

      // Monitor PPM min and max
      ppmMinMS ??= widget.ppmLastDuration;
      ppmMaxMS ??= widget.ppmLastDuration;
      if (widget.ppmLastDuration != null && widget.ppmLastDuration != 0.0 && widget.ppmLastDuration > ppmMaxMS) ppmMaxMS = widget.ppmLastDuration;
      if (widget.ppmLastDuration != null && widget.ppmLastDuration != 0.0 && widget.ppmLastDuration < ppmMinMS) ppmMinMS = widget.ppmLastDuration;

      if (ppmMinMS != null && ppmMaxMS != null) {
        _rangeSliderDiscreteValues = RangeValues(ppmMinMS / 1000000, ppmMaxMS / 1000000);
      }

      // Perform rounding to make doubles pretty
      widget.escAppConfiguration.app_ppm_conf.hyst = doublePrecision(widget.escAppConfiguration.app_ppm_conf.hyst, 2);
      widget.escAppConfiguration.app_ppm_conf.ramp_time_pos = doublePrecision(widget.escAppConfiguration.app_ppm_conf.ramp_time_pos, 2);
      widget.escAppConfiguration.app_ppm_conf.ramp_time_neg = doublePrecision(widget.escAppConfiguration.app_ppm_conf.ramp_time_neg, 2);
      widget.escAppConfiguration.app_ppm_conf.smart_rev_max_duty = doublePrecision(widget.escAppConfiguration.app_ppm_conf.smart_rev_max_duty, 2);
      widget.escAppConfiguration.app_ppm_conf.smart_rev_ramp_time = doublePrecision(widget.escAppConfiguration.app_ppm_conf.smart_rev_ramp_time, 2);
      widget.escAppConfiguration.app_ppm_conf.throttle_exp_brake = doublePrecision(widget.escAppConfiguration.app_ppm_conf.throttle_exp_brake, 2);
      widget.escAppConfiguration.app_ppm_conf.throttle_exp = doublePrecision(widget.escAppConfiguration.app_ppm_conf.throttle_exp, 2);

      widget.escAppConfiguration.app_balance_conf.fault_adc1 = doublePrecision(widget.escAppConfiguration.app_balance_conf.fault_adc1, 2);
      widget.escAppConfiguration.app_balance_conf.fault_adc2 = doublePrecision(widget.escAppConfiguration.app_balance_conf.fault_adc2, 2);
      widget.escAppConfiguration.app_balance_conf.kp = doublePrecision(widget.escAppConfiguration.app_balance_conf.kp, 4);
      widget.escAppConfiguration.app_balance_conf.ki = doublePrecision(widget.escAppConfiguration.app_balance_conf.ki, 4);
      widget.escAppConfiguration.app_balance_conf.kd = doublePrecision(widget.escAppConfiguration.app_balance_conf.kd, 4);
      widget.escAppConfiguration.app_balance_conf.tiltback_constant = doublePrecision(widget.escAppConfiguration.app_balance_conf.tiltback_constant, 1);
      widget.escAppConfiguration.app_balance_conf.brake_current = doublePrecision(widget.escAppConfiguration.app_balance_conf.brake_current, 2);
      widget.escAppConfiguration.app_balance_conf.tiltback_duty = doublePrecision(widget.escAppConfiguration.app_balance_conf.tiltback_duty, 2);

      widget.escAppConfiguration.app_chuk_conf.hyst = doublePrecision(widget.escAppConfiguration.app_chuk_conf.hyst, 2);
      widget.escAppConfiguration.app_chuk_conf.ramp_time_pos = doublePrecision(widget.escAppConfiguration.app_chuk_conf.ramp_time_pos, 2);
      widget.escAppConfiguration.app_chuk_conf.ramp_time_neg = doublePrecision(widget.escAppConfiguration.app_chuk_conf.ramp_time_neg, 2);
      widget.escAppConfiguration.app_chuk_conf.smart_rev_ramp_time = doublePrecision( widget.escAppConfiguration.app_chuk_conf.smart_rev_ramp_time, 2);
      widget.escAppConfiguration.app_chuk_conf.throttle_exp_brake = doublePrecision(widget.escAppConfiguration.app_chuk_conf.throttle_exp_brake, 2);
      widget.escAppConfiguration.app_chuk_conf.throttle_exp = doublePrecision(widget.escAppConfiguration.app_chuk_conf.throttle_exp, 2);

      // Prepare TECs
      tecIMUHz.text = widget.escAppConfiguration.imu_conf.sample_rate_hz.toString();
      tecIMUHz.selection = TextSelection.fromPosition(TextPosition(offset: tecIMUHz.text.length));
      tecBalanceHz.text = widget.escAppConfiguration.app_balance_conf.hertz.toString();
      tecBalanceHz.selection = TextSelection.fromPosition(TextPosition(offset: tecBalanceHz.text.length));

      tecHalfSwitchFaultDelay.text = widget.escAppConfiguration.app_balance_conf.fault_delay_switch_half.toString();
      tecHalfSwitchFaultDelay.selection = TextSelection.fromPosition(TextPosition(offset: tecHalfSwitchFaultDelay.text.length));
      tecFullSwitchFaultDelay.text = widget.escAppConfiguration.app_balance_conf.fault_delay_switch_full.toString();
      tecFullSwitchFaultDelay.selection = TextSelection.fromPosition(TextPosition(offset: tecFullSwitchFaultDelay.text.length));
      tecHalfStateFaultERPM.text = widget.escAppConfiguration.app_balance_conf.fault_adc_half_erpm.toString();
      tecHalfStateFaultERPM.selection = TextSelection.fromPosition(TextPosition(offset: tecHalfStateFaultERPM.text.length));

      tecKP.text = widget.escAppConfiguration.app_balance_conf.kp.toString();
      tecKP.selection = TextSelection.fromPosition(TextPosition(offset: tecKP.text.length));
      tecKI.text = widget.escAppConfiguration.app_balance_conf.ki.toString();
      tecKI.selection = TextSelection.fromPosition(TextPosition(offset: tecKI.text.length));
      tecKD.text = widget.escAppConfiguration.app_balance_conf.kd.toString();
      tecKD.selection = TextSelection.fromPosition(TextPosition(offset: tecKD.text.length));

      tecTiltbackConstantERPM.text = widget.escAppConfiguration.app_balance_conf.tiltback_constant_erpm.toString();
      tecTiltbackConstantERPM.selection = TextSelection.fromPosition(TextPosition(offset: tecTiltbackConstantERPM.text.length));

      return Container(
          child: Stack(children: <Widget>[
            Center(
              child: GestureDetector(
                onTap: () {
                  // Hide the keyboard
                  FocusScope.of(context).requestFocus(new FocusNode());
                },
                child: Column(
                  children: [
                    /// Header icon and text
                    Column(
                      children: [
                        SizedBox(height: 5,),

                        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                          Icon(
                            Icons.settings_applications_outlined,
                            size: 80.0,
                            color: Colors.blue,
                          ),
                          Text("Input\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                        ],),

                        SizedBox(height:5),
                      ],
                    ),


                    /// Discovered CAN IDs
                    Center(child: Column( children: <Widget>[
                      Text("Discovered Devices"),
                      Container(
                        height: 50,
                        child: GridView.builder(
                          primary: false,
                          itemCount: widget.discoveredCANDevices.length + 1, //NOTE: adding one for the direct ESC
                          gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2, crossAxisSpacing: 1, mainAxisSpacing: 1),
                          itemBuilder: (BuildContext context, int index) {
                            // Direct ESC
                            if (index == 0) {
                              return new Card(
                                shadowColor: Colors.transparent,
                                child: new GridTile(
                                  // GestureDetector to switch the currently selected CAN Forward ID
                                    child: new GestureDetector(
                                      onTap: (){
                                        setState(() {
                                          // Clear selections
                                          _selectedPPMCtrlType = null;
                                          _selectedThrExpMode = null;
                                          _selectedAppMode = null;
                                          // Clear CAN Forward
                                          _selectedCANFwdID = null;
                                          // Request primary ESC application configuration
                                          widget.requestESCApplicationConfiguration(_selectedCANFwdID);
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(SnackBar(content: Text("Requesting ESC application configuration from primary ESC")));
                                        });
                                      },
                                      child: Stack(
                                        children: <Widget>[



                                          new Center(child: Text(_selectedCANFwdID == null ? "Direct (Active)" :"Direct", style: TextStyle(fontSize: 12)),),
                                          new ClipRRect(
                                              borderRadius: new BorderRadius.circular(10),
                                              child: new Container(
                                                decoration: new BoxDecoration(
                                                  color: _selectedCANFwdID == null ? Theme.of(context).focusColor : Colors.transparent,
                                                ),
                                              )
                                          )


                                        ],
                                      ),
                                    )
                                ),
                              );
                            }
                            // CAN IDs
                            bool isCANIDSelected = false;
                            if (_selectedCANFwdID == widget.discoveredCANDevices[index-1]) {
                              isCANIDSelected = true;
                            }
                            String invalidDevice = "";
                            if (_invalidCANID == widget.discoveredCANDevices[index-1]) {
                              invalidDevice = " (Invalid)";
                            }
                            return new Card(
                              shadowColor: Colors.transparent,
                              child: new GridTile(
                                // GestureDetector to switch the currently selected CAN Forward ID
                                  child: new GestureDetector(
                                    onTap: (){
                                      if (isCANIDSelected) {
                                        setState(() {
                                          // Clear CAN Forward
                                          _selectedCANFwdID = null;
                                          // Request primary ESC application configuration
                                          widget.requestESCApplicationConfiguration(_selectedCANFwdID);
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(SnackBar(content: Text("Requesting ESC application configuration from primary ESC")));
                                        });
                                      } else {
                                        if (_invalidCANID != widget.discoveredCANDevices[index-1]) {
                                          _selectedCANFwdID = widget.discoveredCANDevices[index-1];
                                          // Request APPCONF from CAN device
                                          widget.requestESCApplicationConfiguration(_selectedCANFwdID);
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(SnackBar(content: Text("Requesting ESC application configuration from CAN ID $_selectedCANFwdID")));
                                        }

                                      }
                                    },
                                    child: Stack(
                                      children: <Widget>[



                                        new Center(child: Text("ID ${widget.discoveredCANDevices[index-1]}${isCANIDSelected?" (Active)":""}$invalidDevice", style: TextStyle(fontSize: 12)),),
                                        new ClipRRect(
                                            borderRadius: new BorderRadius.circular(10),
                                            child: new Container(
                                              decoration: new BoxDecoration(
                                                color: isCANIDSelected ? Theme.of(context).focusColor : Colors.transparent,
                                              ),
                                            )
                                        )


                                      ],
                                    ),
                                  )
                              ),
                            );
                          },
                        )
                      )
                    ],)
                    ),


                    /// List view content
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                        children: <Widget>[

                          Divider(thickness: 3),
                          Text("Select Application Mode"),
                          Center(child:
                          DropdownButton<ListItem>(
                            value: _selectedAppMode,
                            items: _appModeDropdownItems,
                            onChanged: (newValue) {
                              setState(() {
                                _selectedAppMode = newValue;
                                widget.escAppConfiguration.app_to_use = app_use.values[newValue.value];
                                showPPMConfiguration = widget.escAppConfiguration.app_to_use == app_use.APP_PPM_UART;
                                showNunchukConfiguration = widget.escAppConfiguration.app_to_use == app_use.APP_UART;
                                showBalanceConfiguration = widget.escAppConfiguration.app_to_use == app_use.APP_BALANCE;
                              });
                            },
                          )
                          ),
                          //TODO: User control needed? Text("app can ${widget.escAppConfiguration.can_mode}"),

                          // Show Balance Options
                          showBalanceConfiguration ? Column(
                            children: [
                              Divider(thickness: 3),
                              Text("${widget.escAppConfiguration.imu_conf.mode}"),
                              TextField(
                                  controller: tecIMUHz,
                                  decoration: new InputDecoration(labelText: "IMU Hz"),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly
                                  ]
                              ),
                              TextField(
                                  controller: tecBalanceHz,
                                  decoration: new InputDecoration(labelText: "Main Loop Hz"),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly
                                  ]
                              ),

                              SizedBox(height:10),
                              Text("ADC1 Fault ${widget.escAppConfiguration.app_balance_conf.fault_adc1}"),
                              Slider(
                                value: widget.escAppConfiguration.app_balance_conf.fault_adc1,
                                min: 0.0,
                                max: 3.3,
                                label: "${widget.escAppConfiguration.app_balance_conf.fault_adc1}",
                                onChanged: (value) {
                                  setState(() {
                                    widget.escAppConfiguration.app_balance_conf.fault_adc1 = doublePrecision(value, 1);
                                  });
                                },
                              ),

                              Text("ADC2 Fault ${widget.escAppConfiguration.app_balance_conf.fault_adc2}"),
                              Slider(
                                value: widget.escAppConfiguration.app_balance_conf.fault_adc2,
                                min: 0.0,
                                max: 3.3,
                                label: "${widget.escAppConfiguration.app_balance_conf.fault_adc2}",
                                onChanged: (value) {
                                  setState(() {
                                    widget.escAppConfiguration.app_balance_conf.fault_adc2 = doublePrecision(value, 1);
                                  });
                                },
                              ),

                              // NOTE: Not in FW5.1
                              widget.escAppConfiguration.app_balance_conf.fault_delay_switch_half != null ? TextField(
                                  controller: tecHalfSwitchFaultDelay,
                                  decoration: new InputDecoration(labelText: "Half Switch Fault Delay (ms)"),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly
                                  ]
                              ) : Container(),
                              // NOTE: Not in FW5.1
                              widget.escAppConfiguration.app_balance_conf.fault_delay_switch_full != null ? TextField(
                                  controller: tecFullSwitchFaultDelay,
                                  decoration: new InputDecoration(labelText: "Full Switch Fault Delay (ms)"),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly
                                  ]
                              ) : Container(),
                              TextField(
                                  controller: tecHalfStateFaultERPM,
                                  decoration: new InputDecoration(labelText: "Half State Fault ERPM"),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly
                                  ]
                              ),


                              TextField(
                                  controller: tecKP,
                                  decoration: new InputDecoration(labelText: "PID (P gain)"),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.allow(formatPositiveDouble)
                                  ]
                              ),
                              TextField(
                                  controller: tecKI,
                                  decoration: new InputDecoration(labelText: "PID (I gain)"),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.allow(formatPositiveDouble)
                                  ]
                              ),
                              TextField(
                                  controller: tecKD,
                                  decoration: new InputDecoration(labelText: "PID (D gain)"),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.allow(formatPositiveDouble)
                                  ]
                              ),


                              SizedBox(height: 10),
                              Text("Constant Tiltback ${widget.escAppConfiguration.app_balance_conf.tiltback_constant}°"),
                              SmartSlider(
                                value: widget.escAppConfiguration.app_balance_conf.tiltback_constant,
                                mini: -20,
                                maxi: 20,
                                label: "${widget.escAppConfiguration.app_balance_conf.tiltback_constant.toInt()}",
                                onChanged: (value) {
                                  setState(() {
                                    widget.escAppConfiguration.app_balance_conf.tiltback_constant = value.toInt().toDouble();
                                  });
                                },
                              ),

                              TextField(
                                  controller: tecTiltbackConstantERPM,
                                  decoration: new InputDecoration(labelText: "Constant Tiltback ERPM"),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly
                                  ]
                              ),

                              SizedBox(height:10),
                              Text("Duty Cycle Tiltback ${widget.escAppConfiguration.app_balance_conf.tiltback_duty}"),
                              SmartSlider(
                                value: widget.escAppConfiguration.app_balance_conf.tiltback_duty,
                                mini: 0.0,
                                maxi: 1.0,
                                label: "${widget.escAppConfiguration.app_balance_conf.tiltback_duty}",
                                onChanged: (value) {
                                  setState(() {
                                    widget.escAppConfiguration.app_balance_conf.tiltback_duty = doublePrecision(value, 2);
                                  });
                                },
                              ),

                              SizedBox(height:10),
                              Text("Brake Current ${widget.escAppConfiguration.app_balance_conf.brake_current} Amps"),
                              SmartSlider(
                                value: widget.escAppConfiguration.app_balance_conf.brake_current,
                                mini: 0.0,
                                maxi: 20.0,
                                label: "${widget.escAppConfiguration.app_balance_conf.brake_current}",
                                onChanged: (value) {
                                  setState(() {
                                    widget.escAppConfiguration.app_balance_conf.brake_current = doublePrecision(value, 1);
                                  });
                                },
                              ),

                              //Text("current_boost ${widget.escAppConfiguration.app_balance_conf.current_boost}"),
                              //Text("deadzone ${widget.escAppConfiguration.app_balance_conf.deadzone}"),
                              //Text("fault_duty ${widget.escAppConfiguration.app_balance_conf.fault_duty}"),
                              //NOTE: Secondary tuning
                              //Text("accel_confidence_decay ${widget.escAppConfiguration.imu_conf.accel_confidence_decay}"),
                              //Text("imu_conf.mahony_kp ${widget.escAppConfiguration.imu_conf.mahony_kp}"),
                              //Text("imu_conf.mahony_ki ${widget.escAppConfiguration.imu_conf.mahony_ki}"),
                              //Text("imu_conf.madgwick_beta ${widget.escAppConfiguration.imu_conf.madgwick_beta}"),
                            ],
                          ) : Container(),

                          // Show PPM Options
                          showPPMConfiguration ? Column(
                            children: [
                            Divider(thickness: 3),
                            Text("Calibrate PPM"),

                            ElevatedButton(onPressed: (){
                              // If we are not currently calibrating...
                              if (!ppmCalibrate) {
                                // Clear the captured values when starting calibration
                                ppmMinMS = null;
                                ppmMaxMS = null;
                                // Capture the current PPM control type to restore when finished
                                ppmCalibrateControlTypeToRestore = widget.escAppConfiguration.app_ppm_conf.ctrl_type;
                                // Set the control type to none or the ESC will go WILD
                                widget.escAppConfiguration.app_ppm_conf.ctrl_type = ppm_control_type.PPM_CTRL_TYPE_NONE;
                                _selectedPPMCtrlType = null; // Clear selection
                                // Apply the configuration to the ESC
                                if (widget.currentDevice != null) {
                                  // Save application configuration; CAN FWD ID can be null
                                  Future.delayed(Duration(milliseconds: 250), (){
                                    saveAPPCONF(_selectedCANFwdID);
                                  });
                                }
                                // Start calibration routine
                                setState(() {
                                  widget.notifyStopStartPPMCalibrate(true);
                                  ppmCalibrate = true;
                                  startStopPPMTimer(false);
                                });
                              } else {
                                // Stop calibration routine
                                setState(() {
                                  widget.notifyStopStartPPMCalibrate(false);
                                  ppmCalibrate = false;
                                  startStopPPMTimer(true);
                                });

                                // If we did not receive any PPM information we cannot save the changes
                                if (widget.ppmLastDuration == null) {
                                  setState(() {
                                    // Restore the user's PPM control type
                                    widget.escAppConfiguration.app_ppm_conf.ctrl_type = ppmCalibrateControlTypeToRestore;
                                    _selectedPPMCtrlType = null; // Clear selection
                                    Future.delayed(Duration(milliseconds: 250), (){
                                      saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                                    });
                                  });
                                  return;
                                }

                                // Ask user if they are satisfied with the calibration results
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Accept Calibration?'),
                                      content: SingleChildScrollView(
                                        child: ListBody(
                                          children: <Widget>[
                                            Text('PPM values captured'),
                                            Text("Start: ${doublePrecision(ppmMinMS / 1000000, 3)}"),
                                            Text("Center: ${doublePrecision(widget.ppmLastDuration / 1000000, 3)}"),
                                            Text("End: ${doublePrecision(ppmMaxMS / 1000000, 3)}"),
                                            SizedBox(height:10),
                                            Text('If you are satisfied with the results select Accept write values to the ESC')
                                          ],
                                        ),
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: Text('Reject'),
                                          onPressed: () {
                                            setState(() {
                                              ppmMinMS = null;
                                              ppmMaxMS = null;
                                              // Restore the user's PPM control type
                                              widget.escAppConfiguration.app_ppm_conf.ctrl_type = ppmCalibrateControlTypeToRestore;
                                              _selectedPPMCtrlType = null; // Clear selection
                                              Future.delayed(Duration(milliseconds: 250), (){
                                                saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                                              });
                                            });
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text('Accept'),
                                          onPressed: () {
                                            setState(() {
                                              // Restore the user's PPM control type
                                              widget.escAppConfiguration.app_ppm_conf.ctrl_type = ppmCalibrateControlTypeToRestore;
                                              _selectedPPMCtrlType = null; // Clear selection
                                              // Set values from calibration
                                              widget.escAppConfiguration.app_ppm_conf.pulse_start = ppmMinMS / 1000000;
                                              widget.escAppConfiguration.app_ppm_conf.pulse_center = widget.ppmLastDuration / 1000000;
                                              widget.escAppConfiguration.app_ppm_conf.pulse_end = ppmMaxMS / 1000000;
                                              // Apply the configuration to the ESC
                                              Future.delayed(Duration(milliseconds: 250), (){
                                                saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                                              });
                                            });
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }

                            }, child: Text(ppmCalibrate ? widget.ppmCalibrateReady ? "Stop Calibration": "Starting Calibration..." : "Calibrate PPM"),),

                            Stack(children: [
                              RangeSlider(
                                values: _rangeSliderDiscreteValues,
                                min: ppmMinMS == null ? 0.5 : ppmMinMS / 1000000,
                                max: ppmMaxMS == null ? 2.5 : ppmMaxMS / 1000000,
                                labels: RangeLabels(
                                  _rangeSliderDiscreteValues.start.round().toString(),
                                  _rangeSliderDiscreteValues.end.round().toString(),
                                ),
                                onChanged: (values) {},
                              ),
                              widget.ppmLastDuration != null && widget.ppmLastDuration != 0.0 ? SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbColor: Colors.redAccent,
                                  ),
                                  child: Slider(
                                    value: widget.ppmLastDuration / 1000000,
                                    min: ppmMinMS == null ? 0.5 : ppmMinMS / 1000000,
                                    max: ppmMaxMS == null ? 2.5 : ppmMaxMS / 1000000,
                                    label: (widget.ppmLastDuration / 1000000).toString(),
                                    onChanged: (value) {},
                                  )) : Container(),
                            ],),


                            Table(children: [
                              TableRow(children: [
                                Text(""),
                                Text("Calibrate PPM"),
                                Text("ESC Config")
                              ]),
                              TableRow(children: [
                                Text("Start"),
                                Text("${ppmMinMS != null ? ppmMinMS / 1000000 : ""}"),
                                Text("${doublePrecision(widget.escAppConfiguration.app_ppm_conf.pulse_start, 3)}")
                              ]),
                              TableRow(children: [
                                Text("Center"),
                                Text("${widget.ppmLastDuration != null ? widget.ppmLastDuration / 1000000 : ""}"),
                                Text("${doublePrecision(widget.escAppConfiguration.app_ppm_conf.pulse_center, 3)}")
                              ]),
                              TableRow(children: [
                                Text("End"),
                                Text("${ppmMaxMS != null ? ppmMaxMS / 1000000 : ""}"),
                                Text("${doublePrecision(widget.escAppConfiguration.app_ppm_conf.pulse_end, 3)}")
                              ]),
                            ],),

                            Divider(thickness: 3),
                            Text("Select PPM Control Type"),
                            Center(child:
                            DropdownButton<ListItem>(
                              value: _selectedPPMCtrlType,
                              items: _ppmCtrlTypeDropdownItems,
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedPPMCtrlType = newValue;
                                  widget.escAppConfiguration.app_ppm_conf.ctrl_type = ppm_control_type.values[newValue.value];
                                });
                              },
                            )
                            ),

                            Text("Input deadband: ${(widget.escAppConfiguration.app_ppm_conf.hyst * 100.0).toInt()}% (15% = default)"),
                            SmartSlider(
                              value: widget.escAppConfiguration.app_ppm_conf.hyst,
                              mini: 0.01,
                              maxi: 0.35,
                              divisions: 100,
                              label: "${(widget.escAppConfiguration.app_ppm_conf.hyst * 100.0).toInt()}%",
                              onChanged: (value) {
                                setState(() {
                                  widget.escAppConfiguration.app_ppm_conf.hyst = value;
                                });
                              },
                            ),

                            ElevatedButton(onPressed: (){
                              setState(() {
                                showAdvancedOptions = !showAdvancedOptions;
                              });
                            },
                              child: Text("${showAdvancedOptions?"Hide":"Show"} Advanced Options"),),

                            showAdvancedOptions ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SwitchListTile(
                                  title: Text("Median Filter (default = on)"),
                                  value: widget.escAppConfiguration.app_ppm_conf.median_filter,
                                  onChanged: (bool newValue) { setState((){ widget.escAppConfiguration.app_ppm_conf.median_filter = newValue;}); },
                                  secondary: const Icon(Icons.filter_tilt_shift),
                                ),
                                SwitchListTile(
                                  title: Text("Safe Start (default = on)"),
                                  value: widget.escAppConfiguration.app_ppm_conf.safe_start,
                                  onChanged: (bool newValue) { setState((){ widget.escAppConfiguration.app_ppm_conf.safe_start = newValue;}); },
                                  secondary: const Icon(Icons.not_started),
                                ),
                                Text("Positive Ramping Time: ${doublePrecision(widget.escAppConfiguration.app_ppm_conf.ramp_time_pos,2)} seconds (0.4 = default)"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_ppm_conf.ramp_time_pos,
                                  mini: 0.01,
                                  maxi: 0.5,
                                  divisions: 100,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.ramp_time_pos} seconds",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.ramp_time_pos = value;
                                    });
                                  },
                                ),
                                Text("Negative Ramping Time: ${widget.escAppConfiguration.app_ppm_conf.ramp_time_neg} seconds (0.2 = default)"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_ppm_conf.ramp_time_neg,
                                  mini: 0.01,
                                  maxi: 0.5,
                                  divisions: 100,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.ramp_time_neg} seconds",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.ramp_time_neg = value;
                                    });
                                  },
                                ),
                                Text("PID Max ERPM ${widget.escAppConfiguration.app_ppm_conf.pid_max_erpm} (15000 = default)"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_ppm_conf.pid_max_erpm,
                                  mini: 10000.0,
                                  maxi: 30000.0,
                                  divisions: 100,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.pid_max_erpm}",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.pid_max_erpm = value.toInt().toDouble();
                                    });
                                  },
                                ),
                                Text("Max ERPM for direction switch ${widget.escAppConfiguration.app_ppm_conf.max_erpm_for_dir} (4000 = default)"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_ppm_conf.max_erpm_for_dir,
                                  mini: 1000.0,
                                  maxi: 8000.0,
                                  divisions: 700,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.max_erpm_for_dir}",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.max_erpm_for_dir = value.toInt().toDouble();
                                    });
                                  },
                                ),
                                Text("Smart Reverse Max Duty Cycle ${doublePrecision(widget.escAppConfiguration.app_ppm_conf.smart_rev_max_duty,2)} (0.07 = default)"),
                                Slider(
                                  value: widget.escAppConfiguration.app_ppm_conf.smart_rev_max_duty,
                                  min: 0,
                                  max: 1,
                                  divisions: 100,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.smart_rev_max_duty}",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.smart_rev_max_duty = value;
                                    });
                                  },
                                ),
                                Text("Smart Reverse Ramp Time ${widget.escAppConfiguration.app_ppm_conf.smart_rev_ramp_time} seconds (3.0 = default)"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_ppm_conf.smart_rev_ramp_time,
                                  mini: 1,
                                  maxi: 10,
                                  divisions: 1000,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.smart_rev_ramp_time}",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.smart_rev_ramp_time = value;
                                    });
                                  },
                                ),

                                Text("Select Throttle Exponential Mode"),
                                Center(child:
                                DropdownButton<ListItem>(
                                  value: _selectedThrExpMode,
                                  items: _thrExpModeDropdownItems,
                                  onChanged: (newValue) {
                                    setState(() {
                                      _selectedThrExpMode = newValue;
                                      widget.escAppConfiguration.app_ppm_conf.throttle_exp_mode = thr_exp_mode.values[newValue.value];
                                    });
                                  },
                                )
                                ),
                                Center(child: Container(
                                  height: 100,
                                  child: CustomPaint(
                                    painter: CurvePainter(
                                      width: 100,
                                      exp: widget.escAppConfiguration.app_ppm_conf.throttle_exp,
                                      expNegative: widget.escAppConfiguration.app_ppm_conf.throttle_exp_brake,
                                      expMode: widget.escAppConfiguration.app_ppm_conf.throttle_exp_mode,
                                    ),
                                  ),
                                )
                                ),
                                Text("Throttle Exponent ${widget.escAppConfiguration.app_ppm_conf.throttle_exp}"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_ppm_conf.throttle_exp,
                                  mini: -5,
                                  maxi: 5,
                                  divisions: 100,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.throttle_exp}",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.throttle_exp = value;
                                    });
                                  },
                                ),

                                Text("Throttle Exponent Brake ${widget.escAppConfiguration.app_ppm_conf.throttle_exp_brake}"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_ppm_conf.throttle_exp_brake,
                                  mini: -5,
                                  maxi: 5,
                                  divisions: 100,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.throttle_exp_brake}",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.throttle_exp_brake = value;
                                    });
                                  },
                                ),


                                SwitchListTile(
                                  title: Text("Enable Traction Control"),
                                  value: widget.escAppConfiguration.app_ppm_conf.tc,
                                  onChanged: (bool newValue) { setState((){ widget.escAppConfiguration.app_ppm_conf.tc = newValue;}); },
                                  secondary: const Icon(Icons.compare_arrows),
                                ),
                                //Text("traction control ${widget.escAppConfiguration.app_ppm_conf.tc}"),
                                Text("Traction Control ERPM ${widget.escAppConfiguration.app_ppm_conf.tc_max_diff} (3000 = default)"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_ppm_conf.tc_max_diff,
                                  mini: 1000.0,
                                  maxi: 5000.0,
                                  divisions: 1000,
                                  label: "${widget.escAppConfiguration.app_ppm_conf.tc_max_diff}",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_ppm_conf.tc_max_diff = value.toInt().toDouble();
                                    });
                                  },
                                ),


                                //TODO: Allow user control? Text("multi esc ${widget.escAppConfiguration.app_ppm_conf.multi_esc} (uh this needs to be true)"),

                              ],) : Container(),

                            showAdvancedOptions ? ElevatedButton(onPressed: (){
                              setState(() {
                                showAdvancedOptions = false;
                              });
                            }, child: Text("Hide Advanced Options"),) : Container(),

                          ],) : Container(),

                          showNunchukConfiguration ? Column(
                              children: [
                                Divider(thickness: 3),
                                Text("UART Config"),

                                Center(child:
                                DropdownButton<ListItem>(
                                  value: _selectedNunchukCtrlType,
                                  items: _nunchuckCtrlTypeDropdownItems,
                                  onChanged: (newValue) {
                                    setState(() {
                                      _selectedNunchukCtrlType = newValue;
                                      widget.escAppConfiguration.app_chuk_conf.ctrl_type = chuk_control_type.values[newValue.value];
                                    });
                                  },
                                )
                                ),

                                //TODO: We don't want this disabled: Text("${widget.escAppConfiguration.app_chuk_conf.multi_esc}"),


                                Text("Input deadband: ${(widget.escAppConfiguration.app_chuk_conf.hyst * 100).toInt()}% (15% = default)"),
                                SmartSlider(
                                  value: widget.escAppConfiguration.app_chuk_conf.hyst,
                                  mini: 0.01,
                                  maxi: 0.35,
                                  divisions: 100,
                                  label: "${(widget.escAppConfiguration.app_chuk_conf.hyst * 100).toInt()}%",
                                  onChanged: (value) {
                                    setState(() {
                                      widget.escAppConfiguration.app_chuk_conf.hyst = value;
                                    });
                                  },
                                ),

                                // Smart reverse doesn't work in Current Bidirectional mode
                                widget.escAppConfiguration.app_chuk_conf.ctrl_type != chuk_control_type.CHUK_CTRL_TYPE_CURRENT_BIDIRECTIONAL ?
                                    Column(children: [
                                      SwitchListTile(
                                        title: Text("Smart Reverse (default = on)"),
                                        value: widget.escAppConfiguration.app_chuk_conf.use_smart_rev,
                                        onChanged: (bool newValue) { setState((){ widget.escAppConfiguration.app_chuk_conf.use_smart_rev = newValue;}); },
                                        secondary: const Icon(Icons.filter_tilt_shift),
                                      ),

                                      Text("Smart Reverse Max Duty Cycle ${(widget.escAppConfiguration.app_chuk_conf.smart_rev_max_duty * 100).toInt()}% (7% = default)"),
                                      Slider(
                                        value: widget.escAppConfiguration.app_chuk_conf.smart_rev_max_duty,
                                        min: 0,
                                        max: 1,
                                        divisions: 100,
                                        label: "${(widget.escAppConfiguration.app_chuk_conf.smart_rev_max_duty * 100).toInt()}%",
                                        onChanged: (value) {
                                          setState(() {
                                            widget.escAppConfiguration.app_chuk_conf.smart_rev_max_duty = value;
                                          });
                                        },
                                      ),

                                      Text("Smart Reverse Ramp Time ${widget.escAppConfiguration.app_chuk_conf.smart_rev_ramp_time} seconds (3.0 = default)"),
                                      SmartSlider(
                                        value: widget.escAppConfiguration.app_chuk_conf.smart_rev_ramp_time,
                                        mini: 1,
                                        maxi: 10,
                                        divisions: 90,
                                        label: "${widget.escAppConfiguration.app_chuk_conf.smart_rev_ramp_time}",
                                        onChanged: (value) {
                                          setState(() {
                                            widget.escAppConfiguration.app_chuk_conf.smart_rev_ramp_time = value;
                                          });
                                        },
                                      ),
                                    ]) : Container(),


                                ElevatedButton(onPressed: (){
                                  setState(() {
                                    showAdvancedOptions = !showAdvancedOptions;
                                  });
                                },
                                  child: Text("${showAdvancedOptions?"Hide":"Show"} Advanced Options"),),

                                showAdvancedOptions ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    Text("Positive Ramping Time: ${doublePrecision(widget.escAppConfiguration.app_chuk_conf.ramp_time_pos,2)} seconds (0.4 = default)"),
                                    SmartSlider(
                                      value: widget.escAppConfiguration.app_chuk_conf.ramp_time_pos,
                                      mini: 0.01,
                                      maxi: 0.5,
                                      divisions: 100,
                                      label: "${widget.escAppConfiguration.app_chuk_conf.ramp_time_pos} seconds",
                                      onChanged: (value) {
                                        setState(() {
                                          widget.escAppConfiguration.app_chuk_conf.ramp_time_pos = value;
                                        });
                                      },
                                    ),

                                    Text("Negative Ramping Time: ${widget.escAppConfiguration.app_chuk_conf.ramp_time_neg} seconds (0.2 = default)"),
                                    SmartSlider(
                                      value: widget.escAppConfiguration.app_chuk_conf.ramp_time_neg,
                                      mini: 0.01,
                                      maxi: 0.5,
                                      divisions: 100,
                                      label: "${widget.escAppConfiguration.app_chuk_conf.ramp_time_neg} seconds",
                                      onChanged: (value) {
                                        setState(() {
                                          widget.escAppConfiguration.app_chuk_conf.ramp_time_neg = value;
                                        });
                                      },
                                    ),

                                    //TODO: Text("eRPM/s w/CruiseControl (3000 = default) ${widget.escAppConfiguration.app_chuk_conf.stick_erpm_per_s_in_cc}"),

                                    Text("Select Throttle Exponential Mode"),
                                    Center(child:
                                    DropdownButton<ListItem>(
                                      value: _selectedThrExpModeNunchuk,
                                      items: _thrExpModeNunchukDropdownItems,
                                      onChanged: (newValue) {
                                        setState(() {
                                          _selectedThrExpModeNunchuk = newValue;
                                          widget.escAppConfiguration.app_chuk_conf.throttle_exp_mode = thr_exp_mode.values[newValue.value];
                                        });
                                      },
                                    )
                                    ),

                                    Center(child: Container(
                                      height: 100,
                                      child: CustomPaint(
                                        painter: CurvePainter(
                                          width: 100,
                                          exp: widget.escAppConfiguration.app_chuk_conf.throttle_exp,
                                          expNegative: widget.escAppConfiguration.app_chuk_conf.throttle_exp_brake,
                                          expMode: widget.escAppConfiguration.app_chuk_conf.throttle_exp_mode,
                                        ),
                                      ),
                                    )
                                    ),
                                    Text("Throttle Exponent ${widget.escAppConfiguration.app_chuk_conf.throttle_exp}"),
                                    SmartSlider(
                                      value: widget.escAppConfiguration.app_chuk_conf.throttle_exp,
                                      mini: -5,
                                      maxi: 5,
                                      divisions: 100,
                                      label: "${widget.escAppConfiguration.app_chuk_conf.throttle_exp}",
                                      onChanged: (value) {
                                        setState(() {
                                          widget.escAppConfiguration.app_chuk_conf.throttle_exp = value;
                                        });
                                      },
                                    ),

                                    Text("Throttle Exponent Brake ${widget.escAppConfiguration.app_chuk_conf.throttle_exp_brake}"),
                                    SmartSlider(
                                      value: widget.escAppConfiguration.app_chuk_conf.throttle_exp_brake,
                                      mini: -5,
                                      maxi: 5,
                                      divisions: 100,
                                      label: "${widget.escAppConfiguration.app_chuk_conf.throttle_exp_brake}",
                                      onChanged: (value) {
                                        setState(() {
                                          widget.escAppConfiguration.app_chuk_conf.throttle_exp_brake = value;
                                        });
                                      },
                                    ),


                                    SwitchListTile(
                                      title: Text("Enable Traction Control"),
                                      value: widget.escAppConfiguration.app_chuk_conf.tc,
                                      onChanged: (bool newValue) { setState((){ widget.escAppConfiguration.app_chuk_conf.tc = newValue;}); },
                                      secondary: const Icon(Icons.compare_arrows),
                                    ),

                                    Text("Traction Control ERPM ${widget.escAppConfiguration.app_chuk_conf.tc_max_diff} (3000 = default)"),
                                    SmartSlider(
                                      value: widget.escAppConfiguration.app_chuk_conf.tc_max_diff,
                                      mini: 1000.0,
                                      maxi: 5000.0,
                                      divisions: 1000,
                                      label: "${widget.escAppConfiguration.app_chuk_conf.tc_max_diff}",
                                      onChanged: (value) {
                                        setState(() {
                                          widget.escAppConfiguration.app_chuk_conf.tc_max_diff = value.toInt().toDouble();
                                        });
                                      },
                                    ),

                                  ],) : Container(),

                                showAdvancedOptions ? ElevatedButton(onPressed: (){
                                  setState(() {
                                    showAdvancedOptions = false;
                                  });
                                }, child: Text("Hide Advanced Options"),) : Container(),


                              ]
                          ) : Container(),

                          ElevatedButton(
                              child: Text("Save to ESC${_selectedCANFwdID != null ? "/CAN $_selectedCANFwdID" : ""}"),
                              onPressed: () {
                                if (widget.currentDevice != null) {
                                  //setState(() {
                                  // Save application configuration; CAN FWD ID can be null
                                  saveAPPCONF(_selectedCANFwdID);
                                }
                              }),

                          // PPM Default All
                          showPPMConfiguration ? ElevatedButton(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.warning_amber_outlined),
                                Text("Set ALL to default")
                              ],),
                              onPressed: () {
                                setState(() {
                                  widget.escAppConfiguration.app_to_use = app_use.APP_PPM_UART;
                                  _selectedAppMode = null;
                                  widget.escAppConfiguration.app_ppm_conf.pulse_start = 1.0;
                                  widget.escAppConfiguration.app_ppm_conf.pulse_end = 2.0;
                                  widget.escAppConfiguration.app_ppm_conf.pulse_center = 1.5;
                                  widget.escAppConfiguration.app_ppm_conf.ctrl_type = ppm_control_type.PPM_CTRL_TYPE_NONE;
                                  _selectedPPMCtrlType = null;
                                  widget.escAppConfiguration.app_ppm_conf.median_filter = true;
                                  widget.escAppConfiguration.app_ppm_conf.safe_start = true;
                                  widget.escAppConfiguration.app_ppm_conf.ramp_time_pos = 0.4;
                                  widget.escAppConfiguration.app_ppm_conf.ramp_time_neg = 0.2;
                                  widget.escAppConfiguration.app_ppm_conf.pid_max_erpm = 15000.0;
                                  widget.escAppConfiguration.app_ppm_conf.max_erpm_for_dir = 4000.0;
                                  widget.escAppConfiguration.app_ppm_conf.smart_rev_max_duty = 0.07;
                                  widget.escAppConfiguration.app_ppm_conf.smart_rev_ramp_time = 3.0;
                                  widget.escAppConfiguration.app_ppm_conf.throttle_exp_mode = thr_exp_mode.THR_EXP_POLY;
                                  _selectedThrExpMode = null;
                                  widget.escAppConfiguration.app_ppm_conf.throttle_exp = 0.0;
                                  widget.escAppConfiguration.app_ppm_conf.throttle_exp_brake = 0.0;
                                  widget.escAppConfiguration.app_ppm_conf.tc = false;
                                  widget.escAppConfiguration.app_ppm_conf.tc_max_diff = 3000.0;
                                  widget.escAppConfiguration.app_ppm_conf.hyst = 0.15;
                                });
                              }) : Container(),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            /// Close button
            Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: (){
                      globalLogger.d("User Close Input Configuration");
                      genericConfirmationDialog(
                          context,
                          TextButton(
                            child: Text("Not yet"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: Text("Yes"),
                            onPressed: () async {
                              Navigator.of(context).pop();
                              widget.closeESCApplicationConfigurator(true);
                            },
                          ),
                          "Exit Input Configuration?",
                          Text("Unsaved changes will be lost.")
                      );
                    }
                )
            ),
          ],)
      );

    }

    if (widget.showESCConfigurator) {
      // Check if we are building with an invalid motor configuration (signature mismatch)
      if (widget.escMotorConfiguration == null || widget.escMotorConfiguration.si_battery_ah == null) {
        // Invalid MCCONF received
        _invalidCANID = _selectedCANFwdID; // Store invalid ID
        _selectedCANFwdID = null; // Clear selected CAN device
        widget.onAutoloadESCSettings(true); // Request primary ESC configuration
        return Column( // This view will be replaced when ESC responds with valid configuration
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(
                Icons.settings_applications,
                size: 80.0,
                color: Colors.blue,
              ),
              Text("Motor\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
            ],),

            Icon(Icons.file_download),
            Text("Missing Motor Configuration from the ESC"),
            Text("If this problem persists you may need to restart the application")
          ],
        );
      }

      // Prepare text editing controllers
      tecBatterySeriesCount.text = widget.escMotorConfiguration.si_battery_cells.toString();
      tecBatterySeriesCount.selection = TextSelection.fromPosition(TextPosition(offset: tecBatterySeriesCount.text.length));
      tecBatteryCapacityAh.text = doublePrecision(widget.escMotorConfiguration.si_battery_ah,2).toString();
      tecBatteryCapacityAh.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCapacityAh.text.length));
      tecWheelDiameterMillimeters.text = doublePrecision(widget.escMotorConfiguration.si_wheel_diameter * 1000.0, 3).toInt().toString();
      tecWheelDiameterMillimeters.selection = TextSelection.fromPosition(TextPosition(offset: tecWheelDiameterMillimeters.text.length));
      tecMotorPoles.text = widget.escMotorConfiguration.si_motor_poles.toString();
      tecMotorPoles.selection = TextSelection.fromPosition(TextPosition(offset: tecMotorPoles.text.length));
      tecGearRatio.text = doublePrecision(widget.escMotorConfiguration.si_gear_ratio, 3).toString();
      tecGearRatio.selection = TextSelection.fromPosition(TextPosition(offset: tecGearRatio.text.length));

      // Populate text editing controllers
      tecCurrentMax.text = doublePrecision(widget.escMotorConfiguration.l_current_max, 1).toString();
      tecCurrentMin.text = doublePrecision(widget.escMotorConfiguration.l_current_min, 1).toString();
      tecInCurrentMax.text = doublePrecision(widget.escMotorConfiguration.l_in_current_max, 1).toString();
      tecInCurrentMin.text = doublePrecision(widget.escMotorConfiguration.l_in_current_min, 1).toString();
      tecABSCurrentMax.text = doublePrecision(widget.escMotorConfiguration.l_abs_current_max, 1).toString();
      tecMaxERPM.text = widget.escMotorConfiguration.l_max_erpm.toInt().toString();
      tecMinERPM.text = widget.escMotorConfiguration.l_min_erpm.toInt().toString();
      tecMinVIN.text = doublePrecision(widget.escMotorConfiguration.l_min_vin, 1).toString();
      tecMaxVIN.text = doublePrecision(widget.escMotorConfiguration.l_max_vin, 1).toString();
      tecBatteryCutStart.text = doublePrecision(widget.escMotorConfiguration.l_battery_cut_start, 1).toString();
      tecBatteryCutEnd.text = doublePrecision(widget.escMotorConfiguration.l_battery_cut_end, 1).toString();
      tecTempFETStart.text = doublePrecision(widget.escMotorConfiguration.l_temp_fet_start, 1).toString();
      tecTempFETEnd.text = doublePrecision(widget.escMotorConfiguration.l_temp_fet_end, 1).toString();
      tecTempMotorStart.text = doublePrecision(widget.escMotorConfiguration.l_temp_motor_start, 1).toString();
      tecTempMotorEnd.text = doublePrecision(widget.escMotorConfiguration.l_temp_motor_end, 1).toString();
      tecWattMin.text = doublePrecision(widget.escMotorConfiguration.l_watt_min, 1).toString();
      tecWattMax.text = doublePrecision(widget.escMotorConfiguration.l_watt_max, 1).toString();
      tecCurrentMinScale.text = doublePrecision(widget.escMotorConfiguration.l_current_min_scale, 2).toString();
      tecCurrentMaxScale.text = doublePrecision(widget.escMotorConfiguration.l_current_max_scale, 2).toString();
      tecDutyStart.text = doublePrecision(widget.escMotorConfiguration.l_duty_start, 2).toString();

      // Set cursor position to end of text editing controllers
      tecCurrentMax.selection = TextSelection.fromPosition(TextPosition(offset: tecCurrentMax.text.length));
      tecCurrentMin.selection = TextSelection.fromPosition(TextPosition(offset: tecCurrentMin.text.length));
      tecInCurrentMax.selection = TextSelection.fromPosition(TextPosition(offset: tecInCurrentMax.text.length));
      tecInCurrentMin.selection = TextSelection.fromPosition(TextPosition(offset: tecInCurrentMin.text.length));
      tecABSCurrentMax.selection = TextSelection.fromPosition(TextPosition(offset: tecABSCurrentMax.text.length));
      tecMaxERPM.selection = TextSelection.fromPosition(TextPosition(offset: tecMaxERPM.text.length));
      tecMinERPM.selection = TextSelection.fromPosition(TextPosition(offset: tecMinERPM.text.length));
      tecMinVIN.selection = TextSelection.fromPosition(TextPosition(offset: tecMinVIN.text.length));
      tecMaxVIN.selection = TextSelection.fromPosition(TextPosition(offset: tecMaxVIN.text.length));
      tecBatteryCutStart.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCutStart.text.length));
      tecBatteryCutEnd.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCutEnd.text.length));
      tecTempFETStart.selection = TextSelection.fromPosition(TextPosition(offset: tecTempFETStart.text.length));
      tecTempFETEnd.selection = TextSelection.fromPosition(TextPosition(offset: tecTempFETEnd.text.length));
      tecTempMotorStart.selection = TextSelection.fromPosition(TextPosition(offset: tecTempMotorStart.text.length));
      tecTempMotorEnd.selection = TextSelection.fromPosition(TextPosition(offset: tecTempMotorEnd.text.length));
      tecWattMin.selection = TextSelection.fromPosition(TextPosition(offset: tecWattMin.text.length));
      tecWattMax.selection = TextSelection.fromPosition(TextPosition(offset: tecWattMax.text.length));
      tecCurrentMinScale.selection = TextSelection.fromPosition(TextPosition(offset: tecCurrentMinScale.text.length));
      tecCurrentMaxScale.selection = TextSelection.fromPosition(TextPosition(offset: tecCurrentMaxScale.text.length));
      tecDutyStart.selection = TextSelection.fromPosition(TextPosition(offset: tecDutyStart.text.length));

      // Build ESC Configurator
      return Container(
          child: Stack(children: <Widget>[
            Center(
              child: GestureDetector(
                onTap: () {
                  // Hide the keyboard
                  FocusScope.of(context).requestFocus(new FocusNode());
                },
                child: Column(
                  children: [
                    Column(
                      children: [
                        SizedBox(height: 5,),

                        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                          Icon(
                            Icons.settings_applications,
                            size: 80.0,
                            color: Colors.blue,
                          ),
                          Text("Motor\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                        ],),

                        SizedBox(height:10),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(10),
                        children: <Widget>[


                          Center(child: Column( children: <Widget>[
                            Text("Discovered Devices"),
                            SizedBox(
                              height: 50,
                              child: GridView.builder(
                                primary: false,
                                itemCount: widget.discoveredCANDevices.length + 1, //NOTE: +1 to add the Direct ESC
                                gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2, crossAxisSpacing: 1, mainAxisSpacing: 1),
                                itemBuilder: (BuildContext context, int index) {
                                  if (index == 0) {
                                    return new Card(
                                      shadowColor: Colors.transparent,
                                      child: new GridTile(
                                        // GestureDetector to switch the currently selected CAN Forward ID
                                          child: new GestureDetector(
                                            onTap: (){
                                              setState(() {
                                                // Clear CAN Forward
                                                _selectedCANFwdID = null;
                                                // Request primary ESC settings
                                                widget.onAutoloadESCSettings(true);
                                                ScaffoldMessenger
                                                    .of(context)
                                                    .showSnackBar(SnackBar(content: Text("Requesting ESC configuration from primary ESC")));
                                              });
                                            },
                                            child: Stack(
                                              children: <Widget>[



                                                new Center(child: Text(_selectedCANFwdID == null ? "Direct (Active)" :"Direct", style: TextStyle(fontSize: 12))),
                                                new ClipRRect(
                                                    borderRadius: new BorderRadius.circular(10),
                                                    child: new Container(
                                                      decoration: new BoxDecoration(
                                                        color: _selectedCANFwdID == null ? Theme.of(context).focusColor : Colors.transparent,
                                                      ),
                                                    )
                                                )


                                              ],
                                            ),
                                          )
                                      ),
                                    );
                                  }
                                  bool isCANIDSelected = false;
                                  if (_selectedCANFwdID == widget.discoveredCANDevices[index-1]) {
                                    isCANIDSelected = true;
                                  }
                                  String invalidDevice = "";
                                  if (_invalidCANID == widget.discoveredCANDevices[index-1]) {
                                    invalidDevice = " (Invalid)";
                                  }
                                  return new Card(
                                    shadowColor: Colors.transparent,
                                    child: new GridTile(
                                      // GestureDetector to switch the currently selected CAN Forward ID
                                        child: new GestureDetector(
                                          onTap: (){
                                            if (isCANIDSelected) {
                                              setState(() {
                                                // Clear CAN Forward
                                                _selectedCANFwdID = null;
                                                // Request primary ESC settings
                                                widget.onAutoloadESCSettings(true);
                                                ScaffoldMessenger
                                                    .of(context)
                                                    .showSnackBar(SnackBar(content: Text("Requesting ESC configuration from primary ESC")));
                                              });
                                            } else {
                                              if (_invalidCANID != widget.discoveredCANDevices[index-1]) {
                                                //TODO: i don't know if we want to set state here or in the condition above either. needs testing
                                                setState(() {
                                                  _selectedCANFwdID = widget.discoveredCANDevices[index-1];
                                                  // Request MCCONF from CAN device
                                                  requestMCCONFCAN(_selectedCANFwdID);
                                                  ScaffoldMessenger
                                                      .of(context)
                                                      .showSnackBar(SnackBar(content: Text("Requesting ESC configuration from CAN ID $_selectedCANFwdID")));
                                                });
                                              }

                                            }
                                          },
                                          child: Stack(
                                            children: <Widget>[



                                              new Center(child: Text("${widget.discoveredCANDevices[index-1]}${isCANIDSelected?" (Active)":""}$invalidDevice", style: TextStyle(fontSize: 12)),),
                                              new ClipRRect(
                                                  borderRadius: new BorderRadius.circular(10),
                                                  child: new Container(
                                                    decoration: new BoxDecoration(
                                                      color: isCANIDSelected ? Theme.of(context).focusColor : Colors.transparent,
                                                    ),
                                                  )
                                              )


                                            ],
                                          ),
                                        )
                                    ),
                                  );
                                },
                              ),
                            )
                          ],)
                          ),

                          Center(child:
                          Column(children: <Widget>[
                            Text("ESC Information"),
                            ElevatedButton(
                                child: Text("Request from ESC${_selectedCANFwdID != null ? "/CAN $_selectedCANFwdID" : ""}"),
                                onPressed: () {
                                  if (widget.currentDevice != null) {
                                    setState(() {
                                      if ( _selectedCANFwdID != null ) {
                                        requestMCCONFCAN(_selectedCANFwdID);
                                        ScaffoldMessenger
                                            .of(context)
                                            .showSnackBar(SnackBar(content: Text("Requesting ESC configuration from CAN ID $_selectedCANFwdID")));
                                      } else {
                                        widget.onAutoloadESCSettings(true);
                                        ScaffoldMessenger
                                            .of(context)
                                            .showSnackBar(SnackBar(content: Text("Requesting ESC configuration")));
                                      }
                                    });
                                  }
                                })
                          ],)
                          ),

                          //TODO: consider all unused struct members again
                          //Text("${widget.escMotorConfiguration.motor_type}"),
                          //Text("${widget.escMotorConfiguration.sensor_mode}"),

                          SwitchListTile(
                            title: Text("Reverse Motor (${widget.escMotorConfiguration.m_invert_direction})"),
                            value: widget.escMotorConfiguration.m_invert_direction,
                            onChanged: (bool newValue) { setState((){widget.escMotorConfiguration.m_invert_direction = newValue;}); },
                            secondary: const Icon(Icons.sync),
                          ),

                          DropdownButton(
                              value: widget.escMotorConfiguration.si_battery_type.index,
                              items: [
                                DropdownMenuItem(
                                  child: Text("Battery Type: Li-ion 3.0/4.2V"),
                                  value: 0,
                                ),
                                DropdownMenuItem(
                                  child: Text("Battery Type: LiFePO₄ 2.6/3.6V"),
                                  value: 1,
                                ),
                                DropdownMenuItem(
                                    child: Text("Battery Type: Lead Acid"),
                                    value: 2
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  widget.escMotorConfiguration.si_battery_type = BATTERY_TYPE.values[value];
                                });
                              }),

                          DropdownButton(
                              value: widget.escMotorConfiguration.foc_sensor_mode.index,
                              items: [
                                DropdownMenuItem(
                                  child: Text("FOC_SENSOR_MODE_SENSORLESS"),
                                  value: 0,
                                ),
                                DropdownMenuItem(
                                  child: Text("FOC_SENSOR_MODE_ENCODER"),
                                  value: 1,
                                ),
                                DropdownMenuItem(
                                    child: Text("FOC_SENSOR_MODE_HALL"),
                                    value: 2
                                ),
                                DropdownMenuItem(
                                    child: Text("FOC_SENSOR_MODE_HFI"),
                                    value: 3
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  widget.escMotorConfiguration.foc_sensor_mode = mc_foc_sensor_mode.values[value];
                                });
                              }),



                          TextField(
                              controller: tecBatterySeriesCount,
                              decoration: new InputDecoration(labelText: "Battery Series Count"),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly
                              ]
                          ),
                          TextField(
                              controller: tecBatteryCapacityAh,
                              decoration: new InputDecoration(labelText: "Battery Capacity (Ah)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                            controller: tecWheelDiameterMillimeters,
                            decoration: new InputDecoration(labelText: "Wheel Diameter in Millimeters"),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                          TextField(
                              controller: tecMotorPoles,
                              decoration: new InputDecoration(labelText: "Motor Poles"),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly
                              ]
                          ),
                          TextField(
                              controller: tecGearRatio,
                              decoration: new InputDecoration(labelText: "Gear Ratio"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),






                          TextField(
                              controller: tecCurrentMax,
                              decoration: new InputDecoration(labelText: "Motor Current Max (Amps)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecCurrentMin,
                              decoration: new InputDecoration(labelText: "Motor Current Max Brake (Amps)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                NumberTextInputFormatter() //This allows for negative doubles
                              ]
                          ),
                          TextField(
                              controller: tecInCurrentMax,
                              decoration: new InputDecoration(labelText: "Battery Current Max (Amps)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecInCurrentMin,
                              decoration: new InputDecoration(labelText: "Battery Current Max Regen (Amps)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                NumberTextInputFormatter() //This allows for negative doubles
                              ]
                          ),
                          TextField(
                              controller: tecABSCurrentMax,
                              decoration: new InputDecoration(labelText: "Absolute Maximum Current (Amps)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),

                          TextField(
                              controller: tecMaxERPM,
                              decoration: new InputDecoration(labelText: "Max ERPM"),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly
                              ]
                          ),
                          TextField(
                              controller: tecMinERPM,
                              decoration: new InputDecoration(labelText: "Min ERPM"),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),

                          TextField(
                              controller: tecMinVIN,
                              decoration: new InputDecoration(labelText: "Minimum Voltage Input"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecMaxVIN,
                              decoration: new InputDecoration(labelText: "Maximum Voltage Input"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),

                          TextField(
                              controller: tecBatteryCutStart,
                              decoration: new InputDecoration(labelText: "Battery Cutoff Start (Volts)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecBatteryCutEnd,
                              decoration: new InputDecoration(labelText: "Battery Cutoff End (Volts)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecTempFETStart,
                              decoration: new InputDecoration(labelText: "ESC Temperature Cutoff Start (Celsius)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecTempFETEnd,
                              decoration: new InputDecoration(labelText: "ESC Temperature Cutoff End (Celsius)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecTempMotorStart,
                              decoration: new InputDecoration(labelText: "Motor Temperature Cutoff Start (Celsius)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecTempMotorEnd,
                              decoration: new InputDecoration(labelText: "Motor Temperature Cutoff End (Celsius)"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),

                          TextField(
                              controller: tecWattMin,
                              decoration: new InputDecoration(labelText: "Maximum Braking Wattage"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                NumberTextInputFormatter() //This allows for negative doubles
                              ]
                          ),
                          TextField(
                              controller: tecWattMax,
                              decoration: new InputDecoration(labelText: "Maximum Wattage"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecCurrentMinScale,
                              decoration: new InputDecoration(labelText: "Min Current Scale"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecCurrentMaxScale,
                              decoration: new InputDecoration(labelText: "Max Current Scale"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),
                          TextField(
                              controller: tecDutyStart,
                              decoration: new InputDecoration(labelText: "Duty Cycle Current Limit Start"),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(formatPositiveDouble)
                              ]
                          ),

                          //Text(" ${widget.escMotorConfiguration.}"),

                          ElevatedButton(
                              child: Text("Save to ESC${_selectedCANFwdID != null ? "/CAN $_selectedCANFwdID" : ""}"),
                              onPressed: () {
                                if (widget.currentDevice != null) {
                                  //setState(() {
                                  // Save motor configuration; CAN FWD ID can be null
                                  saveMCCONF(_selectedCANFwdID);
                                  //TODO: Not going to notify the user because sometimes saveMCCONF fails and they have to try again
                                  /*
                            // Notify user
                            if ( _selectedCANFwdID != null ) {
                              Scaffold
                                  .of(context)
                                  .showSnackBar(SnackBar(content: Text("Saving ESC configuration to CAN ID $_selectedCANFwdID")));
                            } else {
                              Scaffold
                                  .of(context)
                                  .showSnackBar(SnackBar(content: Text("Saving ESC configuration")));
                            }
                             */
                                  //});
                                }
                              }),

                          Divider(height: 10,),
                          Center(child: Text("Additional Tools"),),
                          Row( mainAxisAlignment: MainAxisAlignment.spaceBetween ,
                            children: <Widget>[
                              ElevatedButton(
                                //TODO: quick pair for CAN FWD device?
                                  child: Row(children: <Widget>[
                                    Icon(Icons.settings_remote),
                                    Text("nRF Quick Pair")
                                  ],),
                                  onPressed: () {
                                    // Don't write if not connected
                                    if (widget.theTXCharacteristic != null) {
                                      var byteData = new ByteData(10); //<start><payloadLen><packetID><int32_milliseconds><crc1><crc2><end>
                                      byteData.setUint8(0, 0x02);
                                      byteData.setUint8(1, 0x05);
                                      byteData.setUint8(2, COMM_PACKET_ID.COMM_NRF_START_PAIRING.index);
                                      byteData.setUint32(3, 10000); //milliseconds
                                      int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, 5);
                                      byteData.setUint16(7, checksum);
                                      byteData.setUint8(9, 0x03); //End of packet

                                      //<start><payloadLen><packetID><int32_milliseconds><crc1><crc2><end>
                                      widget.theTXCharacteristic.write(byteData.buffer.asUint8List()).then((value){
                                        globalLogger.d('You have 10 seconds to power on your remote!');
                                      }).catchError((e){
                                        globalLogger.e("nRF Quick Pair: Exception: $e");
                                      });
                                    } else {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text("nRF Quick Pair"),
                                            content: Text("Oops. Try connecting to your board first."),
                                          );
                                        },
                                      );
                                    }
                                  }),

                              ElevatedButton(
                                  child: Row(children: <Widget>[
                                    Icon(Icons.donut_large),
                                    Text("FOC Wizard")
                                  ],),
                                  onPressed: () {
                                    if(widget.theTXCharacteristic == null) {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text("Connection Required =("),
                                            content: Text("This feature requires an active connection."),
                                          );
                                        },
                                      );
                                      return;
                                    }
                                    setState(() {
                                      // navigate to the route
                                      Navigator.of(context).pushNamed(ConfigureESC.routeName, arguments: FOCWizardArguments(widget.theTXCharacteristic, null));
                                    });
                                  })

                            ],)


                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: (){
                      globalLogger.d("User Close Motor Configuration");
                      genericConfirmationDialog(
                          context,
                          TextButton(
                            child: Text("Not yet"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: Text("Yes"),
                            onPressed: () async {
                              Navigator.of(context).pop();
                              widget.closeESCConfigurator(true);
                            },
                          ),
                          "Close Motor Configuration?",
                          Text("Unsaved changes will be lost.")
                      );
                    }
                )
            ),
          ],)
      );
    }

    tecBoardAlias.text = widget.myUserSettings.settings.boardAlias;
    tecBoardAlias.selection = TextSelection.fromPosition(TextPosition(offset: tecBoardAlias.text.length));


    return Container(
      //padding: EdgeInsets.all(5),
        child: Center(
          child: GestureDetector(
            onTap: () {
              // Hide the keyboard
              FocusScope.of(context).requestFocus(new FocusNode());
            },
            child: ListView(
              padding: EdgeInsets.all(10),
              children: <Widget>[

                SizedBox(height: 5,),





                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Icon(
                    Icons.settings,
                    size: 80.0,
                    color: Colors.blue,
                  ),
                  Text("FreeSK8\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                ],),


                SwitchListTile(
                  title: Text("Display imperial distances"),
                  value: widget.myUserSettings.settings.useImperial,
                  onChanged: (bool newValue) { setState((){widget.myUserSettings.settings.useImperial = newValue;}); },
                  secondary: const Icon(Icons.power_input),
                ),
                SwitchListTile(
                  title: Text("Display fahrenheit temperatures"),
                  value: widget.myUserSettings.settings.useFahrenheit,
                  onChanged: (bool newValue) { setState((){widget.myUserSettings.settings.useFahrenheit = newValue;}); },
                  secondary: const Icon(Icons.wb_sunny),
                ),
                SwitchListTile(
                  title: Text("Override speed/distance with GPS metrics"),
                  subtitle: Text("For use with eFoil, eBike"),
                  value: widget.myUserSettings.settings.useGPSData,
                  onChanged: (bool newValue) async {
                    bool valueToSet = newValue;

                    // Confirm with user if we are enabling this option
                    if (valueToSet == true) {
                      // Confirm setting with user
                      valueToSet = await genericConfirmationDialog(
                          context,
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("No Thank You"),
                          ),
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Yes Please")
                          ),
                          "Quick check!",
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Oh, hey.. Usually ESC data is preferred for speed and distance. Are you sure you want to see GPS metrics?"),
                              Icon(Icons.gps_fixed),
                              SizedBox(height: 15),

                            ],
                          )
                      );
                    }

                    setState((){
                      widget.myUserSettings.settings.useGPSData = valueToSet != null ? valueToSet : false;
                    });
                  },
                  secondary: Icon(widget.myUserSettings.settings.useGPSData ? Icons.gps_fixed : Icons.gps_not_fixed),
                ),

                TextField(
                  controller: tecBoardAlias,
                  decoration: new InputDecoration(labelText: "Board Name / Alias"),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: 15),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Column(children: <Widget>[
                    Text("Board Avatar"),
                    SizedBox(
                      width: 125,
                      child:  ElevatedButton(
                          child:
                          Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Take "),Icon(Icons.camera_alt),],),

                          onPressed: () {
                            getImage(false);
                          }),
                    ),
                    SizedBox(
                      width: 125,
                      child:  ElevatedButton(
                          child:
                          Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Select "),Icon(Icons.filter),],),

                          onPressed: () {
                            getImage(true);
                          }),
                    )
                  ],),

                  SizedBox(width: 15),
                  CircleAvatar(
                      backgroundImage: _boardAvatar != null ? _boardAvatar : AssetImage('assets/FreeSK8_Mobile.png'),
                      radius: 100,
                      backgroundColor: Colors.white)

                ]),

                SizedBox(height:10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  ElevatedButton(
                      child: Text("Revert Settings"),
                      onPressed: () {
                        setState(() {
                          widget.myUserSettings.reloadSettings();
                          ScaffoldMessenger
                              .of(context)
                              .showSnackBar(SnackBar(content: Text('Application settings loaded from last state')));
                        });
                      }),

                  SizedBox(width:15),

                  ElevatedButton(
                      child: Text("Save Settings"),
                      onPressed: () async {
                        FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                        try {
                          if (tecBoardAlias.text.length < 1) tecBoardAlias.text = "Unnamed";
                          widget.myUserSettings.settings.boardAlias = tecBoardAlias.text;
                          // NOTE: Board avatar is updated with the image picker
                          await widget.myUserSettings.saveSettings();

                          // Update cached avatar
                          widget.updateCachedAvatar(true);

                          // Recompute statistics in case we change measurement units
                          widget.updateComputedVehicleStatistics(false);

                        } catch (e) {
                          globalLogger.e("Save Settings Exception $e");
                          ScaffoldMessenger
                              .of(context)
                              .showSnackBar(SnackBar(content: Text('Sorry friend. Save settings failed =(')));
                        }
                        ScaffoldMessenger
                            .of(context)
                            .showSnackBar(SnackBar(content: Text('Application settings saved')));
                      }),


                ],),


                Divider(thickness: 2,),

                ExpansionPanelList(
                    elevation: 0,
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      print(_showAdvanced);
                      _showAdvanced = !_showAdvanced;
                    });
                  },
                  children: [
                    ExpansionPanel(
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        headerBuilder: (context, isOpen) {
                          return Row(children: [
                            SizedBox(width: 10),
                            Icon(Icons.science_outlined),
                            Text("Advanced")
                          ],);
                        },
                        body: Column(children: [
                          ElevatedButton(
                              child: Text("Export Data Backup"),
                              onPressed: () async {
                                FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                                // Show dialog to prevent user input
                                await Dialogs.showPleaseWaitDialog(context, _keyLoader).timeout(Duration(milliseconds: 500)).catchError((error){});

                                try {
                                  final documentsDirectory = await getApplicationDocumentsDirectory();
                                  final supportDirectory = await getApplicationSupportDirectory();

                                  // Zip a directory to out.zip using the zipDirectory convenience method
                                  var encoder = ZipFileEncoder();

                                  // Manually create a zip of individual files
                                  encoder.create("${supportDirectory.path}/freesk8_beta_backup.zip");

                                  // Add log files
                                  encoder.addDirectory(Directory("${documentsDirectory.path}/logs"));

                                  //rideLogsFromDatabase.forEach((element)  {
                                  //TODO: no safety checking here. Opening file must be on device
                                  //  encoder.addFile(File("${documentsDirectory.path}${element.logFilePath}"));
                                  //});

                                  // Add the database
                                  String path = await getDatabasesPath();
                                  encoder.addFile(File("$path/logDatabase.db"));

                                  // Add the avatars
                                  encoder.addDirectory(Directory("${documentsDirectory.path}/avatars"));

                                  // Add the userSettings export
                                  encoder.addFile(await exportSettings('${supportDirectory.path}/freesk8_beta_userSettings.json'));

                                  // Finish out zip file
                                  encoder.close();

                                  Navigator.of(context).pop(); // Remove PleaseWait dialog
                                  await Share.file("FreeSK8 Beta Log Archive", "freesk8_beta_backup.zip", await File("${supportDirectory.path}/freesk8_beta_backup.zip").readAsBytes(), 'application/zip', text: "FreeSK8 Beta Logs");

                                } catch (e, stacktrace) {
                                  Navigator.of(context).pop(); // Remove PleaseWait dialog
                                  globalLogger.e("Export Data Exception $e");
                                  globalLogger.e(stacktrace.toString());
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(SnackBar(content: Text("Export Exception. Please send debug log")));
                                }
                              }),

                          ElevatedButton(
                              child: Text("Import Data Backup (Caution!)"),
                              onPressed: () async {
                                FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                                // Show dialog to prevent user input
                                await Dialogs.showPleaseWaitDialog(context, _keyLoader).timeout(Duration(milliseconds: 500)).catchError((error){});

                                try {
                                  final documentsDirectory = await getApplicationDocumentsDirectory();

                                  FlutterDocumentPickerParams params = FlutterDocumentPickerParams(
                                    allowedFileExtensions: ["zip"],
                                    allowedMimeTypes: ["application/zip"],
                                  );

                                  String result = await FlutterDocumentPicker.openDocument(params: params);
                                  globalLogger.d("Import Data: User imported file: $result");

                                  if (result == null) {
                                    Navigator.of(context).pop(); // Remove PleaseWait dialog
                                    return ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(SnackBar(content: Text("Import Aborted: No File Specified")));
                                  }

                                  // Read the Zip file from disk.
                                  final bytes = File(result).readAsBytesSync();

                                  // Decode the Zip file
                                  final archive = ZipDecoder().decodeBytes(bytes);

                                  // Extract the contents of the Zip archive to disk.
                                  for (final file in archive) {
                                    final filename = file.name;
                                    if (file.isFile) {
                                      final data = file.content as List<int>;
                                      File('${documentsDirectory.path}/' + filename)
                                        ..createSync(recursive: true)
                                        ..writeAsBytesSync(data);
                                      print(filename);
                                    } else {
                                      Directory('${documentsDirectory.path}/' + filename)
                                        ..create(recursive: true);
                                    }
                                  }

                                  // Make sure we've extracted the a userSettings file for importing
                                  final String importSettingsFilePath = "${documentsDirectory.path}/freesk8_beta_userSettings.json";
                                  if (!File(importSettingsFilePath).existsSync()) {
                                    Navigator.of(context).pop(); // Remove PleaseWait dialog
                                    return ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(SnackBar(content: Text("Invalid Import File Selected")));
                                  }

                                  // Import UserSettings
                                  if (await importSettings(importSettingsFilePath)) {
                                    // Import Ride Log Database
                                    String dbPath = await getDatabasesPath();
                                    File("${documentsDirectory.path}/logDatabase.db").copy("$dbPath/logDatabase.db");

                                    Navigator.of(context).pop(); // Remove PleaseWait dialog
                                    globalLogger.d("Import Data Completed Successfully");
                                    ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(SnackBar(content: Text("Import Data Completed Successfully")));

                                    // Removing import files to free space and clear import state
                                    File(importSettingsFilePath).deleteSync();
                                    File(result).deleteSync();
                                  } else {
                                    globalLogger.d("Import did not finish successfully");
                                    ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(SnackBar(content: Text("Import Aborted")));
                                  }



                                } catch (e, stacktrace) {
                                  Navigator.of(context).pop(); // Remove PleaseWait dialog
                                  globalLogger.e("Import Data Exception $e");
                                  globalLogger.e(stacktrace.toString());
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(SnackBar(content: Text("Import Exception. Please send debug log")));

                                }
                              }),

                          ElevatedButton(
                              child: Text("Open Vehicle Manager"),
                              onPressed: () async {
                                FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                                // Wait for the navigation to return
                                final result = await Navigator.of(context).pushNamed(VehicleManager.routeName, arguments: VehicleManagerArguments(widget.currentDevice == null ? null : widget.currentDevice?.id.toString()));
                                // If changes were made the result of the Navigation will be true and we'll want to reload the user settings
                                if (result == true) {
                                  // Request the user settings to be reloaded
                                  widget.reloadUserSettings(result);
                                }
                              }),
                        ],),
                      isExpanded: _showAdvanced
                    ),
                  ],
                ),


              ],
            ),
          ),
        )
    );
  }
}
