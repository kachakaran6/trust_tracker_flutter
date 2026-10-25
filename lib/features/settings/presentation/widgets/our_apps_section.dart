import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kOurAppsJsonUrl =
  'https://raw.githubusercontent.com/kachakaran6/Application-json/main/app.json';
const String _kCacheKey = 'our_apps_cache_json';
const String _kCacheTimeKey = 'our_apps_cache_time';

class AppPromoModel {
  final String id;
  final String appName;
  final String packageName;
  final String playStoreUrl;
  final String iconUrl;
  final String description;
  final String status;

  AppPromoModel({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.playStoreUrl,
    required this.iconUrl,
    required this.description,
    this.status = '',
  });

  factory AppPromoModel.fromJson(Map<String, dynamic> json) {
    return AppPromoModel(
      id: json['id'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      playStoreUrl: json['playStoreUrl'] as String? ?? '',
      iconUrl: json['iconUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class OurAppsSection extends StatefulWidget {
  const OurAppsSection({super.key});

  @override
  State<OurAppsSection> createState() => _OurAppsSectionState();
}

class _OurAppsSectionState extends State<OurAppsSection> {
  List<AppPromoModel> _apps = [];
  bool _isLoading = true;
  bool _isOffline = false;
  bool _hasError = false;
  String _currentPackageName = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentPackageName();
    _loadApps();
  }

  Future<void> _loadCurrentPackageName() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _currentPackageName = info.packageName;
      });
    } catch (_) {}
  }

  Future<void> _loadApps({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
      _hasError = false;
    });

    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cached = prefs.getString(_kCacheKey);
      final cacheTime = prefs.getInt(_kCacheTimeKey) ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (cached != null && cacheAge < const Duration(hours: 24).inMilliseconds) {
        try {
          final decoded = jsonDecode(cached);
          setState(() {
            _apps = _parseApps(decoded);
            _isLoading = false;
          });
          return;
        } catch (_) {}
      }
    }

    try {
      final response = await http
          .get(Uri.parse(_kOurAppsJsonUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        await prefs.setString(_kCacheKey, response.body);
        await prefs.setInt(_kCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        setState(() {
          _apps = _parseApps(decoded);
          _isLoading = false;
        });
      } else {
        _tryLoadFromCache(prefs);
      }
    } catch (e) {
      debugPrint('OurAppsSection: Network error: $e');
      _tryLoadFromCache(prefs);
    }
  }

  void _tryLoadFromCache(SharedPreferences prefs) {
    final cached = prefs.getString(_kCacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        setState(() {
          _apps = _parseApps(decoded);
          _isLoading = false;
          _isOffline = true;
        });
        return;
      } catch (_) {}
    }
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  Future<void> _openPlayStore(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<AppPromoModel> _parseApps(dynamic decoded) {
    final List<dynamic> appsJson = decoded is Map<String, dynamic>
        ? (decoded['apps'] as List<dynamic>? ?? const <dynamic>[])
        : decoded is List
            ? decoded
            : const <dynamic>[];

    return appsJson
        .whereType<Map>()
        .map((app) => AppPromoModel.fromJson(Map<String, dynamic>.from(app)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OUR APPS',
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              if (_isOffline)
                Chip(
                  label: Text('Offline', style: tt.labelSmall),
                  avatar: const Icon(Icons.cloud_off_rounded, size: 14),
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
            ],
          ),
        ),
        _buildContent(context),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    if (_isLoading) {
      return _buildLoading(context);
    }

    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, color: cs.onSurface.withOpacity(0.3), size: 40),
            const SizedBox(height: 8),
            Text(
              'Unable to load apps. Check your connection.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _loadApps(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_apps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            'No apps available.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.5)),
          ),
        ),
      );
    }

    return Column(
      children: _apps
          .map(
            (app) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OurAppCard(
                app: app,
                isCurrentApp: app.packageName == _currentPackageName,
                onTap: () => _openPlayStore(app.playStoreUrl),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: List.generate(4, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outline.withOpacity(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 140, height: 16, color: cs.surfaceContainerHighest),
                      const SizedBox(height: 8),
                      Container(width: double.infinity, height: 12, color: cs.surfaceContainerHighest),
                      const SizedBox(height: 4),
                      Container(width: 200, height: 12, color: cs.surfaceContainerHighest),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 70,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _OurAppCard extends StatelessWidget {
  final AppPromoModel app;
  final bool isCurrentApp;
  final VoidCallback onTap;

  const _OurAppCard({required this.app, required this.isCurrentApp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 64,
                        height: 64,
                        color: cs.surfaceContainerHighest,
                        child: _buildIcon(app.iconUrl),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.appName,
                            style: TextStyle(
                              color: theme.textTheme.titleMedium?.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            app.description,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      height: 32,
                      child: _buildAction(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (isCurrentApp) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: theme.disabledColor.withValues(alpha: 0.2)),
        ),
        child: Text(
          'Installed',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: theme.disabledColor,
            fontFamily: 'Inter',
          ),
        ),
      );
    }

    if (app.status == 'coming_soon') {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: theme.disabledColor.withValues(alpha: 0.2)),
        ),
        child: Text(
          'Soon',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.disabledColor,
            fontFamily: 'Inter',
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary.withValues(alpha: 0.1),
        foregroundColor: cs.primary,
        padding: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        'Get',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
      ),
    );
  }

  Widget _buildIcon(String url) {
    if (url.isEmpty) {
      return const Icon(Icons.apps_rounded, size: 32, color: Colors.grey);
    }

    var finalUrl = url;
    if (!url.startsWith('http')) {
      finalUrl = 'https://raw.githubusercontent.com/kachakaran6/Application-json/main$url';
    }

    return Image.network(
      finalUrl,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return const Icon(Icons.android_rounded, size: 32, color: Colors.grey);
      },
    );
  }

  Widget _placeholderIcon(ColorScheme cs) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.apps_rounded, color: cs.onPrimaryContainer, size: 28),
    );
  }
}
