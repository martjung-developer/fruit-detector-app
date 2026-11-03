import 'package:app/models/collection_counter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts captures independently per class', () {
    final counter = CollectionCounter();
    expect(counter.countFor('fresh_apple'), 0);
    expect(counter.increment('fresh_apple'), 1);
    expect(counter.increment('fresh_apple'), 2);
    expect(counter.increment('rotten_orange'), 1);
    expect(counter.countFor('fresh_apple'), 2);
  });
}
