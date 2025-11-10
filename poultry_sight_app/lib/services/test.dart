import 'package:poultry_app/services/egg_prediction_service.dart';

void main() async {
  // Create an instance of EggPredictionService
  final service = EggPredictionService();

  try {
    // Load the model
    await service.loadModel();

    // Run prediction with sample inputs
    int eggCount = await service.predictEggProduction(
      temperature: 20.0,
      humidity: 60.0,
      ammonia: 10.0,
      lightIntensity: 400.0,
      chickenCount: 1000.0,
    );

    // Print the result
    print('Predicted egg count: $eggCount');

    // Dispose resources
    service.dispose();
  } catch (e) {
    print('Error during prediction: $e');
  }
}