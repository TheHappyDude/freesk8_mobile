import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freesk8_mobile/escHelper/appConf.dart';

// VESC based ESC defines
// From datatypes.h
enum BATTERY_TYPE {
  BATTERY_TYPE_LIION_3_0__4_2,
  BATTERY_TYPE_LIIRON_2_6__3_6,
  BATTERY_TYPE_LEAD_ACID
}

enum temp_sensor_type {
  TEMP_SENSOR_NTC_10K_25C,
  TEMP_SENSOR_PTC_1K_100C,
  TEMP_SENSOR_KTY83_122
}

enum out_aux_mode {
  OUT_AUX_MODE_OFF,
  OUT_AUX_MODE_ON_AFTER_2S,
  OUT_AUX_MODE_ON_AFTER_5S,
  OUT_AUX_MODE_ON_AFTER_10S,
  OUT_AUX_MODE_UNUSED
}

enum drv8301_oc_mode{
  DRV8301_OC_LIMIT,
  DRV8301_OC_LATCH_SHUTDOWN,
  DRV8301_OC_REPORT_ONLY,
  DRV8301_OC_DISABLED
}

enum sensor_port_mode {
  SENSOR_PORT_MODE_HALL,
  SENSOR_PORT_MODE_ABI,
  SENSOR_PORT_MODE_AS5047_SPI,
  SENSOR_PORT_MODE_AD2S1205,
  SENSOR_PORT_MODE_SINCOS,
  SENSOR_PORT_MODE_TS5700N8501,
  SENSOR_PORT_MODE_TS5700N8501_MULTITURN
}

enum mc_foc_hfi_samples {
  HFI_SAMPLES_8,
  HFI_SAMPLES_16,
  HFI_SAMPLES_32
}

enum mc_foc_observer_type{
  FOC_OBSERVER_ORTEGA_ORIGINAL,
  FOC_OBSERVER_ORTEGA_ITERATIVE
}

enum mc_foc_cc_decoupling_mode {
  FOC_CC_DECOUPLING_DISABLED,
  FOC_CC_DECOUPLING_CROSS,
  FOC_CC_DECOUPLING_BEMF,
  FOC_CC_DECOUPLING_CROSS_BEMF
}

enum mc_foc_sensor_mode {
  FOC_SENSOR_MODE_SENSORLESS,
  FOC_SENSOR_MODE_ENCODER,
  FOC_SENSOR_MODE_HALL,
  FOC_SENSOR_MODE_HFI
}

enum mc_sensor_mode {
  SENSOR_MODE_SENSORLESS,
  SENSOR_MODE_SENSORED,
  SENSOR_MODE_HYBRID
}

enum mc_motor_type {
  MOTOR_TYPE_BLDC,
  MOTOR_TYPE_DC,
  MOTOR_TYPE_FOC,
  MOTOR_TYPE_GPD
}

enum mc_comm_mode {
  COMM_MODE_INTEGRATE,
  COMM_MODE_DELAY
}

enum mc_pwm_mode {
  PWM_MODE_NONSYNCHRONOUS_HISW, // This mode is not recommended
  PWM_MODE_SYNCHRONOUS, // The recommended and most tested mode
  PWM_MODE_BIPOLAR // Some glitches occasionally, can kill MOSFETs
}

enum COMM_PACKET_ID {
  COMM_FW_VERSION,
  COMM_JUMP_TO_BOOTLOADER,
  COMM_ERASE_NEW_APP,
  COMM_WRITE_NEW_APP_DATA,
  COMM_GET_VALUES,
  COMM_SET_DUTY,
  COMM_SET_CURRENT,
  COMM_SET_CURRENT_BRAKE,
  COMM_SET_RPM,
  COMM_SET_POS,
  COMM_SET_HANDBRAKE,
  COMM_SET_DETECT,
  COMM_SET_SERVO_POS,
  COMM_SET_MCCONF,
  COMM_GET_MCCONF,
  COMM_GET_MCCONF_DEFAULT,
  COMM_SET_APPCONF,
  COMM_GET_APPCONF,
  COMM_GET_APPCONF_DEFAULT,
  COMM_SAMPLE_PRINT,
  COMM_TERMINAL_CMD,
  COMM_PRINT,
  COMM_ROTOR_POSITION,
  COMM_EXPERIMENT_SAMPLE,
  COMM_DETECT_MOTOR_PARAM,
  COMM_DETECT_MOTOR_R_L,
  COMM_DETECT_MOTOR_FLUX_LINKAGE,
  COMM_DETECT_ENCODER,
  COMM_DETECT_HALL_FOC,
  COMM_REBOOT,
  COMM_ALIVE,
  COMM_GET_DECODED_PPM,
  COMM_GET_DECODED_ADC,
  COMM_GET_DECODED_CHUK,
  COMM_FORWARD_CAN,
  COMM_SET_CHUCK_DATA,
  COMM_CUSTOM_APP_DATA,
  COMM_NRF_START_PAIRING,
  COMM_GPD_SET_FSW,
  COMM_GPD_BUFFER_NOTIFY,
  COMM_GPD_BUFFER_SIZE_LEFT,
  COMM_GPD_FILL_BUFFER,
  COMM_GPD_OUTPUT_SAMPLE,
  COMM_GPD_SET_MODE,
  COMM_GPD_FILL_BUFFER_INT8,
  COMM_GPD_FILL_BUFFER_INT16,
  COMM_GPD_SET_BUFFER_INT_SCALE,
  COMM_GET_VALUES_SETUP,
  COMM_SET_MCCONF_TEMP,
  COMM_SET_MCCONF_TEMP_SETUP,
  COMM_GET_VALUES_SELECTIVE,
  COMM_GET_VALUES_SETUP_SELECTIVE,
  COMM_EXT_NRF_PRESENT,
  COMM_EXT_NRF_ESB_SET_CH_ADDR,
  COMM_EXT_NRF_ESB_SEND_DATA,
  COMM_EXT_NRF_ESB_RX_DATA,
  COMM_EXT_NRF_SET_ENABLED,
  COMM_DETECT_MOTOR_FLUX_LINKAGE_OPENLOOP,
  COMM_DETECT_APPLY_ALL_FOC,
  COMM_JUMP_TO_BOOTLOADER_ALL_CAN,
  COMM_ERASE_NEW_APP_ALL_CAN,
  COMM_WRITE_NEW_APP_DATA_ALL_CAN,
  COMM_PING_CAN,
  COMM_APP_DISABLE_OUTPUT,
  COMM_TERMINAL_CMD_SYNC,
  COMM_GET_IMU_DATA,
  COMM_BM_CONNECT,
  COMM_BM_ERASE_FLASH_ALL,
  COMM_BM_WRITE_FLASH,
  COMM_BM_REBOOT,
  COMM_BM_DISCONNECT,
  COMM_BM_MAP_PINS_DEFAULT,
  COMM_BM_MAP_PINS_NRF5X,
  COMM_ERASE_BOOTLOADER,
  COMM_ERASE_BOOTLOADER_ALL_CAN,
  COMM_PLOT_INIT,
  COMM_PLOT_DATA,
  COMM_PLOT_ADD_GRAPH,
  COMM_PLOT_SET_GRAPH,
  COMM_GET_DECODED_BALANCE,
  COMM_BM_MEM_READ,
  COMM_WRITE_NEW_APP_DATA_LZO,
  COMM_WRITE_NEW_APP_DATA_ALL_CAN_LZO,
  COMM_BM_WRITE_FLASH_LZO,
  COMM_SET_CURRENT_REL,
  COMM_CAN_FWD_FRAME,
  COMM_SET_BATTERY_CUT
}

