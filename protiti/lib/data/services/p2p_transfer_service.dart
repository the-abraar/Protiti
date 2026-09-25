import 'dart:io';
import 'package:nearby_connections/nearby_connections.dart';

class P2PTransferService {
  // P2P_STAR allows one host (the victim) to securely connect to a trusted receiver
  static const Strategy strategy = Strategy.P2P_STAR;
  
  // Obfuscated service ID to prevent scanning by unauthorized apps
  static const String serviceId = "com.android.system.sync.protocol.v2";

  /// Initiates an offline BLE/Wi-Fi Direct broadcast
  Future<void> startOfflineBroadcast(String stealthAlias) async {
    try {
      await Nearby().startAdvertising(
        stealthAlias, // E.g., "Galaxy_S21_Guest" to hide Protiti's signature
        strategy,
        onConnectionInitiated: (id, info) {
          // The UI should prompt the user to verify a connection pin before accepting
          Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              // Receiver logic for incoming encrypted evidence
            },
            onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            // Secure tunnel established
          }
        },
        onDisconnected: (id) {},
        serviceId: serviceId,
      );
    } catch (e) {
      // Graceful fail if hardware radios are forced off
    }
  }

  /// Fires the encrypted vault ZIP payload over the offline tunnel
  Future<void> dispatchEncryptedVault(String endpointId, File encryptedPayload) async {
    await Nearby().sendFilePayload(endpointId, encryptedPayload.path);
  }
  
  void stopBroadcast() {
    Nearby().stopAdvertising();
    Nearby().stopAllEndpoints();
  }
}
