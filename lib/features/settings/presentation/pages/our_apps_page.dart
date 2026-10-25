import 'package:flutter/material.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/widgets/our_apps_section.dart';

class OurAppsPage extends StatelessWidget {
  const OurAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Apps'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          OurAppsSection(),
        ],
      ),
    );
  }
}