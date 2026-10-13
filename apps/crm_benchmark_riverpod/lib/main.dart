import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/crm_state_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  final actions = container.read(crmProvider.notifier);
  runApp(RiverpodBenchApp(container: container, selective: BenchConfig.isSelective));
  SessionRunner(actions: actions, library: 'riverpod').startAfterFirstFrame();
}
