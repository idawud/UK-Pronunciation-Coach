// On-device check that the connectivity_plus plug-in is registered and answers
// (A2's Wi-Fi-only download check). No network traffic: it only asks the OS which
// transport is active, so it passes with the network on or off.
//
//   flutter test integration_test/A2-runtime -d <device>
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uk_pronunciation_coach/engine/runtime/network.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the production monitor uses connectivity_plus', (_) async {
    final monitor = platformNetworkMonitor();
    expect(monitor, isA<ConnectivityNetworkMonitor>());
    final results = await Connectivity().checkConnectivity();
    expect(results, isNotEmpty);
    final unmetered = await monitor.isUnmetered();
    final settled = ConnectivityNetworkMonitor.classify(results);
    if (settled != null) expect(unmetered, settled);
  });
}
