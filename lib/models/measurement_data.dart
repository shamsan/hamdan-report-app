class BatteryMeasurement {
  final int cellNumber;
  final int stringNumber;
  final double voltage;     // Volts (e.g. 2.15V)
  final double boltTorque;  // N.m (عزم براغي الربط)
  final String notes;

  const BatteryMeasurement({
    required this.cellNumber,
    this.stringNumber = 1,
    this.voltage = 0.0,
    this.boltTorque = 0.0,
    this.notes = '',
  });

  BatteryMeasurement copyWith({
    double? voltage,
    double? boltTorque,
    String? notes,
  }) {
    return BatteryMeasurement(
      cellNumber: cellNumber,
      stringNumber: stringNumber,
      voltage: voltage ?? this.voltage,
      boltTorque: boltTorque ?? this.boltTorque,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'cellNumber': cellNumber,
    'stringNumber': stringNumber,
    'voltage': voltage,
    'boltTorque': boltTorque,
    'notes': notes,
  };

  factory BatteryMeasurement.fromJson(Map<String, dynamic> json) => BatteryMeasurement(
    cellNumber: json['cellNumber'] ?? 1,
    stringNumber: json['stringNumber'] ?? 1,
    voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
    boltTorque: (json['boltTorque'] as num?)?.toDouble() ?? 0.0,
    notes: json['notes'] ?? '',
  );
}

class OperationalData {
  final String id;
  final String parameter;
  final String unit;
  final String measuredValue;
  final String standardRange;
  final String status;
  final String notes;

  const OperationalData({
    required this.id,
    required this.parameter,
    required this.unit,
    required this.measuredValue,
    required this.standardRange,
    this.status = '',
    this.notes = '',
  });

  String get parameterName => parameter;

  OperationalData copyWith({
    String? measuredValue,
    String? status,
    String? notes,
  }) {
    return OperationalData(
      id: id,
      parameter: parameter,
      unit: unit,
      measuredValue: measuredValue ?? this.measuredValue,
      standardRange: standardRange,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parameter': parameter,
    'unit': unit,
    'measuredValue': measuredValue,
    'standardRange': standardRange,
    'status': status,
    'notes': notes,
  };

  factory OperationalData.fromJson(Map<String, dynamic> json) => OperationalData(
    id: json['id'] ?? '',
    parameter: json['parameter'] ?? '',
    unit: json['unit'] ?? '',
    measuredValue: json['measuredValue'] ?? '',
    standardRange: json['standardRange'] ?? '',
    status: json['status'] ?? '',
    notes: json['notes'] ?? '',
  );
}

class StringMeasurement {
  final int stringNumber;
  final int panelCount;
  final double openCircuitVoltageVoc;
  final double shortCircuitCurrentIsc;
  final double operatingVoltageVmp;
  final double operatingCurrentImp;
  final double solarIrradiance; // W/m2
  final String notes;

  const StringMeasurement({
    required this.stringNumber,
    this.panelCount = 0,
    this.openCircuitVoltageVoc = 0.0,
    this.shortCircuitCurrentIsc = 0.0,
    this.operatingVoltageVmp = 0.0,
    this.operatingCurrentImp = 0.0,
    this.solarIrradiance = 0.0,
    this.notes = '',
  });

  /// Dynamic calculated power (W) = Vmp * Imp
  double get calculatedPower => (operatingVoltageVmp > 0 && operatingCurrentImp > 0)
      ? (operatingVoltageVmp * operatingCurrentImp).roundToDouble()
      : 0.0;

  bool get hasData => openCircuitVoltageVoc > 0 || shortCircuitCurrentIsc > 0 || operatingVoltageVmp > 0;

  StringMeasurement copyWith({
    int? panelCount,
    double? openCircuitVoltageVoc,
    double? shortCircuitCurrentIsc,
    double? operatingVoltageVmp,
    double? operatingCurrentImp,
    double? solarIrradiance,
    String? notes,
  }) {
    return StringMeasurement(
      stringNumber: stringNumber,
      panelCount: panelCount ?? this.panelCount,
      openCircuitVoltageVoc: openCircuitVoltageVoc ?? this.openCircuitVoltageVoc,
      shortCircuitCurrentIsc: shortCircuitCurrentIsc ?? this.shortCircuitCurrentIsc,
      operatingVoltageVmp: operatingVoltageVmp ?? this.operatingVoltageVmp,
      operatingCurrentImp: operatingCurrentImp ?? this.operatingCurrentImp,
      solarIrradiance: solarIrradiance ?? this.solarIrradiance,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'stringNumber': stringNumber,
    'panelCount': panelCount,
    'openCircuitVoltageVoc': openCircuitVoltageVoc,
    'shortCircuitCurrentIsc': shortCircuitCurrentIsc,
    'operatingVoltageVmp': operatingVoltageVmp,
    'operatingCurrentImp': operatingCurrentImp,
    'solarIrradiance': solarIrradiance,
    'calculatedPower': calculatedPower,
    'notes': notes,
  };

  factory StringMeasurement.fromJson(Map<String, dynamic> json) => StringMeasurement(
    stringNumber: json['stringNumber'] ?? 1,
    panelCount: json['panelCount'] ?? 0,
    openCircuitVoltageVoc: (json['openCircuitVoltageVoc'] as num?)?.toDouble() ?? 0.0,
    shortCircuitCurrentIsc: (json['shortCircuitCurrentIsc'] as num?)?.toDouble() ?? 0.0,
    operatingVoltageVmp: (json['operatingVoltageVmp'] as num?)?.toDouble() ?? 0.0,
    operatingCurrentImp: (json['operatingCurrentImp'] as num?)?.toDouble() ?? 0.0,
    solarIrradiance: (json['solarIrradiance'] as num?)?.toDouble() ?? 0.0,
    notes: json['notes'] ?? '',
  );
}

typedef OperationalReading = OperationalData;
