/// `1:04:09` for anything over an hour, `4:09` otherwise.
String formatClock(Duration d) {
  final total = d.inSeconds;
  final s = (total % 60).toString().padLeft(2, '0');
  final m = (total ~/ 60) % 60;
  final h = total ~/ 3600;
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
