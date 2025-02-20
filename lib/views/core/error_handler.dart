import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/models/error_model.dart';

class GlobalErrorHandler extends ConsumerWidget {
  final Widget child;
  const GlobalErrorHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(errorProvider);

    return Stack(
      children: [
        child,
        if (error != null) _buildErrorOverlay(context, error, ref),
      ],
    );
  }

  Widget _buildErrorOverlay(
      BuildContext context, AppError error, WidgetRef ref) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(errorProvider.notifier).clearError(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
