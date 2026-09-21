class BatteryMeasurement {
  final int cellNumber;
  final int stringNumber;
  final double voltage;           // Volts (e.g. 2.15V)
  final double temperature;       // Celsius (e.g. 28.5C)
  final double internalResistance;// mOhm (e.g. 0.35)
  final String notes;

  const BatteryMeasurement({
    required this.cellNumber,
    this.stringNumber = 1,
    this.voltage = 2.15,
    this.temperature = 28.0,
    this.internalResistance = 0.32,
    this.notes = '',
  });

  BatteryMeasurement copyWith({
    double? voltage,
    double? temperature,
    double? internalResistance,
    String? notes,
  }) {
    return BatteryMeasurement(
      cellNumber: cellNumber,
      stringNumber: stringNumber,
      voltage: voltage ?? this.voltage,
      temperature: temperature ?? this.temperature,
      internalResistance: internalResistance ?? this.internalResistance,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'cellNumber': cellNumber,
    'stringNumber': stringNumber,
    'voltage': voltage,
    'temperature': temperature,
    'internalResistance': internalResistance,
    'notes': notes,
  };

  factory BatteryMeasurement.fromJson(Map<String, dynamic> json) => BatteryMeasurement(
    cellNumber: json['cellNumber'] ?? 1,
    stringNumber: json['stringNumber'] ?? 1,
    voltage: (json['voltage'] as num?)?.toDouble() ?? 2.15,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 28.0,
    internalResistance: (json['internalResistance'] as num?)?.toDouble() ?? 0.32,
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
    this.status = 'طبيعي',
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
    status: json['status'] ?? 'طبيعي',
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
  final double calculatedPower;
  final String notes;

  const StringMeasurement({
    required this.stringNumber,
    this.panelCount = 8,
    this.openCircuitVoltageVoc = 390.0,
    this.shortCircuitCurrentIsc = 14.5,
    this.operatingVoltageVmp = 320.0,
    this.operatingCurrentImp = 13.8,
    this.solarIrradiance = 850.0,
    this.calculatedPower = 4416.0,
    this.notes = 'أداء مطابق للمعايير',
  });

  StringMeasurement copyWith({
    int? panelCount,
    double? openCircuitVoltageVoc,
    double? shortCircuitCurrentIsc,
    double? operatingVoltageVmp,
    double? operatingCurrentImp,
    double? solarIrradiance,
    double? calculatedPower,
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
      calculatedPower: calculatedPower ?? this.calculatedPower,
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
    panelCount: json['panelCount'] ?? 8,
    openCircuitVoltageVoc: (json['openCircuitVoltageVoc'] as num?)?.toDouble() ?? 390.0,
    shortCircuitCurrentIsc: (json['shortCircuitCurrentIsc'] as num?)?.toDouble() ?? 14.5,
    operatingVoltageVmp: (json['operatingVoltageVmp'] as num?)?.toDouble() ?? 320.0,
    operatingCurrentImp: (json['operatingCurrentImp'] as num?)?.toDouble() ?? 13.8,
    solarIrradiance: (json['solarIrradiance'] as num?)?.toDouble() ?? 850.0,
    calculatedPower: (json['calculatedPower'] as num?)?.toDouble() ?? 4416.0,
    notes: json['notes'] ?? '',
  );
}

typedef OperationalReading = OperationalData;
