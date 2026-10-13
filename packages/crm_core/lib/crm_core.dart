/// Kode bersama benchmark CRM. Satu-satunya kode yang berbeda antar-aplikasi
/// adalah lapisan *state management*; selebihnya berada di sini.
library;

export 'src/config.dart';
export 'src/data/mock_data.dart';
export 'src/driver/crm_actions.dart';
export 'src/driver/update_driver.dart';
export 'src/driver/update_plan.dart';
export 'src/instrumentation/frame_recorder.dart';
export 'src/instrumentation/memory_sampler.dart';
export 'src/instrumentation/rebuild_counter.dart';
export 'src/instrumentation/result_writer.dart';
export 'src/instrumentation/session_runner.dart';
export 'src/instrumentation/stats.dart';
export 'src/model/crm_state.dart';
export 'src/model/customer.dart';
export 'src/ui/bench_app.dart';
export 'src/ui/counter_view.dart';
export 'src/ui/customer_list_view.dart';
export 'src/ui/customer_tile.dart';
export 'src/ui/dashboard_layout.dart';
export 'src/ui/search_field_view.dart';
