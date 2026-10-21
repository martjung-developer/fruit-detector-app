import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../models/prediction_result.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/probability_list.dart';
import '../widgets/result_card.dart';
import '../widgets/upload_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiClient _api = ApiClient();
  Uint8List? _imageBytes;
  String? _filename;
  Prediction? _prediction;
  String? _error;
  bool _loading = false;

  Future<void> _pickAndPredict() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _filename = file.name;
        _prediction = null;
        _error = null;
      });
      await _runPrediction(bytes, file.name);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not select or read that image. Please try another file.';
      });
    }
  }

  Future<void> _runPrediction(Uint8List bytes, String filename) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prediction = await _api.predict(bytes, filename);
      if (mounted) setState(() => _prediction = prediction);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not reach the classification server. Make sure the API is running.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _retry() {
    final bytes = _imageBytes;
    final filename = _filename;
    if (bytes != null && filename != null) {
      _runPrediction(bytes, filename);
    } else {
      _pickAndPredict();
    }
  }

  Widget _resultContent() {
    if (_loading) return const LoadingSkeleton(key: ValueKey('loading'));
    if (_error != null) {
      return ErrorState(
        key: const ValueKey('error'),
        message: _error!,
        onRetry: _retry,
      );
    }
    final prediction = _prediction;
    if (prediction == null) return const EmptyState(key: ValueKey('empty'));
    return Column(
      key: const ValueKey('result'),
      children: [
        ResultCard(prediction: prediction),
        const SizedBox(height: AppSpacing.medium),
        ProbabilityList(prediction: prediction),
      ],
    );
  }

  Widget _animatedResult() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 450),
    switchInCurve: Curves.easeOutCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: _resultContent(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader(),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = Responsive.isDesktop(constraints.maxWidth);
          final horizontalPadding = Responsive.isMobile(constraints.maxWidth)
              ? AppSpacing.medium
              : AppSpacing.large;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.large,
              horizontalPadding,
              AppSpacing.extraLarge,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: UploadCard(
                              onPick: _pickAndPredict,
                              loading: _loading,
                              imageBytes: _imageBytes,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.large),
                          Expanded(child: _animatedResult()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          UploadCard(
                            onPick: _pickAndPredict,
                            loading: _loading,
                            imageBytes: _imageBytes,
                          ),
                          const SizedBox(height: AppSpacing.large),
                          _animatedResult(),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
