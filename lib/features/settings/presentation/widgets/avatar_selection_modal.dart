import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:trust_tracker_flutter/core/constants/app_avatars.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

/// Shows the avatar selection modal. This is a shared component used in both
/// Settings and Dashboard for profile customization.
void showAvatarSelectionModal({
  required BuildContext context,
  required WidgetRef ref,
  required SettingsState settings,
}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final tt = theme.textTheme;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.chooseAvatar,
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (settings.userAvatar != null)
                    TextButton(
                      onPressed: () {
                        ref.read(settingsProvider.notifier).setUserAvatar(null);
                        Navigator.pop(context);
                      },
                      child: Text(l10n.resetAvatar),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // --- Custom Photo Option ---
              InkWell(
                onTap: () async {
                  await _handleCustomPhoto(context, ref);
                  if (context.mounted) Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.primary.withOpacity(0.2)),
                    color: cs.primary.withOpacity(0.05),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "Upload Custom Photo",
                        style: tt.titleMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // --- Grid of Preset Avatars ---
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                  ),
                  itemCount: AppAvatars.avatarList.length,
                  itemBuilder: (context, index) {
                    final avatarPath = AppAvatars.avatarList[index];
                    final isSelected = settings.userAvatar == avatarPath;
                    return GestureDetector(
                      onTap: () {
                        ref.read(settingsProvider.notifier).setUserAvatar(avatarPath);
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? cs.primary : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            avatarPath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _handleCustomPhoto(BuildContext context, WidgetRef ref) async {
  try {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'user_avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final localPath = p.join(appDir.path, fileName);

    final File localFile = await File(image.path).copy(localPath);
    await ref.read(settingsProvider.notifier).setUserAvatar(localFile.path);
    HapticFeedback.mediumImpact();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }
}
