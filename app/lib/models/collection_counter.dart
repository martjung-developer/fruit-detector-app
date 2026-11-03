/// In-memory capture counts for the nine teacher-labeled classes.
class CollectionCounter {
  final Map<String, int> _counts = {};
  int countFor(String label) => _counts[label] ?? 0;
  int increment(String label) {
    final next = countFor(label) + 1;
    _counts[label] = next;
    return next;
  }
}
