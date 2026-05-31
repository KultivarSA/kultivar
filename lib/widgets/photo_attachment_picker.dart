import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../screens/photo_markup_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/image_cache_size.dart';
import '../utils/photo_path_resolver.dart';

class PhotoAttachmentPicker extends StatelessWidget {
  final List<String> photoPaths;
  final void Function(String path) onPhotoAdded;
  final void Function(String path) onPhotoRemoved;
  /// Called with (oldFilename, newFilename) when a photo is replaced by its
  /// annotated version. If null, the markup button is not shown.
  final void Function(String oldPath, String newPath)? onPhotoReplaced;

  const PhotoAttachmentPicker({
    super.key,
    required this.photoPaths,
    required this.onPhotoAdded,
    required this.onPhotoRemoved,
    this.onPhotoReplaced,
  });

  Future<void> _openMarkup(BuildContext context, String filename) async {
    final resolved = PhotoPathResolver.resolve(filename);
    final newFilename = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoMarkupScreen(photoPath: resolved),
      ),
    );
    if (newFilename != null && newFilename.isNotEmpty) {
      onPhotoReplaced?.call(filename, newFilename);
    }
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title:
                  Text('Take Photo', style: AppTypography.labelLarge(context)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('Choose from Gallery',
                  style: AppTypography.labelLarge(context)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final List<XFile> picked;

    // Compression policy (P2):
    //   • imageQuality 85 — visually indistinguishable from the source
    //     for grow photos, ~20-30% smaller files than the original 80.
    //   • maxWidth/maxHeight 1920 — caps dimensions so a 12-megapixel
    //     iPhone shot drops from ~4032 px to 1920 px on its long edge.
    //     Effective file-size drop: 4 MB HEIC → ~250-450 KB JPEG.
    //   • image_picker resizes + re-encodes via platform-native libs
    //     (UIImage on iOS, BitmapFactory on Android) so we avoid an
    //     extra dependency on flutter_image_compress.
    //   • When imageQuality is set, image_picker always emits JPEG
    //     regardless of the source format — solves the "stored .HEIC
    //     that can't be rendered" problem for iPhone users.
    const kMaxDim = 1920.0;
    const kQuality = 85;

    if (source == ImageSource.gallery) {
      picked = await picker.pickMultiImage(
        imageQuality: kQuality,
        maxWidth: kMaxDim,
        maxHeight: kMaxDim,
      );
    } else {
      final single = await picker.pickImage(
        source: source,
        imageQuality: kQuality,
        maxWidth: kMaxDim,
        maxHeight: kMaxDim,
      );
      picked = single != null ? [single] : [];
    }

    for (final xFile in picked) {
      final dir = await getApplicationDocumentsDirectory();
      final filename = '${DateTime.now().millisecondsSinceEpoch}_'
          '${p.basename(xFile.path)}';
      final dest = File('${dir.path}/$filename');
      await dest.writeAsBytes(await xFile.readAsBytes());
      // Store only the filename — PhotoPathResolver.resolve() reconstructs
      // the full path at display time, making the stored value device-agnostic.
      onPhotoAdded(filename);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Photos', style: AppTypography.bodySmall(context)),
            GestureDetector(
              onTap: () => _pickPhoto(context),
              child: Row(children: [
                const Icon(Icons.add_photo_alternate,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.xxs),
                Text('Add',
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: AppColors.primary)),
              ]),
            ),
          ],
        ),
        if (photoPaths.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photoPaths.length,
              itemBuilder: (_, i) {
                final path = PhotoPathResolver.resolve(photoPaths[i]);
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(path),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          // P1.4 — cap decode at 90 × DPR.
                          cacheWidth: imageCacheWidth(context, 90),
                          // A9 — preview thumbnail in the attachment
                          // strip; the parent tap target above already
                          // exposes "Photo, remove" as a button.
                          semanticLabel: 'Attached photo preview',
                          errorBuilder: (_, __, ___) => Container(
                            width: 90,
                            height: 90,
                            color: context.colSurface2,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: context.colTextMuted,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ── Remove button ──────────────
                    Positioned(
                      top: 4,
                      right: 14,
                      child: GestureDetector(
                        // Pass the stored value (filename), not the
                        // resolved absolute path — callers store filenames
                        // and use List.remove() to find the entry.
                        onTap: () => onPhotoRemoved(photoPaths[i]),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                    // ── Markup button ───────────────
                    if (onPhotoReplaced != null)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: GestureDetector(
                          onTap: () => _openMarkup(context, photoPaths[i]),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.black, size: 14),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
