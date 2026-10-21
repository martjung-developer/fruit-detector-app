/// Typed prediction returned by the classifier API.
class Prediction {
  const Prediction({
    required this.label,
    required this.fruit,
    required this.quality,
    required this.confidence,
    required this.probabilities,
    required this.lowConfidence,
  });

  final String label;
  final String fruit;
  final String quality;
  final double confidence;
  final Map<String, double> probabilities;
  final bool lowConfidence;

  /// Parse a JSON response while reporting useful errors for malformed fields.
  factory Prediction.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('The API returned an unexpected response.');
    }
    final rawProbabilities = value['probabilities'];
    if (rawProbabilities is! Map<String, dynamic>) {
      throw const FormatException(
        'The API response is missing probability scores.',
      );
    }
    final probabilities = <String, double>{};
    for (final entry in rawProbabilities.entries) {
      if (entry.value is! num) {
        throw const FormatException(
          'The API returned an invalid probability score.',
        );
      }
      probabilities[entry.key] = (entry.value as num).toDouble();
    }
    final label = value['label'];
    final fruit = value['fruit'];
    final quality = value['quality'];
    final confidence = value['confidence'];
    if (label is! String ||
        fruit is! String ||
        quality is! String ||
        confidence is! num) {
      throw const FormatException(
        'The API response is missing prediction details.',
      );
    }
    return Prediction(
      label: label,
      fruit: fruit,
      quality: quality,
      confidence: confidence.toDouble(),
      probabilities: probabilities,
      lowConfidence: value['low_confidence'] == true,
    );
  }

  /// Human-friendly class label such as `Fresh orange`.
  String get humanLabel => _titleCase(label.replaceAll('_', ' '));

  /// Fruit title for the main result heading.
  String get fruitTitle => _titleCase(fruit);

  /// Quality title for the main result badge.
  String get qualityTitle => _titleCase(quality);

  /// Probabilities ordered from most likely to least likely.
  List<MapEntry<String, double>> get sortedProbabilities {
    final entries = probabilities.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    return entries;
  }

  static String _titleCase(String value) => value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
