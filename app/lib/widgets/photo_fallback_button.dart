import 'package:flutter/material.dart';

/// Secondary photo picker action shown only when camera access fails.
class PhotoFallbackButton extends StatelessWidget {
  const PhotoFallbackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.photo_outlined),
    label: const Text('Use a photo instead'),
  );
}
