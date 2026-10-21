import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../models/prediction.dart';
import '../widgets/probability_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiClient _api = ApiClient();
  Uint8List? _bytes;
  Prediction? _prediction;
  bool _loading = false;
  String? _error;

  Future<void> _pickAndPredict() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _bytes = bytes;
        _prediction = null;
        _error = null;
        _loading = true;
      });
      final prediction = await _api.predict(bytes, file.name);
      if (mounted) setState(() => _prediction = prediction);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not select or read that image. Please try another file.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _prediction?.probabilities.entries.toList()
      ?..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: const Text('Fruit Quality Classifier')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _pickAndPredict,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload fruit image'),
                ),
                const SizedBox(height: 16),
                if (_bytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_bytes!, height: 260, fit: BoxFit.cover),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_prediction case final prediction?) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${prediction.fruit} - ${prediction.quality}'.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Confidence: ${prediction.confidence.toStringAsFixed(2)}%',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (prediction.lowConfidence)
                    const Chip(label: Text('Low confidence')),
                  const SizedBox(height: 12),
                  for (final entry in entries ?? <MapEntry<String, double>>[])
                    ProbabilityBar(label: entry.key, value: entry.value),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