// CAN commands
// From datatypes.h
enum CAN_PACKET_ID {
  CAN_PACKET_SET_DUTY,
  CAN_PACKET_SET_CURRENT,
  CAN_PACKET_SET_CURRENT_BRAKE,
  CAN_PACKET_SET_RPM,
  CAN_PACKET_SET_POS,
  CAN_PACKET_FILL_RX_BUFFER,
  CAN_PACKET_FILL_RX_BUFFER_LONG,
  CAN_PACKET_PROCESS_RX_BUFFER,
  CAN_PACKET_PROCESS_SHORT_BUFFER,
  CAN_PACKET_STATUS,
  CAN_PACKET_SET_CURRENT_REL,
  CAN_PACKET_SET_CURRENT_BRAKE_REL,
  CAN_PACKET_SET_CURRENT_HANDBRAKE,
  CAN_PACKET_SET_CURRENT_HANDBRAKE_REL,
  CAN_PACKET_STATUS_2,
  CAN_PACKET_STATUS_3,
  CAN_PACKET_STATUS_4,
  CAN_PACKET_PING,
  CAN_PACKET_PONG,
  CAN_PACKET_DETECT_APPLY_ALL_FOC,
  CAN_PACKET_DETECT_APPLY_ALL_FOC_RES,
  CAN_PACKET_CONF_CURRENT_LIMITS,
  CAN_PACKET_CONF_STORE_CURRENT_LIMITS,
  CAN_PACKET_CONF_CURRENT_LIMITS_IN,
  CAN_PACKET_CONF_STORE_CURRENT_LIMITS_IN,
  CAN_PACKET_CONF_FOC_ERPMS,
  CAN_PACKET_CONF_STORE_FOC_ERPMS,
  CAN_PACKET_STATUS_5,
  CAN_PACKET_POLL_TS5700N8501_STATUS,
  CAN_PACKET_CONF_BATTERY_CUT,
  CAN_PACKET_CONF_STORE_BATTERY_CUT,
  CAN_PACKET_SHUTDOWN
}

// VESC based ESC faults
// From datatypes.h
enum mc_fault_code {
  FAULT_CODE_NONE,
  FAULT_CODE_OVER_VOLTAGE,
  FAULT_CODE_UNDER_VOLTAGE,
  FAULT_CODE_DRV,
  FAULT_CODE_ABS_OVER_CURRENT,
  FAULT_CODE_OVER_TEMP_FET,
  FAULT_CODE_OVER_TEMP_MOTOR,
  FAULT_CODE_GATE_DRIVER_OVER_VOLTAGE,
  FAULT_CODE_GATE_DRIVER_UNDER_VOLTAGE,
  FAULT_CODE_MCU_UNDER_VOLTAGE,
  FAULT_CODE_BOOTING_FROM_WATCHDOG_RESET,
  FAULT_CODE_ENCODER_SPI,
  FAULT_CODE_ENCODER_SINCOS_BELOW_MIN_AMPLITUDE,
  FAULT_CODE_ENCODER_SINCOS_ABOVE_MAX_AMPLITUDE,
  FAULT_CODE_FLASH_CORRUPTION,
  FAULT_CODE_HIGH_OFFSET_CURRENT_SENSOR_1,
  FAULT_CODE_HIGH_OFFSET_CURRENT_SENSOR_2,
  FAULT_CODE_HIGH_OFFSET_CURRENT_SENSOR_3,
  FAULT_CODE_UNBALANCED_CURRENTS,
  FAULT_CODE_BRK,
  FAULT_CODE_RESOLVER_LOT,
  FAULT_CODE_RESOLVER_DOS,
  FAULT_CODE_RESOLVER_LOS
}

class ESCTelemetry {
  ESCTelemetry() {
    v_in = 0;
    temp_mos = 0;
    temp_mos_1 = 0;
    temp_mos_2 = 0;
    temp_mos_3 = 0;
    temp_motor = 0;
    current_motor = 0;
    current_in = 0;
    foc_id = 0;
    foc_iq = 0;
    rpm = 0;
    duty_now = 0;
    amp_hours = 0;
    amp_hours_charged = 0;
    watt_hours = 0;
    watt_hours_charged = 0;
    tachometer = 0;
    tachometer_abs = 0;
    position = 0;
    vesc_id = 0;
    vd = 0;
    vq = 0;
    fault_code = mc_fault_code.FAULT_CODE_NONE;
  }
  //FW 5
  double v_in;
  double temp_mos;
  double temp_mos_1;
  double temp_mos_2;
  double temp_mos_3;
  double temp_motor;
  double current_motor;
  double current_in;
  double foc_id;
  double foc_iq;
  double rpm;
  double duty_now;
  double amp_hours;
  double amp_hours_charged;
  double watt_hours;
  double watt_hours_charged;
  int tachometer;
  int tachometer_abs;
  double position;
  mc_fault_code fault_code;
  int vesc_id;
  double vd;
  double vq;
}

class ESCProfile {
  ESCProfile({this.profileName});
  // For user interaction
  String profileName;
  double speedKmh;
  double speedKmhRev;
  // VESC based ESC variables :smirk:
  double l_current_min_scale;
  double l_current_max_scale;
  double l_watt_min;
  double l_watt_max;
}

class MCCONF {
  MCCONF() {
    hall_table = new List(8);
    foc_hall_table = new List(8);
  }
  // Switching and drive
  mc_pwm_mode pwm_mode;
  mc_comm_mode comm_mode;
  mc_motor_type motor_type;
  mc_sensor_mode sensor_mode;
  // Limits
  double l_current_max;
  double l_current_min;
  double l_in_current_max;
  double l_in_current_min;
  double l_abs_current_max;
  double l_min_erpm;
  double l_max_erpm;
  double l_erpm_start;
  double l_max_erpm_fbrake;
  double l_max_erpm_fbrake_cc;
  double l_min_vin;
  double l_max_vin;
  double l_battery_cut_start;
  double l_battery_cut_end;
  bool l_slow_abs_current;
  double l_temp_fet_start;
  double l_temp_fet_end;
  double l_temp_motor_start;
  double l_temp_motor_end;
  double l_temp_accel_dec;
  double l_min_duty;
  double l_max_duty;
  double l_watt_max;
  double l_watt_min;
  double l_current_max_scale;
  double l_current_min_scale;
  double l_duty_start;
  // Overridden limits (Computed during runtime)
  double lo_current_max;
  double lo_current_min;
  double lo_in_current_max;
  double lo_in_current_min;
  double lo_current_motor_max_now;
  double lo_current_motor_min_now;
  // Sensorless (bldc)
  double sl_min_erpm;
  double sl_min_erpm_cycle_int_limit;
  double sl_max_fullbreak_current_dir_change;
  double sl_cycle_int_limit;
  double sl_phase_advance_at_br;
  double sl_cycle_int_rpm_br;
  double sl_bemf_coupling_k;
  // Hall sensor
  List<int> hall_table;
  double hall_sl_erpm;
  // FOC
  double foc_current_kp;
  double foc_current_ki;
  double foc_f_sw;
  double foc_dt_us;
  double foc_encoder_offset;
  bool foc_encoder_inverted;
  double foc_encoder_ratio;
  double foc_encoder_sin_offset;
  double foc_encoder_sin_gain;
  double foc_encoder_cos_offset;
  double foc_encoder_cos_gain;
  double foc_encoder_sincos_filter_constant;
  double foc_motor_l;
  double foc_motor_r;
  double foc_motor_flux_linkage;
  double foc_observer_gain;
  double foc_observer_gain_slow;
  double foc_pll_kp;
  double foc_pll_ki;
  double foc_duty_dowmramp_kp;
  double foc_duty_dowmramp_ki;
  double foc_openloop_rpm;
  double foc_sl_openloop_hyst;
  double foc_sl_openloop_time;
  double foc_sl_d_current_duty;
  double foc_sl_d_current_factor;
  mc_foc_sensor_mode foc_sensor_mode;
  List<int> foc_hall_table;
  double foc_sl_erpm;
  bool foc_sample_v0_v7;
  bool foc_sample_high_current;
  double foc_sat_comp;
  bool foc_temp_comp;
  double foc_temp_comp_base_temp;
  double foc_current_filter_const;
  mc_foc_cc_decoupling_mode foc_cc_decoupling;
  mc_foc_observer_type foc_observer_type;
  double foc_hfi_voltage_start;
  double foc_hfi_voltage_run;
  double foc_hfi_voltage_max;
  double foc_sl_erpm_hfi;
  int foc_hfi_start_samples;
  double foc_hfi_obs_ovr_sec;
  mc_foc_hfi_samples foc_hfi_samples;
  // GPDrive
  int gpd_buffer_notify_left;
  int gpd_buffer_interpol;
  double gpd_current_filter_const;
  double gpd_current_kp;
  double gpd_current_ki;
  // Speed PID
  double s_pid_kp;
  double s_pid_ki;
  double s_pid_kd;
  double s_pid_kd_filter;
  double s_pid_min_erpm;
  bool s_pid_allow_braking;
  // Pos PID
  double p_pid_kp;
  double p_pid_ki;
  double p_pid_kd;
  double p_pid_kd_filter;
  double p_pid_ang_div;
  // Current controller
  double cc_startup_boost_duty;
  double cc_min_current;
  double cc_gain;
  double cc_ramp_step_max;
  // Misc
  int m_fault_stop_time_ms;
  double m_duty_ramp_step;
  double m_current_backoff_gain;
  int m_encoder_counts;
  sensor_port_mode m_sensor_port_mode;
  bool m_invert_direction;
  drv8301_oc_mode m_drv8301_oc_mode;
  int m_drv8301_oc_adj;
  double m_bldc_f_sw_min;
  double m_bldc_f_sw_max;
  double m_dc_f_sw;
  double m_ntc_motor_beta;
  out_aux_mode m_out_aux_mode;
  temp_sensor_type m_motor_temp_sens_type;
  double m_ptc_motor_coeff;
  // Setup info
  int si_motor_poles;
  double si_gear_ratio;
  double si_wheel_diameter;
  BATTERY_TYPE si_battery_type;
  int si_battery_cells;
  double si_battery_ah;
}

