import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/error_reporter.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/photo_path_resolver.dart';

/// F7 — Voice-note attachment.
///
/// Self-contained UI:
///  * Record / Stop button (filled circle, red while recording).
///  * Live elapsed-seconds counter capped at [maxSeconds].
///  * Auto-stops at [maxSeconds] so growers can't accidentally produce
///    20-minute clips — the brief "quick check" is the whole point.
///  * List of existing clips with play/pause + delete affordances.
///
/// File storage matches the photo pattern:
///   * Files live under `getApplicationDocumentsDirectory()`.
///   * Only the bare filename is stored on [PlantNote.audioUrls].
///   * [PhotoPathResolver.resolve] reconstructs the full path on read
///     so backups can be restored on any device without breaking links.
///
/// Hidden on web — the `record` package has no web fallback for the
/// codec we use, and grow journaling on web is rare enough that we'd
/// rather hide the entry than ship a broken button.
class VoiceNoteAttachment extends StatefulWidget {
  /// Filenames as stored on the parent model.
  final List<String> audioPaths;
  final void Function(String filename) onAudioAdded;
  final void Function(String filename) onAudioRemoved;

  /// Hard cap on recording length.  Defaults to 30 s — the brief
  /// "30-second voice memo" from the F7 spec.
  final int maxSeconds;

  const VoiceNoteAttachment({
    super.key,
    required this.audioPaths,
    required this.onAudioAdded,
    required this.onAudioRemoved,
    this.maxSeconds = 30,
  });

  @override
  State<VoiceNoteAttachment> createState() => _VoiceNoteAttachmentState();
}

class _VoiceNoteAttachmentState extends State<VoiceNoteAttachment> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  int _elapsedMs = 0;
  bool _recording = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_recording) {
      await _stopAndSave();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    try {
      // record 5.x: hasPermission triggers the OS-level prompt the
      // first time and surfaces denied/restricted on subsequent calls.
      final granted = await _recorder.hasPermission();
      if (!granted) {
        _toast('Microphone permission denied');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final filename =
          '${DateTime.now().millisecondsSinceEpoch}_voice.m4a';
      final path = p.join(dir.path, filename);

      // AAC-LC at 64 kbps — broadcast-quality voice, ~480 KB per 60 s.
      // m4a container is universally supported by audioplayers on iOS,
      // Android, macOS, Windows MF, and Linux GStreamer.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _elapsedMs = 0;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) {
          _ticker?.cancel();
          return;
        }
        setState(() => _elapsedMs += 100);
        // Auto-stop on hitting the cap so we can't run away.
        if (_elapsedMs >= widget.maxSeconds * 1000) {
          _stopAndSave();
        }
      });
    } catch (e, stack) {
      ErrorReporter.report('VoiceNoteAttachment.start', e, stack);
      _toast('Could not start recording');
    }
  }

  Future<void> _stopAndSave() async {
    _ticker?.cancel();
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _elapsedMs = 0;
      });
      if (path == null) return;
      // Discard ultra-short blips so a fat-fingered tap doesn't pollute
      // the timeline with empty clips.
      final file = File(path);
      if (!file.existsSync() || file.statSync().size < 1024) {
        // Clean up the (almost-empty) file before discarding.
        try {
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
        return;
      }
      widget.onAudioAdded(p.basename(path));
    } catch (e, stack) {
      ErrorReporter.report('VoiceNoteAttachment.stop', e, stack);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // Web/desktop platforms without microphone support shouldn't see the
    // entry at all — the user can't act on it.
    if (kIsWeb) return const SizedBox.shrink();

    final seconds = (_elapsedMs / 1000).floor();
    final maxed = seconds >= widget.maxSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Voice notes', style: AppTypography.bodySmall(context)),
            GestureDetector(
              onTap: _toggle,
              child: Row(children: [
                Icon(
                  _recording
                      ? Icons.stop_circle_rounded
                      : Icons.mic_rounded,
                  color:
                      _recording ? AppColors.danger : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  _recording
                      ? '${seconds}s${maxed ? ' (max)' : ''}  ·  Tap to stop'
                      : 'Record',
                  style: AppTypography.bodySmall(context).copyWith(
                      color: _recording
                          ? AppColors.danger
                          : AppColors.primary),
                ),
              ]),
            ),
          ],
        ),
        if (_recording)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(
              value: (_elapsedMs / (widget.maxSeconds * 1000)).clamp(0, 1),
              backgroundColor: context.colSurface3,
              valueColor: AlwaysStoppedAnimation(
                  maxed ? AppColors.warning : AppColors.danger),
              minHeight: 3,
            ),
          ),
        if (widget.audioPaths.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          ...widget.audioPaths.map(
            (filename) => _VoiceNoteRow(
              filename: filename,
              onDelete: () => widget.onAudioRemoved(filename),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Playback row ──────────────────────────────────────────────────────────────

/// Standalone playback widget for a single audio clip.  Manages its
/// own `AudioPlayer` so multiple rows can sit side-by-side without
/// trampling each other's state.
class _VoiceNoteRow extends StatefulWidget {
  final String filename;
  final VoidCallback? onDelete;

  const _VoiceNoteRow({
    required this.filename,
    this.onDelete,
  });

  @override
  State<_VoiceNoteRow> createState() => _VoiceNoteRowState();
}

class _VoiceNoteRowState extends State<_VoiceNoteRow> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration? _total;
  Duration _position = Duration.zero;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<Duration>? _posSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _total = d);
    });
    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      // Resolve the bare filename to an absolute path at play time —
      // same pattern as PhotoAttachmentPicker.  This makes the stored
      // filename portable across devices and reinstalls.
      final path = PhotoPathResolver.resolve(widget.filename);
      // audioplayers 6.x: DeviceFileSource for local paths.
      await _player.play(DeviceFileSource(path));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_total != null && _total!.inMilliseconds > 0)
        ? _position.inMilliseconds / _total!.inMilliseconds
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: context.colSurface2,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colBorderFaint),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1).toDouble(),
                      backgroundColor: context.colSurface3,
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _total != null
                        ? '${_fmt(_position)} / ${_fmt(_total!)}'
                        : 'Voice note',
                    style: AppTypography.labelSmall(context)
                        .copyWith(color: context.colTextMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(width: AppSpacing.xxs),
              IconButton(
                tooltip: 'Delete voice note',
                icon: Icon(Icons.close_rounded,
                    size: 16, color: context.colTextMuted),
                onPressed: widget.onDelete,
                // A10 — keep the visual icon small (16 px) so it
                // doesn't dominate the inline voice-note row, but
                // restore IconButton's default minimum constraints
                // (≈ 40 dp with `compact` density) so the tap target
                // satisfies WCAG 2.5.5 / Apple HIG (≥ 44 pt).  The
                // prior `constraints: const BoxConstraints()`
                // collapsed the hit area to roughly 20 × 20 — fine
                // for sighted mouse-pointer users, hostile to anyone
                // on touch.
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Public read-only player ───────────────────────────────────────────────────

/// Read-only voice-note player used inside note rows (without the
/// delete button).  Exported so other screens can render audio
/// attachments without exposing the full attachment editor.
class VoiceNotePlayer extends StatelessWidget {
  final String filename;
  const VoiceNotePlayer({super.key, required this.filename});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    return _VoiceNoteRow(filename: filename);
  }
}
