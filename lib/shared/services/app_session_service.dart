import 'package:uuid/uuid.dart';

import 'package:test_app/utils/helpers/local_storage.dart';

class AppSessionService {
  static const _anonViewerIdKey = 'gtube_anon_viewer_id';

  late final String _analyticsSessionId;
  late final String _clientSessionId;
  late final String _anonymousViewerId;

  String get analyticsSessionId => _analyticsSessionId;

  String get clientSessionId => _clientSessionId;

  String get anonymousViewerId => _anonymousViewerId;

  Future<void> init() async {
    const uuid = Uuid();
    _analyticsSessionId = uuid.v4();
    _clientSessionId = uuid.v4();

    final stored = LocalStorage.getString(_anonViewerIdKey);
    if (stored != null && stored.isNotEmpty) {
      _anonymousViewerId = stored;
    } else {
      _anonymousViewerId = uuid.v4();
      await LocalStorage.setString(_anonViewerIdKey, _anonymousViewerId);
    }
  }
}
