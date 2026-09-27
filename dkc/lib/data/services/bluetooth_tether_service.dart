import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothTetherService {
  StreamSubscription? _adapterSubscription;
  StreamSubscription? _connectionSubscription;

  /// Arms the Bluetooth tether. If the phone is separated from the victim's
  /// smartwatch/earbuds, or if the abuser maliciously turns off Bluetooth, it triggers lockdown.
  ///
  /// Both streams replay their current state as the first event on
  /// subscribe, so we skip that one baseline reading — otherwise anyone
  /// whose Bluetooth simply happens to already be off (the common case on
  /// most phones) gets locked out the instant the vault opens.
  void startTetherMonitoring(Function onTetherBroken) {
    // 1. Monitor if the Bluetooth adapter is forcefully turned off
    _adapterSubscription = FlutterBluePlus.adapterState.skip(1).listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.off) {
        onTetherBroken();
      }
    });

    // 2. Monitor if a connected device (e.g., Apple Watch) drops out of range
    _connectionSubscription = FlutterBluePlus.events.onConnectionStateChanged.skip(1).listen((event) {
       if (event.connectionState == BluetoothConnectionState.disconnected) {
         onTetherBroken();
       }
    });
  }

  void stopMonitoring() {
    _adapterSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
