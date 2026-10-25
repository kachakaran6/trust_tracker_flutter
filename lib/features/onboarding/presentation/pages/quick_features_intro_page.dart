import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';

class QuickFeaturesIntroPage extends ConsumerWidget {
  const QuickFeaturesIntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 80,
                      color: cs.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Supercharge Your Workflow',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Trust Tracker comes with powerful shortcuts to help you track finances instantly.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildFeatureItem(
                      context,
                      icon: Icons.settings_suggest_rounded,
                      title: 'Quick Settings Tile',
                      description: 'Pull down your notification shade and add the Trust Tracker tile (Wallet icon) to quickly add a transaction without opening the app.',
                    ),
                    const SizedBox(height: 32),
                    _buildFeatureItem(
                      context,
                      icon: Icons.touch_app_rounded,
                      title: 'App Shortcuts',
                      description: 'Long press the Trust Tracker app icon on your home screen to jump straight into adding income, expenses, or viewing analytics.',
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () {
                  ref.read(settingsProvider.notifier).setHasSeenQuickFeaturesIntro(true);
                  // the router redirect should automatically push us to /dashboard
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, {required IconData icon, required String title, required String description}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cs.onPrimaryContainer, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
