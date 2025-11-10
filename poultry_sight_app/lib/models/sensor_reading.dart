// models/sensor_reading.dart
class SensorReading {
  final String activity;
  final double temperature;
  final double humidity;
  final double lightIntensity;
  final double ammonia;

  SensorReading({
    this.activity = 'Unknown',
    this.temperature = 0.0,
    this.humidity = 0.0,
    this.lightIntensity = 0.0,
    this.ammonia = 0.0,
  });

  // A factory constructor to create a SensorReading from a Map
  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      activity: map['room_activity']?.toString() ?? 'Unknown',
      temperature: map['temperature']?.toDouble() ?? 0.0,
      humidity: map['humidity']?.toDouble() ?? 0.0,
      lightIntensity: map['light_intensity']?.toDouble() ?? 0.0,
      ammonia: map['ammonia']?.toDouble() ?? 0.0,
    );
  }
}