class ESCFirmware {
  ESCFirmware() {
    fw_version_major = 0;
    fw_version_minor = 0;
    hardware_name = "loading...";
  }
  int fw_version_major;
  int fw_version_minor;
  String hardware_name;
}

class ESCFault {
  int faultCode;
  int faultCount;
  int escID;
  DateTime firstSeen;
  DateTime lastSeen;

  ESCFault({this.faultCode, this.faultCount, this.escID, this.firstSeen, this.lastSeen});

  String toString() {
    return "${mc_fault_code.values[this.faultCode].toString().substring(14)} was seen ${this.faultCount} time${this.faultCount!=1?"s":""} on ESC ${this.escID} at ${this.firstSeen.toString().substring(0,19)}${this.faultCount > 1 ? " until ${this.lastSeen.toString().substring(11,19)}" : ""}";
  }

  TableRow toTableRow() {
    return TableRow(children: [
      Text(mc_fault_code.values[this.faultCode].toString().substring(14)),
      Text(this.faultCount.toString()),
      Text(this.escID.toString()),
      Text(this.firstSeen.toString()),
      Text(this.lastSeen.toString())
    ]);
  }
}

class ESCHelper {
  static const int MCCONF_SIGNATURE = 3698540221;
  static const int APPCONF_SIGNATURE = 2460147246;

