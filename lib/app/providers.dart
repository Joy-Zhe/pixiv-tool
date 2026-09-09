import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_services.dart';

final appServicesProvider = Provider<AppServices>((ref) {
  throw StateError('AppServices was not initialized');
});
