import '../../data/services/location_service.dart';

class TriggerPanicUseCase {
  final LocationService locationService;
  
  TriggerPanicUseCase(this.locationService);

  Future<void> execute() async {
    final loc = await locationService.getCurrentLocation();
    // Send SMS to emergency contacts with loc
  }
}