  List<ESCFault> processFaults(int faultCount, Uint8List payload) {
    print(payload);
    List<ESCFault> response = new List();
    int index = 0;
    for (int i=0; i<faultCount; ++i) {
      ESCFault fault = new ESCFault();
      fault.faultCode = payload[index++];
      fault.faultCount = buffer_get_uint16(payload, index); index += 2;
      fault.escID = buffer_get_uint16(payload, index); index += 2;
      index += 3; //NOTE: Alignment
      fault.firstSeen = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(payload, index, Endian.little) * 1000, isUtc: true); index += 8;
      fault.lastSeen = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(payload, index, Endian.little) * 1000, isUtc: true); index += 8;
      print(fault.toString());
      response.add(fault);
    }
    return response;
  }

  ESCFirmware processFirmware(Uint8List payload) {
    int index = 1;
    ESCFirmware firmwarePacket = new ESCFirmware();
    firmwarePacket.fw_version_major = payload[index++];
    firmwarePacket.fw_version_minor = payload[index++];

    Uint8List hardwareBytes = new Uint8List(30);
    int i = 0;
    while (payload[index] != 0) {
      hardwareBytes[i++] = payload[index++];
    }
    firmwarePacket.hardware_name = new String.fromCharCodes(hardwareBytes);

    return firmwarePacket;
  }

  ESCTelemetry processTelemetry(Uint8List payload) {
    int index = 1;
    ESCTelemetry telemetryPacket = new ESCTelemetry();

    telemetryPacket.temp_mos = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_motor = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.current_motor = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.current_in = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.foc_id = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.foc_iq = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.duty_now = buffer_get_float16(payload, index, 1000.0); index += 2;
    telemetryPacket.rpm = buffer_get_float32(payload, index, 1.0); index += 4;
    telemetryPacket.v_in = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.amp_hours = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.amp_hours_charged = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.watt_hours = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.watt_hours_charged = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.tachometer = buffer_get_int32(payload, index); index += 4;
    telemetryPacket.tachometer_abs = buffer_get_int32(payload, index); index += 4;
    telemetryPacket.fault_code = mc_fault_code.values[payload[index++]];
    telemetryPacket.position = buffer_get_float32(payload, index, 10.0); index += 4;
    telemetryPacket.vesc_id = payload[index++];
    telemetryPacket.temp_mos_1 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_mos_2 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_mos_3 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.vd = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.vq = buffer_get_float32(payload, index, 100.0);

    return telemetryPacket;
  }

  APPCONF processAPPCONF(Uint8List buffer) {
    int index = 1;
    APPCONF appconfData = new APPCONF();
    int signature = buffer_get_uint32(buffer, index); index += 4;
    if (signature != APPCONF_SIGNATURE) {
      print("Invalid APPCONF signature; received $signature expecting $APPCONF_SIGNATURE");
      return appconfData;
    }
    print("VALID APPCONF SIGNATURE winky face emoji, winky face emoji, winky face emoji");

    appconfData.controller_id = buffer[index++];
    appconfData.timeout_msec = buffer_get_uint32(buffer, index); index += 4;
    appconfData.timeout_brake_current = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.send_can_status = CAN_STATUS_MODE.values[buffer[index++]];
    appconfData.send_can_status_rate_hz = buffer_get_uint16(buffer, index); index += 2;
    appconfData.can_baud_rate = CAN_BAUD.values[buffer[index++]];
    appconfData.pairing_done = buffer[index++] > 0 ? true : false;
    appconfData.permanent_uart_enabled = buffer[index++] > 0 ? true : false;
    appconfData.shutdown_mode = SHUTDOWN_MODE.values[buffer[index++]];
    appconfData.can_mode = CAN_MODE.values[buffer[index++]];
    appconfData.uavcan_esc_index = buffer[index++];
    appconfData.app_to_use = app_use.values[buffer[index++]];
    appconfData.app_ppm_conf.ctrl_type = ppm_control_type.values[buffer[index++]];
    appconfData.app_ppm_conf.pid_max_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.hyst = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.pulse_start = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.pulse_end = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.pulse_center = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.median_filter = buffer[index++] > 0 ? true : false;
    appconfData.app_ppm_conf.safe_start = buffer[index++] > 0 ? true : false;
    appconfData.app_ppm_conf.throttle_exp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.throttle_exp_brake = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.throttle_exp_mode = thr_exp_mode.values[buffer[index++]];
    appconfData.app_ppm_conf.ramp_time_pos = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.ramp_time_neg = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.multi_esc = buffer[index++] > 0 ? true : false;
    appconfData.app_ppm_conf.tc = buffer[index++] > 0 ? true : false;
    appconfData.app_ppm_conf.tc_max_diff = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.max_erpm_for_dir = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.smart_rev_max_duty = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.smart_rev_ramp_time = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.ctrl_type = adc_control_type.values[buffer[index++]];
    appconfData.app_adc_conf.hyst = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.voltage_start = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.voltage_end = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.voltage_center = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.voltage2_start = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.voltage2_end = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.use_filter = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.safe_start = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.cc_button_inverted = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.rev_button_inverted = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.voltage_inverted = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.voltage2_inverted = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.throttle_exp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.throttle_exp_brake = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.throttle_exp_mode = thr_exp_mode.values[buffer[index++]];
    appconfData.app_adc_conf.ramp_time_pos = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.ramp_time_neg = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.multi_esc = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.tc = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.tc_max_diff = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.update_rate_hz = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_uart_baudrate = buffer_get_uint32(buffer, index); index += 4;
    appconfData.app_chuk_conf.ctrl_type = chuk_control_type.values[buffer[index++]];
    appconfData.app_chuk_conf.hyst = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.ramp_time_pos = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.ramp_time_neg = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.stick_erpm_per_s_in_cc = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.throttle_exp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.throttle_exp_brake = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.throttle_exp_mode = thr_exp_mode.values[buffer[index++]];
    appconfData.app_chuk_conf.multi_esc = buffer[index++] > 0 ? true : false;
    appconfData.app_chuk_conf.tc = buffer[index++] > 0 ? true : false;
    appconfData.app_chuk_conf.tc_max_diff = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.use_smart_rev = buffer[index++] > 0 ? true : false;
    appconfData.app_chuk_conf.smart_rev_max_duty = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.smart_rev_ramp_time = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_nrf_conf.speed = NRF_SPEED.values[buffer[index++]];
    appconfData.app_nrf_conf.power = NRF_POWER.values[buffer[index++]];
    appconfData.app_nrf_conf.crc_type = NRF_CRC .values[buffer[index++]];
    appconfData.app_nrf_conf.retry_delay = NRF_RETR_DELAY.values[buffer[index++]];
    appconfData.app_nrf_conf.retries = buffer[index++];
    appconfData.app_nrf_conf.channel = buffer[index++];
    appconfData.app_nrf_conf.address[0] = buffer[index++];
    appconfData.app_nrf_conf.address[1] = buffer[index++];
    appconfData.app_nrf_conf.address[2] = buffer[index++];
    appconfData.app_nrf_conf.send_crc_ack = buffer[index++] > 0 ? true : false;
    appconfData.app_balance_conf.kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.ki = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.kd = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.hertz = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.pitch_fault = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.roll_fault = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.adc1 = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.adc2 = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.overspeed_duty = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_duty = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_angle = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_speed = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_high_voltage = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_low_voltage = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.startup_pitch_tolerance = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.startup_roll_tolerance = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.startup_speed = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.deadzone = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.current_boost = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.multi_esc = buffer[index++] > 0 ? true : false;
    appconfData.app_balance_conf.yaw_kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.yaw_ki = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.yaw_kd = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.roll_steer_kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.brake_current = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.overspeed_delay = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.fault_delay = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.tiltback_constant = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.roll_steer_erpm_kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.yaw_current_clamp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.adc_half_fault_erpm = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.setpoint_pitch_filter = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.setpoint_target_filter = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.setpoint_clamp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.type = IMU_TYPE.values[buffer[index++]];
    appconfData.imu_conf.mode = AHRS_MODE.values[buffer[index++]];
    appconfData.imu_conf.sample_rate_hz = buffer_get_uint16(buffer, index); index += 2;
    appconfData.imu_conf.accel_confidence_decay = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.mahony_kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.mahony_ki = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.madgwick_beta = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.rot_roll = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.rot_pitch = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.rot_yaw = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.accel_offsets[0] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.accel_offsets[1] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.accel_offsets[2] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offsets[0] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offsets[1] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offsets[2] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offset_comp_fact[0] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offset_comp_fact[1] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offset_comp_fact[2] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offset_comp_clamp = buffer_get_float32_auto(buffer, index); index += 4;

    print("escHelper::processAPPCONF: final index = $index");
    return appconfData;
  }

  ByteData serializeAPPCONF(APPCONF conf) {
    int index = 0;
    ByteData response = new ByteData(390); //TODO: ByteData is not dynamic, setting exact size
    response.setUint32(index, APPCONF_SIGNATURE); index += 4;

    response.setUint8(index++, conf.controller_id);
    response.setUint32(index, conf.timeout_msec); index += 4;
    response.setFloat32(index, conf.timeout_brake_current); index += 4;
    response.setUint8(index++, conf.send_can_status.index);
    response.setUint16(index, conf.send_can_status_rate_hz); index += 2;
    response.setUint8(index++, conf.can_baud_rate.index);
    response.setUint8(index++, conf.pairing_done ? 1 : 0);
    response.setUint8(index++, conf.permanent_uart_enabled ? 1 : 0);
    response.setUint8(index++, conf.shutdown_mode.index);
    response.setUint8(index++, conf.can_mode.index);
    response.setUint8(index++, conf.uavcan_esc_index);
    response.setUint8(index++, conf.app_to_use.index);
    response.setUint8(index++, conf.app_ppm_conf.ctrl_type.index);
    response.setFloat32(index, conf.app_ppm_conf.pid_max_erpm); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.hyst); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.pulse_start); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.pulse_end); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.pulse_center); index += 4;
    response.setUint8(index++, conf.app_ppm_conf.median_filter ? 1 : 0);
    response.setUint8(index++, conf.app_ppm_conf.safe_start ? 1 : 0);
    response.setFloat32(index, conf.app_ppm_conf.throttle_exp); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.throttle_exp_brake); index += 4;
    response.setUint8(index++, conf.app_ppm_conf.throttle_exp_mode.index);
    response.setFloat32(index, conf.app_ppm_conf.ramp_time_pos); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.ramp_time_neg); index += 4;
    response.setUint8(index++, conf.app_ppm_conf.multi_esc ? 1 : 0);
    response.setUint8(index++, conf.app_ppm_conf.tc ? 1 : 0);
    response.setFloat32(index, conf.app_ppm_conf.tc_max_diff); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.max_erpm_for_dir); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.smart_rev_max_duty); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.smart_rev_ramp_time); index += 4;
    response.setUint8(index++, conf.app_adc_conf.ctrl_type.index);
    response.setFloat32(index, conf.app_adc_conf.hyst); index += 4;
    response.setFloat32(index, conf.app_adc_conf.voltage_start); index += 4;
    response.setFloat32(index, conf.app_adc_conf.voltage_end); index += 4;
    response.setFloat32(index, conf.app_adc_conf.voltage_center); index += 4;
    response.setFloat32(index, conf.app_adc_conf.voltage2_start); index += 4;
    response.setFloat32(index, conf.app_adc_conf.voltage2_end); index += 4;
    response.setUint8(index++, conf.app_adc_conf.use_filter ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.safe_start ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.cc_button_inverted ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.rev_button_inverted ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.voltage_inverted ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.voltage2_inverted ? 1 : 0);
    response.setFloat32(index, conf.app_adc_conf.throttle_exp); index += 4;
    response.setFloat32(index, conf.app_adc_conf.throttle_exp_brake); index += 4;
    response.setUint8(index++, conf.app_adc_conf.throttle_exp_mode.index);
    response.setFloat32(index, conf.app_adc_conf.ramp_time_pos); index += 4;
    response.setFloat32(index, conf.app_adc_conf.ramp_time_neg); index += 4;
    response.setUint8(index++, conf.app_adc_conf.multi_esc ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.tc ? 1 : 0);
    response.setFloat32(index, conf.app_adc_conf.tc_max_diff); index += 4;
    response.setUint16(index, conf.app_adc_conf.update_rate_hz); index += 2;
    response.setUint32(index, conf.app_uart_baudrate); index += 4;
    response.setUint8(index++, conf.app_chuk_conf.ctrl_type.index);
    response.setFloat32(index, conf.app_chuk_conf.hyst); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.ramp_time_pos); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.ramp_time_neg); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.stick_erpm_per_s_in_cc); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.throttle_exp); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.throttle_exp_brake); index += 4;
    response.setUint8(index++, conf.app_chuk_conf.throttle_exp_mode.index);
    response.setUint8(index++, conf.app_chuk_conf.multi_esc ? 1 : 0);
    response.setUint8(index++, conf.app_chuk_conf.tc ? 1 : 0);
    response.setFloat32(index, conf.app_chuk_conf.tc_max_diff); index += 4;
    response.setUint8(index++, conf.app_chuk_conf.use_smart_rev ? 1 : 0);
    response.setFloat32(index, conf.app_chuk_conf.smart_rev_max_duty); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.smart_rev_ramp_time); index += 4;
    response.setUint8(index++, conf.app_nrf_conf.speed.index);
    response.setUint8(index++, conf.app_nrf_conf.power.index);
    response.setUint8(index++, conf.app_nrf_conf.crc_type.index);
    response.setUint8(index++, conf.app_nrf_conf.retry_delay.index);
    response.setUint8(index++, conf.app_nrf_conf.retries);
    response.setUint8(index++, conf.app_nrf_conf.channel);
    response.setUint8(index++, conf.app_nrf_conf.address[0]);
    response.setUint8(index++, conf.app_nrf_conf.address[1]);
    response.setUint8(index++, conf.app_nrf_conf.address[2]);
    response.setUint8(index++, conf.app_nrf_conf.send_crc_ack ? 1 : 0);
    response.setFloat32(index, conf.app_balance_conf.kp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.ki); index += 4;
    response.setFloat32(index, conf.app_balance_conf.kd); index += 4;
    response.setUint16(index, conf.app_balance_conf.hertz); index += 2;
    response.setFloat32(index, conf.app_balance_conf.pitch_fault); index += 4;
    response.setFloat32(index, conf.app_balance_conf.roll_fault); index += 4;
    response.setFloat32(index, conf.app_balance_conf.adc1); index += 4;
    response.setFloat32(index, conf.app_balance_conf.adc2); index += 4;
    response.setFloat32(index, conf.app_balance_conf.overspeed_duty); index += 4;
    response.setFloat32(index, conf.app_balance_conf.tiltback_duty); index += 4;
    response.setFloat32(index, conf.app_balance_conf.tiltback_angle); index += 4;
    response.setFloat32(index, conf.app_balance_conf.tiltback_speed); index += 4;
    response.setFloat32(index, conf.app_balance_conf.tiltback_high_voltage); index += 4;
    response.setFloat32(index, conf.app_balance_conf.tiltback_low_voltage); index += 4;
    response.setFloat32(index, conf.app_balance_conf.startup_pitch_tolerance); index += 4;
    response.setFloat32(index, conf.app_balance_conf.startup_roll_tolerance); index += 4;
    response.setFloat32(index, conf.app_balance_conf.startup_speed); index += 4;
    response.setFloat32(index, conf.app_balance_conf.deadzone); index += 4;
    response.setFloat32(index, conf.app_balance_conf.current_boost); index += 4;
    response.setUint8(index++, conf.app_balance_conf.multi_esc ? 1 : 0);
    response.setFloat32(index, conf.app_balance_conf.yaw_kp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.yaw_ki); index += 4;
    response.setFloat32(index, conf.app_balance_conf.yaw_kd); index += 4;
    response.setFloat32(index, conf.app_balance_conf.roll_steer_kp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.brake_current); index += 4;
    response.setUint16(index, conf.app_balance_conf.overspeed_delay); index += 2;
    response.setUint16(index, conf.app_balance_conf.fault_delay); index += 2;
    response.setFloat32(index, conf.app_balance_conf.tiltback_constant); index += 4;
    response.setFloat32(index, conf.app_balance_conf.roll_steer_erpm_kp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.yaw_current_clamp); index += 4;
    response.setUint16(index, conf.app_balance_conf.adc_half_fault_erpm); index += 2;
    response.setFloat32(index, conf.app_balance_conf.setpoint_pitch_filter); index += 4;
    response.setFloat32(index, conf.app_balance_conf.setpoint_target_filter); index += 4;
    response.setFloat32(index, conf.app_balance_conf.setpoint_clamp); index += 4;
    response.setUint8(index++, conf.imu_conf.type.index);
    response.setUint8(index++, conf.imu_conf.mode.index);
    response.setUint16(index, conf.imu_conf.sample_rate_hz); index += 2;
    response.setFloat32(index, conf.imu_conf.accel_confidence_decay); index += 4;
    response.setFloat32(index, conf.imu_conf.mahony_kp); index += 4;
    response.setFloat32(index, conf.imu_conf.mahony_ki); index += 4;
    response.setFloat32(index, conf.imu_conf.madgwick_beta); index += 4;
    response.setFloat32(index, conf.imu_conf.rot_roll); index += 4;
    response.setFloat32(index, conf.imu_conf.rot_pitch); index += 4;
    response.setFloat32(index, conf.imu_conf.rot_yaw); index += 4;
    response.setFloat32(index, conf.imu_conf.accel_offsets[0]); index += 4;
    response.setFloat32(index, conf.imu_conf.accel_offsets[1]); index += 4;
    response.setFloat32(index, conf.imu_conf.accel_offsets[2]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offsets[0]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offsets[1]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offsets[2]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offset_comp_fact[0]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offset_comp_fact[1]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offset_comp_fact[2]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offset_comp_clamp); index += 4;

    return response;
  }

  MCCONF processMCCONF(Uint8List buffer) {
    int index = 1;
    MCCONF mcconfData = new MCCONF();
    int signature  = buffer_get_uint32(buffer, index); index += 4;
    if (signature != MCCONF_SIGNATURE) {
      print("Invalid MCCONF Signature. Received $signature but expected $MCCONF_SIGNATURE");
      //Return empty mcconf
      return mcconfData;
    }

    mcconfData.pwm_mode = mc_pwm_mode.values[buffer[index++]];
    mcconfData.comm_mode = mc_comm_mode.values[buffer[index++]];
    mcconfData.motor_type = mc_motor_type.values[buffer[index++]];
    mcconfData.sensor_mode = mc_sensor_mode.values[buffer[index++]];
    mcconfData.l_current_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_current_min = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_in_current_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_in_current_min = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_abs_current_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_min_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_max_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_erpm_start = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_max_erpm_fbrake = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_max_erpm_fbrake_cc = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_min_vin = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_max_vin = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_battery_cut_start = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_battery_cut_end = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_slow_abs_current = buffer[index++] > 0 ? true : false;
    mcconfData.l_temp_fet_start = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_temp_fet_end = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_temp_motor_start = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_temp_motor_end = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_temp_accel_dec = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_min_duty = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_max_duty = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_watt_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_watt_min = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_current_max_scale = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_current_min_scale = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_duty_start = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_min_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_min_erpm_cycle_int_limit = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_max_fullbreak_current_dir_change = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_cycle_int_limit = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_phase_advance_at_br = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_cycle_int_rpm_br = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_bemf_coupling_k = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.hall_table[0] = buffer[index++];
    mcconfData.hall_table[1] = buffer[index++];
    mcconfData.hall_table[2] = buffer[index++];
    mcconfData.hall_table[3] = buffer[index++];
    mcconfData.hall_table[4] = buffer[index++];
    mcconfData.hall_table[5] = buffer[index++];
    mcconfData.hall_table[6] = buffer[index++];
    mcconfData.hall_table[7] = buffer[index++];
    mcconfData.hall_sl_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_current_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_current_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_f_sw = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_dt_us = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_inverted = buffer[index++] > 0 ? true : false;
    mcconfData.foc_encoder_offset = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_ratio = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_sin_gain = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_cos_gain = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_sin_offset = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_cos_offset = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_sincos_filter_constant = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sensor_mode = mc_foc_sensor_mode.values[buffer[index++]];
    mcconfData.foc_pll_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_pll_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_motor_l = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_motor_r = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_motor_flux_linkage = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_observer_gain = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_observer_gain_slow = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_duty_dowmramp_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_duty_dowmramp_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_openloop_rpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sl_openloop_hyst = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sl_openloop_time = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sl_d_current_duty = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sl_d_current_factor = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_hall_table[0] = buffer[index++];
    mcconfData.foc_hall_table[1] = buffer[index++];
    mcconfData.foc_hall_table[2] = buffer[index++];
    mcconfData.foc_hall_table[3] = buffer[index++];
    mcconfData.foc_hall_table[4] = buffer[index++];
    mcconfData.foc_hall_table[5] = buffer[index++];
    mcconfData.foc_hall_table[6] = buffer[index++];
    mcconfData.foc_hall_table[7] = buffer[index++];
    mcconfData.foc_sl_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sample_v0_v7 = buffer[index++] > 0 ? true: false;
    mcconfData.foc_sample_high_current = buffer[index++] > 0 ? true : false;
    mcconfData.foc_sat_comp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_temp_comp = buffer[index++] > 0 ? true : false;
    mcconfData.foc_temp_comp_base_temp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_current_filter_const = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_cc_decoupling = mc_foc_cc_decoupling_mode.values[buffer[index++]];
    mcconfData.foc_observer_type = mc_foc_observer_type.values[buffer[index++]];
    mcconfData.foc_hfi_voltage_start = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_hfi_voltage_run = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_hfi_voltage_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sl_erpm_hfi = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_hfi_start_samples = buffer_get_uint16(buffer, index); index += 2;
    mcconfData.foc_hfi_obs_ovr_sec = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_hfi_samples = mc_foc_hfi_samples.values[buffer[index++]];
    mcconfData.gpd_buffer_notify_left = buffer_get_int16(buffer, index); index += 2;
    mcconfData.gpd_buffer_interpol = buffer_get_int16(buffer, index); index += 2;
    mcconfData.gpd_current_filter_const = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.gpd_current_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.gpd_current_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_kd = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_kd_filter = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_min_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_allow_braking = buffer[index++] > 0 ? true: false;
    mcconfData.p_pid_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_kd = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_kd_filter = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_ang_div = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.cc_startup_boost_duty = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.cc_min_current = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.cc_gain = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.cc_ramp_step_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_fault_stop_time_ms = buffer_get_int32(buffer, index); index += 4;
    mcconfData.m_duty_ramp_step = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_current_backoff_gain = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_encoder_counts = buffer_get_uint32(buffer, index); index += 4;
    mcconfData.m_sensor_port_mode = sensor_port_mode.values[buffer[index++]];
    mcconfData.m_invert_direction = buffer[index++] > 0 ? true: false;
    mcconfData.m_drv8301_oc_mode = drv8301_oc_mode.values[buffer[index++]];
    mcconfData.m_drv8301_oc_adj = buffer[index++];
    mcconfData.m_bldc_f_sw_min = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_bldc_f_sw_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_dc_f_sw = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_ntc_motor_beta = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_out_aux_mode = out_aux_mode.values[buffer[index++]];
    mcconfData.m_motor_temp_sens_type = temp_sensor_type.values[buffer[index++]];
    mcconfData.m_ptc_motor_coeff = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.si_motor_poles = buffer[index++];
    mcconfData.si_gear_ratio = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.si_wheel_diameter = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.si_battery_type = BATTERY_TYPE.values[buffer[index++]];
    mcconfData.si_battery_cells = buffer[index++];
    mcconfData.si_battery_ah = buffer_get_float32_auto(buffer, index); index += 4;

    return mcconfData;
  }
