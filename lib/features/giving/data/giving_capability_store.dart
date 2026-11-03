import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/giving/repo/donor_giving_repo.dart';

/// Who can be given to, remembered for as long as that is safe.
///
/// Every surface that draws a Give button needs the same answer about the same
/// handful of ministries, and the answer is public, cheap and identical for
/// every reader — so asking once per screen would be several requests for one
/// fact. This holds it for the session.
///
/// Three things it is careful about:
///
/// - **Unknown is not false.** [known] answers `null` for a ministry nobody
///   has asked about, which is what lets a surface tell "no Give button" apart
///   from "not asked yet" and fetch rather than silently withhold the action.
/// - **It expires.** A ministry can be restricted mid-session — the guide says
///   to cache only briefly — so an entry older than [ttl] is re-read. Offering
///   Give for a ministry that has since been suspended walks the giver into a
///   refusal they cannot act on.
/// - **One flight per creator.** Two cards asking at once share a request
///   instead of racing, which matters most on a feed where the same ministry
///   appears several times.
class GivingCapabilityStore extends ChangeNotifier {
  GivingCapabilityStore({DonorGivingRepo? repo})
    : _repo = repo ?? DonorGivingRepo();

  /// Short enough that a restriction is noticed within a sitting, long enough
  /// that scrolling a feed does not re-ask about every card.
  static const ttl = Duration(minutes: 5);

  final DonorGivingRepo _repo;
  final Map<String, _Entry> _entries = {};
  final Map<String, Future<bool>> _inFlight = {};

  /// What is already known, without asking. `null` means unasked or stale.
  bool? known(String creatorId) {
    final entry = _entries[creatorId];
    if (entry == null || entry.isStale) return null;
    return entry.available;
  }

  /// The answer, fetched if it is not already held.
  ///
  /// Never throws: a lookup that fails answers `false`, because a Give button
  /// drawn on a guess is worse than one missing. The entry is not cached in
  /// that case, so the next surface tries again.
  Future<bool> ensure(String creatorId) {
    if (creatorId.isEmpty) return Future.value(false);
    final cached = known(creatorId);
    if (cached != null) return Future.value(cached);
    return _inFlight[creatorId] ??= _fetch(creatorId);
  }

  Future<bool> _fetch(String creatorId) async {
    try {
      final available = await _repo.fetchCapability(creatorId);
      _put(creatorId, available);
      return available;
    } catch (e) {
      logger.w('Giving capability lookup failed', error: e);
      return false;
    } finally {
      _inFlight.remove(creatorId);
    }
  }

  /// Looks up a page of ministries in one request.
  ///
  /// Ones already held are not asked about again, so a feed that pages in more
  /// rows only pays for the ministries it has not seen.
  Future<void> prime(Iterable<String> creatorIds) async {
    final wanted = {
      for (final id in creatorIds)
        if (id.isNotEmpty && known(id) == null) id,
    };
    if (wanted.isEmpty) return;
    try {
      final answers = await _repo.fetchCapabilities(wanted.toList());
      if (answers.isEmpty) return;
      answers.forEach((id, available) => _entries[id] = _Entry(available));
      notifyListeners();
    } catch (e) {
      // A feed with no Give buttons is the safe outcome; nothing is drawn on
      // an unanswered question.
      logger.w('Giving capability batch failed', error: e);
    }
  }

  void _put(String creatorId, bool available) {
    _entries[creatorId] = _Entry(available);
    notifyListeners();
  }

  @visibleForTesting
  void seed(String creatorId, bool available) => _put(creatorId, available);

  @visibleForTesting
  void clear() {
    _entries.clear();
    _inFlight.clear();
  }
}

class _Entry {
  _Entry(this.available) : at = DateTime.now();

  final bool available;
  final DateTime at;

  bool get isStale => DateTime.now().difference(at) > GivingCapabilityStore.ttl;
}
