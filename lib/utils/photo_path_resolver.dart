import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Resolves a stored photo identifier (filename-only or legacy absolute path)
/// to a full filesystem path suitable for [File] / [Image.file].
///
/// ## Why this exists
/// Photos used to be stored as absolute paths, e.g.
///   `/data/user/0/.../files/1717000000_photo.jpg`
/// Absolute paths break when the app is moved or backed-up and restored on a
/// different device because the path prefix changes.
///
/// New photos are stored as bare filenames, e.g. `1717000000_photo.jpg`.
/// This resolver handles both conventions transparently so the UI doesn't need
/// to care about which format a stored entry uses.
///
/// ## Usage
///   1. Call [PhotoPathResolver.init] once at app startup (in `main()`).
///   2. Call [PhotoPathResolver.resolve] synchronously wherever you need a path.
class PhotoPathResolver {
  PhotoPathResolver._();

  static String? _basePath;

  /// Must be called once before [resolve] is used (e.g. in `main()` before
  /// `runApp`).  Caches the application documents directory path.
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _basePath = dir.path;
  }

  /// Converts a stored photo entry to a full path.
  ///
  /// * If [nameOrPath] already looks like an absolute path (contains a path
  ///   separator) it is returned unchanged — legacy compatibility.
  /// * Otherwise the cached base directory is prepended.
  ///
  /// Returns [nameOrPath] unchanged when [init] has not been called yet so the
  /// widget's `errorBuilder` handles the missing file gracefully.
  static String resolve(String nameOrPath) {
    if (nameOrPath.contains(Platform.pathSeparator) ||
        nameOrPath.contains('/')) {
      return nameOrPath; // Legacy absolute path — use as-is.
    }
    if (_basePath == null) return nameOrPath; // init() not called yet.
    return '$_basePath${Platform.pathSeparator}$nameOrPath';
  }

  /// Extracts just the filename from [absolutePath] so it can be stored
  /// in a model without the volatile directory prefix.
  ///
  /// Equivalent to `path.basename(absolutePath)`.
  static String toFilename(String absolutePath) {
    final sep = absolutePath.contains(Platform.pathSeparator)
        ? Platform.pathSeparator
        : '/';
    return absolutePath.split(sep).last;
  }
}