/* mSerializeOrder	<139 items>	QStringList
		[0]	"pwm_mode"	QString
		[1]	"comm_mode"	QString
		[2]	"motor_type"	QString
		[3]	"sensor_mode"	QString
		[4]	"l_current_max"	QString
		[5]	"l_current_min"	QString
		[6]	"l_in_current_max"	QString
		[7]	"l_in_current_min"	QString
		[8]	"l_abs_current_max"	QString
		[9]	"l_min_erpm"	QString
		[10]	"l_max_erpm"	QString
		[11]	"l_erpm_start"	QString
		[12]	"l_max_erpm_fbrake"	QString
		[13]	"l_max_erpm_fbrake_cc"	QString
		[14]	"l_min_vin"	QString
		[15]	"l_max_vin"	QString
		[16]	"l_battery_cut_start"	QString
		[17]	"l_battery_cut_end"	QString
		[18]	"l_slow_abs_current"	QString
		[19]	"l_temp_fet_start"	QString
		[20]	"l_temp_fet_end"	QString
		[21]	"l_temp_motor_start"	QString
		[22]	"l_temp_motor_end"	QString
		[23]	"l_temp_accel_dec"	QString
		[24]	"l_min_duty"	QString
		[25]	"l_max_duty"	QString
		[26]	"l_watt_max"	QString
		[27]	"l_watt_min"	QString
		[28]	"l_current_max_scale"	QString
		[29]	"l_current_min_scale"	QString
		[30]	"l_duty_start"	QString
		[31]	"sl_min_erpm"	QString
		[32]	"sl_min_erpm_cycle_int_limit"	QString
		[33]	"sl_max_fullbreak_current_dir_change"	QString
		[34]	"sl_cycle_int_limit"	QString
		[35]	"sl_phase_advance_at_br"	QString
		[36]	"sl_cycle_int_rpm_br"	QString
		[37]	"sl_bemf_coupling_k"	QString
		[38]	"hall_table__0"	QString
		[39]	"hall_table__1"	QString
		[40]	"hall_table__2"	QString
		[41]	"hall_table__3"	QString
		[42]	"hall_table__4"	QString
		[43]	"hall_table__5"	QString
		[44]	"hall_table__6"	QString
		[45]	"hall_table__7"	QString
		[46]	"hall_sl_erpm"	QString
		[47]	"foc_current_kp"	QString
		[48]	"foc_current_ki"	QString
		[49]	"foc_f_sw"	QString
		[50]	"foc_dt_us"	QString
		[51]	"foc_encoder_inverted"	QString
		[52]	"foc_encoder_offset"	QString
		[53]	"foc_encoder_ratio"	QString
		[54]	"foc_encoder_sin_gain"	QString
		[55]	"foc_encoder_cos_gain"	QString
		[56]	"foc_encoder_sin_offset"	QString
		[57]	"foc_encoder_cos_offset"	QString
		[58]	"foc_encoder_sincos_filter_constant"	QString
		[59]	"foc_sensor_mode"	QString
		[60]	"foc_pll_kp"	QString
		[61]	"foc_pll_ki"	QString
		[62]	"foc_motor_l"	QString
		[63]	"foc_motor_r"	QString
		[64]	"foc_motor_flux_linkage"	QString
		[65]	"foc_observer_gain"	QString
		[66]	"foc_observer_gain_slow"	QString
		[67]	"foc_duty_dowmramp_kp"	QString
		[68]	"foc_duty_dowmramp_ki"	QString
		[69]	"foc_openloop_rpm"	QString
		[70]	"foc_sl_openloop_hyst"	QString
		[71]	"foc_sl_openloop_time"	QString
		[72]	"foc_sl_d_current_duty"	QString
		[73]	"foc_sl_d_current_factor"	QString
		[74]	"foc_hall_table__0"	QString
		[75]	"foc_hall_table__1"	QString
		[76]	"foc_hall_table__2"	QString
		[77]	"foc_hall_table__3"	QString
		[78]	"foc_hall_table__4"	QString
		[79]	"foc_hall_table__5"	QString
		[80]	"foc_hall_table__6"	QString
		[81]	"foc_hall_table__7"	QString
		[82]	"foc_sl_erpm"	QString
		[83]	"foc_sample_v0_v7"	QString
		[84]	"foc_sample_high_current"	QString
		[85]	"foc_sat_comp"	QString
		[86]	"foc_temp_comp"	QString
		[87]	"foc_temp_comp_base_temp"	QString
		[88]	"foc_current_filter_const"	QString
		[89]	"foc_cc_decoupling"	QString
		[90]	"foc_observer_type"	QString
		[91]	"foc_hfi_voltage_start"	QString
		[92]	"foc_hfi_voltage_run"	QString
		[93]	"foc_hfi_voltage_max"	QString
		[94]	"foc_sl_erpm_hfi"	QString
		[95]	"foc_hfi_start_samples"	QString
		[96]	"foc_hfi_obs_ovr_sec"	QString
		[97]	"foc_hfi_samples"	QString
		[98]	"gpd_buffer_notify_left"	QString
		[99]	"gpd_buffer_interpol"	QString
		[100]	"gpd_current_filter_const"	QString
		[101]	"gpd_current_kp"	QString
		[102]	"gpd_current_ki"	QString
		[103]	"s_pid_kp"	QString
		[104]	"s_pid_ki"	QString
		[105]	"s_pid_kd"	QString
		[106]	"s_pid_kd_filter"	QString
		[107]	"s_pid_min_erpm"	QString
		[108]	"s_pid_allow_braking"	QString
		[109]	"p_pid_kp"	QString
		[110]	"p_pid_ki"	QString
		[111]	"p_pid_kd"	QString
		[112]	"p_pid_kd_filter"	QString
		[113]	"p_pid_ang_div"	QString
		[114]	"cc_startup_boost_duty"	QString
		[115]	"cc_min_current"	QString
		[116]	"cc_gain"	QString
		[117]	"cc_ramp_step_max"	QString
		[118]	"m_fault_stop_time_ms"	QString
		[119]	"m_duty_ramp_step"	QString
		[120]	"m_current_backoff_gain"	QString
		[121]	"m_encoder_counts"	QString
		[122]	"m_sensor_port_mode"	QString
		[123]	"m_invert_direction"	QString
		[124]	"m_drv8301_oc_mode"	QString
		[125]	"m_drv8301_oc_adj"	QString
		[126]	"m_bldc_f_sw_min"	QString
		[127]	"m_bldc_f_sw_max"	QString
		[128]	"m_dc_f_sw"	QString
		[129]	"m_ntc_motor_beta"	QString
		[130]	"m_out_aux_mode"	QString
		[131]	"m_motor_temp_sens_type"	QString
		[132]	"m_ptc_motor_coeff"	QString
		[133]	"si_motor_poles"	QString
		[134]	"si_gear_ratio"	QString
		[135]	"si_wheel_diameter"	QString
		[136]	"si_battery_type"	QString
		[137]	"si_battery_cells"	QString
		[138]	"si_battery_ah"	QString
 */
  ByteData serializeMCCONF(MCCONF conf) {
    int index = 0;
    ByteData response = new ByteData(437); //TODO: ByteData is not dynamic, setting exact size
    response.setUint32(index, MCCONF_SIGNATURE); index += 4;

    response.setUint8(index++, conf.pwm_mode.index);
    response.setUint8(index++, conf.comm_mode.index);
    response.setUint8(index++, conf.motor_type.index);
    response.setUint8(index++, conf.sensor_mode.index);
    response.setFloat32(index, conf.l_current_max); index += 4;
    response.setFloat32(index, conf.l_current_min); index += 4;
    response.setFloat32(index, conf.l_in_current_max); index += 4;
    response.setFloat32(index, conf.l_in_current_min); index += 4;
    response.setFloat32(index, conf.l_abs_current_max); index += 4;
    response.setFloat32(index, conf.l_min_erpm); index += 4;
    response.setFloat32(index, conf.l_max_erpm); index += 4;
    response.setFloat32(index, conf.l_erpm_start); index += 4;
    response.setFloat32(index, conf.l_max_erpm_fbrake); index += 4;
    response.setFloat32(index, conf.l_max_erpm_fbrake_cc); index += 4;
    response.setFloat32(index, conf.l_min_vin); index += 4;
    response.setFloat32(index, conf.l_max_vin); index += 4;
    response.setFloat32(index, conf.l_battery_cut_start); index += 4;
    response.setFloat32(index, conf.l_battery_cut_end); index += 4;
    response.setUint8(index++, conf.l_slow_abs_current ? 1 : 0);
    response.setFloat32(index, conf.l_temp_fet_start); index += 4;
    response.setFloat32(index, conf.l_temp_fet_end); index += 4;
    response.setFloat32(index, conf.l_temp_motor_start); index += 4;
    response.setFloat32(index, conf.l_temp_motor_end); index += 4;
    response.setFloat32(index, conf.l_temp_accel_dec); index += 4;
    response.setFloat32(index, conf.l_min_duty); index += 4;
    response.setFloat32(index, conf.l_max_duty); index += 4;
    response.setFloat32(index, conf.l_watt_max); index += 4;
    response.setFloat32(index, conf.l_watt_min); index += 4;
    response.setFloat32(index, conf.l_current_max_scale); index += 4;
    response.setFloat32(index, conf.l_current_min_scale); index += 4;
    response.setFloat32(index, conf.l_duty_start); index += 4;
    response.setFloat32(index, conf.sl_min_erpm); index += 4;
    response.setFloat32(index, conf.sl_min_erpm_cycle_int_limit); index += 4;
    response.setFloat32(index, conf.sl_max_fullbreak_current_dir_change); index += 4;
    response.setFloat32(index, conf.sl_cycle_int_limit); index += 4;
    response.setFloat32(index, conf.sl_phase_advance_at_br); index += 4;
    response.setFloat32(index, conf.sl_cycle_int_rpm_br); index += 4;
    response.setFloat32(index, conf.sl_bemf_coupling_k); index += 4;
    response.setUint8(index++, conf.hall_table[0]);
    response.setUint8(index++, conf.hall_table[1]);
    response.setUint8(index++, conf.hall_table[2]);
    response.setUint8(index++, conf.hall_table[3]);
    response.setUint8(index++, conf.hall_table[4]);
    response.setUint8(index++, conf.hall_table[5]);
    response.setUint8(index++, conf.hall_table[6]);
    response.setUint8(index++, conf.hall_table[7]);
    response.setFloat32(index, conf.hall_sl_erpm); index += 4;
    response.setFloat32(index, conf.foc_current_kp); index += 4;
    response.setFloat32(index, conf.foc_current_ki); index += 4;
    response.setFloat32(index, conf.foc_f_sw); index += 4;
    response.setFloat32(index, conf.foc_dt_us); index += 4;
    response.setUint8(index++, conf.foc_encoder_inverted ? 1 : 0);
    response.setFloat32(index, conf.foc_encoder_offset); index += 4;
    response.setFloat32(index, conf.foc_encoder_ratio); index += 4;
    response.setFloat32(index, conf.foc_encoder_sin_gain); index += 4;
    response.setFloat32(index, conf.foc_encoder_cos_gain); index += 4;
    response.setFloat32(index, conf.foc_encoder_sin_offset); index += 4;
    response.setFloat32(index, conf.foc_encoder_cos_offset); index += 4;
    response.setFloat32(index, conf.foc_encoder_sincos_filter_constant); index += 4;
    response.setUint8(index++, conf.foc_sensor_mode.index);
    response.setFloat32(index, conf.foc_pll_kp); index += 4;
    response.setFloat32(index, conf.foc_pll_ki); index += 4;
    response.setFloat32(index, conf.foc_motor_l); index += 4;
    response.setFloat32(index, conf.foc_motor_r); index += 4;
    response.setFloat32(index, conf.foc_motor_flux_linkage); index += 4;
    response.setFloat32(index, conf.foc_observer_gain); index += 4;
    response.setFloat32(index, conf.foc_observer_gain_slow); index += 4;
    response.setFloat32(index, conf.foc_duty_dowmramp_kp); index += 4;
    response.setFloat32(index, conf.foc_duty_dowmramp_ki); index += 4;
    response.setFloat32(index, conf.foc_openloop_rpm); index += 4;
    response.setFloat32(index, conf.foc_sl_openloop_hyst); index += 4;
    response.setFloat32(index, conf.foc_sl_openloop_time); index += 4;
    response.setFloat32(index, conf.foc_sl_d_current_duty); index += 4;
    response.setFloat32(index, conf.foc_sl_d_current_factor); index += 4;
    response.setUint8(index++, conf.foc_hall_table[0]);
    response.setUint8(index++, conf.foc_hall_table[1]);
    response.setUint8(index++, conf.foc_hall_table[2]);
    response.setUint8(index++, conf.foc_hall_table[3]);
    response.setUint8(index++, conf.foc_hall_table[4]);
    response.setUint8(index++, conf.foc_hall_table[5]);
    response.setUint8(index++, conf.foc_hall_table[6]);
    response.setUint8(index++, conf.foc_hall_table[7]);
    response.setFloat32(index, conf.foc_sl_erpm); index += 4;
    response.setUint8(index++, conf.foc_sample_v0_v7 ? 1 : 0);
    response.setUint8(index++, conf.foc_sample_high_current ? 1 : 0);
    response.setFloat32(index, conf.foc_sat_comp); index += 4;
    response.setUint8(index++, conf.foc_temp_comp ? 1 : 0);
    response.setFloat32(index, conf.foc_temp_comp_base_temp); index += 4;
    response.setFloat32(index, conf.foc_current_filter_const); index += 4;
    response.setUint8(index++, conf.foc_cc_decoupling.index);
    response.setUint8(index++, conf.foc_observer_type.index);
    response.setFloat32(index, conf.foc_hfi_voltage_start); index += 4;
    response.setFloat32(index, conf.foc_hfi_voltage_run); index += 4;
    response.setFloat32(index, conf.foc_hfi_voltage_max); index += 4;
    response.setFloat32(index, conf.foc_sl_erpm_hfi); index += 4;
    response.setUint16(index, conf.foc_hfi_start_samples); index += 2;
    response.setFloat32(index, conf.foc_hfi_obs_ovr_sec); index += 4;
    response.setUint8(index++, conf.foc_hfi_samples.index);
    response.setInt16(index, conf.gpd_buffer_notify_left); index += 2;
    response.setInt16(index, conf.gpd_buffer_interpol); index += 2;
    response.setFloat32(index, conf.gpd_current_filter_const); index += 4;
    response.setFloat32(index, conf.gpd_current_kp); index += 4;
    response.setFloat32(index, conf.gpd_current_ki); index += 4;
    response.setFloat32(index, conf.s_pid_kp); index += 4;
    response.setFloat32(index, conf.s_pid_ki); index += 4;
    response.setFloat32(index, conf.s_pid_kd); index += 4;
    response.setFloat32(index, conf.s_pid_kd_filter); index += 4;
    response.setFloat32(index, conf.s_pid_min_erpm); index += 4;
    response.setUint8(index++, conf.s_pid_allow_braking ? 1 : 0);
    response.setFloat32(index, conf.p_pid_kp); index += 4;
    response.setFloat32(index, conf.p_pid_ki); index += 4;
    response.setFloat32(index, conf.p_pid_kd); index += 4;
    response.setFloat32(index, conf.p_pid_kd_filter); index += 4;
    response.setFloat32(index, conf.p_pid_ang_div); index += 4;
    response.setFloat32(index, conf.cc_startup_boost_duty); index += 4;
    response.setFloat32(index, conf.cc_min_current); index += 4;
    response.setFloat32(index, conf.cc_gain); index += 4;
    response.setFloat32(index, conf.cc_ramp_step_max); index += 4;
    response.setInt32(index, conf.m_fault_stop_time_ms); index += 4;
    response.setFloat32(index, conf.m_duty_ramp_step); index += 4;
    response.setFloat32(index, conf.m_current_backoff_gain); index += 4;
    response.setUint32(index, conf.m_encoder_counts); index += 4;
    response.setUint8(index++, conf.m_sensor_port_mode.index);
    response.setUint8(index++, conf.m_invert_direction ? 1 : 0);
    response.setUint8(index++, conf.m_drv8301_oc_mode.index);
    response.setUint8(index++, conf.m_drv8301_oc_adj);
    response.setFloat32(index, conf.m_bldc_f_sw_min); index += 4;
    response.setFloat32(index, conf.m_bldc_f_sw_max); index += 4;
    response.setFloat32(index, conf.m_dc_f_sw); index += 4;
    response.setFloat32(index, conf.m_ntc_motor_beta); index += 4;
    response.setUint8(index++, conf.m_out_aux_mode.index);
    response.setUint8(index++, conf.m_motor_temp_sens_type.index);
    response.setFloat32(index, conf.m_ptc_motor_coeff); index += 4;
    response.setUint8(index++, conf.si_motor_poles);
    response.setFloat32(index, conf.si_gear_ratio); index += 4;
    response.setFloat32(index, conf.si_wheel_diameter); index += 4;
    response.setUint8(index++, conf.si_battery_type.index);
    response.setUint8(index++, conf.si_battery_cells);
    response.setFloat32(index, conf.si_battery_ah); index += 4;

    print("serializeMCCONF final index is $index");
    return response;
  }

  int buffer_get_int16(Uint8List buffer, int index) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getInt16(index);
  }

  int buffer_get_uint16(Uint8List buffer, int index) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getUint16(index);
  }
  
  int buffer_get_int32(Uint8List buffer, int index) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getInt32(index);
  }

  int buffer_get_uint32(Uint8List buffer, int index) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getUint32(index);
  }

  int buffer_get_uint64(Uint8List buffer, int index, [Endian endian = Endian.big]) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getUint64(index, endian);
  }

  double buffer_get_float16(Uint8List buffer, int index, double scale) {
    return buffer_get_int16(buffer, index) / scale;
  }

  double buffer_get_float32(Uint8List buffer, int index, double scale) {
    return buffer_get_int32(buffer, index) / scale;
  }

  double buffer_get_float32_auto(Uint8List buffer, int index) {
    Uint32List res = new Uint32List(1);
    res[0] = buffer_get_uint32(buffer, index);

    int e = (res[0] >> 23) & 0xFF;
    Uint32List sig_i = new Uint32List(1);
    sig_i[0] = res[0] & 0x7FFFFF;
    int neg_i = res[0] & (1 << 31);
    bool neg = neg_i > 0 ? true : false;

    double sig = 0.0;
    if (e != 0 || sig_i[0] != 0) {
      sig = sig_i[0].toDouble() / (8388608.0 * 2.0) + 0.5;
      e -= 126;
    }

    if (neg) {
      sig = -sig;
    }

    return ldexpf(sig, e);
  }

  // Multiplies a floating point value arg by the number 2 raised to the exp power.
  double ldexpf(double arg, int exp) {
    double result = arg * pow(2, exp);
    return result;
  }

  ///ESC Profiles
  static Future<ESCProfile> getESCProfile(int profileIndex) async {
    print("getESCProfile is loading index $profileIndex");
    final prefs = await SharedPreferences.getInstance();
    ESCProfile response = new ESCProfile();
    response.profileName = prefs.getString('profile$profileIndex name') ?? "Unnamed";
    response.speedKmh = prefs.getDouble('profile$profileIndex speedKmh') ?? 32.0;
    response.speedKmhRev = prefs.getDouble('profile$profileIndex speedKmhRev') ?? -32.0;
    response.l_current_min_scale = prefs.getDouble('profile$profileIndex l_current_min_scale') ?? 1.0;
    response.l_current_max_scale = prefs.getDouble('profile$profileIndex l_current_max_scale') ?? 1.0;
    response.l_watt_min = prefs.getDouble('profile$profileIndex l_watt_min') ?? 0.0;
    response.l_watt_max = prefs.getDouble('profile$profileIndex l_watt_max') ?? 0.0;

    return response;
  }
  static Future<String> getESCProfileName(int profileIndex) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile$profileIndex name') ?? "Unnamed";
  }
  static Future<void> setESCProfile(int profileIndex, ESCProfile profile) async {
    print("setESCProfile is saving index $profileIndex");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile$profileIndex name', profile.profileName);
    await prefs.setDouble('profile$profileIndex speedKmh', profile.speedKmh);
    await prefs.setDouble('profile$profileIndex speedKmhRev', profile.speedKmhRev);
    await prefs.setDouble('profile$profileIndex l_current_min_scale', profile.l_current_min_scale);
    await prefs.setDouble('profile$profileIndex l_current_max_scale', profile.l_current_max_scale);
    await prefs.setDouble('profile$profileIndex l_watt_min', profile.l_watt_min);
    await prefs.setDouble('profile$profileIndex l_watt_max', profile.l_watt_max);
  }

}

