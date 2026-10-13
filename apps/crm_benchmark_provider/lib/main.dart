import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'state/crm_state_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = CrmStateProvider();
  runApp(ProviderBenchApp(state: state, selective: BenchConfig.isSelective));
  SessionRunner(actions: state, library: 'provider').startAfterFirstFrame();
}
