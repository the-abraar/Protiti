import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

class AlibiService {
  /// Silently schedules a completely native-looking incoming phone call.
  /// This provides the victim a socially acceptable reason to leave a dangerous room.
  static Future<void> scheduleFakeCall({int delaySeconds = 15}) async {
    Future.delayed(Duration(seconds: delaySeconds), () async {
      
      final callParams = CallKitParams(
        id: const Uuid().v4(),
        nameCaller: 'HR Department', // A boring, highly believable interruption
        appName: 'Phone',
        handle: 'Work Urgent',
        type: 0,
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: false, // Don't leave suspicious missed call logs
        ),
        extra: <String, dynamic>{'isAlibi': true},
      );
      
      // Triggers the physical OS-level incoming call UI (works even if the phone is locked!)
      await FlutterCallkitIncoming.showCallkitIncoming(callParams);
    });
  }
}
