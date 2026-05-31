import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PhotoMarkupScreen
//
// Full-screen photo annotation editor. Supports:
//   • Freehand pen
//   • Arrow (drag start → end)
//   • Circle/oval (drag to define bounding box)
//   • Text label (tap to place)
//
// Returns the bare filename of the saved annotated image via Navigator.pop().
// ─────────────────────────────────────────────────────────────────────────────

// ── Tool enum ─────────────────────────────────────────────────────────────────

enum _Tool {
  pen,
  arrow,
  circle,
  text;

  String get label {
    switch (this) {
      case _Tool.pen:
        return 'Pen';
      case _Tool.arrow:
        return 'Arrow';
      case _Tool.circle:
        return 'Circle';
      case _Tool.text:
        return 'Text';
    }
  }

  IconData get icon {
    switch (this) {
      case _Tool.pen:
        return Icons.edit_rounded;
      case _Tool.arrow:
        return Icons.arrow_forward_rounded;
      case _Tool.circle:
        return Icons.circle_outlined;
      case _Tool.text:
        return Icons.text_fields_rounded;
    }
  }
}

// ── Stroke model ──────────────────────────────────────────────────────────────

sealed class _Stroke {
  final Color color;
  final double width;
  const _Stroke({required this.color, required this.width});
}

final class _FreehandStroke extends _Stroke {
  final List<Offset> points;
  const _FreehandStroke({
    required this.points,
    required super.color,
    required super.width,
  });
}

final class _ArrowStroke extends _Stroke {
  final Offset start;
  final Offset end;
  const _ArrowStroke({
    required this.start,
    required this.end,
    required super.color,
    required super.width,
  });
}

final class _CircleStroke extends _Stroke {
  final Offset center;
  final double rx;
  final double ry;
  const _CircleStroke({
    required this.center,
    required this.rx,
    required this.ry,
    required super.color,
    required super.width,
  });
}

final class _TextStroke extends _Stroke {
  final Offset position;
  final String text;
  const _TextStroke({
    required this.position,
    required this.text,
    required super.color,
  }) : super(width: 0);
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _MarkupPainter extends CustomPainter {
  final ui.Image? photo;
  final List<_Stroke> committed;
  final _Stroke? active;

  const _MarkupPainter({
    this.photo,
    required this.committed,
    this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Draw photo ──────────────────────────────
    if (photo != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: photo!,
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );
    }

    // ── Draw strokes ────────────────────────────
    for (final stroke in [...committed, if (active != null) active!]) {
      _drawStroke(canvas, stroke);
    }
  }

  void _drawStroke(Canvas canvas, _Stroke stroke) {
    switch (stroke) {
      case _FreehandStroke(:final points, :final color, :final width):
        if (points.length < 2) return;
        final paint = _strokePaint(color, width);
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (var i = 1; i < points.length; i++) {
          // Smooth with quadratic bezier through midpoints
          if (i == points.length - 1) {
            path.lineTo(points[i].dx, points[i].dy);
          } else {
            final mid = Offset(
              (points[i].dx + points[i - 1].dx) / 2,
              (points[i].dy + points[i - 1].dy) / 2,
            );
            path.quadraticBezierTo(
                points[i - 1].dx, points[i - 1].dy, mid.dx, mid.dy);
          }
        }
        canvas.drawPath(path, paint);

      case _ArrowStroke(:final start, :final end, :final color, :final width):
        final paint = _strokePaint(color, width);
        canvas.drawLine(start, end, paint);
        _drawArrowHead(canvas, start, end, color, width);

      case _CircleStroke(:final center, :final rx, :final ry, :final color, :final width):
        canvas.drawOval(
          Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
          _strokePaint(color, width),
        );

      case _TextStroke(:final position, :final text, :final color):
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              shadows: const [
                Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1)),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 300);
        // Pill background for readability
        final bg = Rect.fromLTWH(
          position.dx - 4,
          position.dy - 2,
          tp.width + 8,
          tp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bg, const Radius.circular(4)),
          Paint()..color = Colors.black.withValues(alpha: 0.45),
        );
        tp.paint(canvas, position);
    }
  }

  Paint _strokePaint(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  void _drawArrowHead(
      Canvas canvas, Offset start, Offset end, Color color, double width) {
    final vec = end - start;
    final len = vec.distance;
    if (len < 8) return;

    final unit = vec / len;
    final perp = Offset(-unit.dy, unit.dx);
    final headSize = math.max(10.0, width * 4.5);

    final tip = end;
    final b1 = end - unit * headSize + perp * headSize * 0.55;
    final b2 = end - unit * headSize - perp * headSize * 0.55;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(b1.dx, b1.dy)
      ..lineTo(b2.dx, b2.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_MarkupPainter old) =>
      old.photo != photo ||
      old.committed != committed ||
      old.active != active;
}

// ── Main screen ───────────────────────────────────────────────────────────────

class PhotoMarkupScreen extends StatefulWidget {
  /// Resolved absolute path to the source photo.
  final String photoPath;

  const PhotoMarkupScreen({super.key, required this.photoPath});

  @override
  State<PhotoMarkupScreen> createState() => _PhotoMarkupScreenState();
}

class _PhotoMarkupScreenState extends State<PhotoMarkupScreen> {
  // Photo loading
  ui.Image? _photo;
  bool _loading = true;

  // Drawing state
  _Tool _tool = _Tool.pen;
  Color _color = AppColors.danger;
  double _strokeWidth = 4.0;

  final List<_Stroke> _committed = [];
  _Stroke? _active;
  Offset? _dragStart;
  List<Offset> _penPoints = [];

  // For saving
  final _repaintKey = GlobalKey();
  bool _saving = false;

  // Palette
  static const _palette = [
    AppColors.danger,
    Color(0xFFFFD166), // bright yellow
    Colors.white,
    AppColors.growing,
    Color(0xFF74B9FF), // sky blue
  ];

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _photo?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      final codec =
          await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _photo = frame.image;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Gesture handlers ─────────────────────────────

  void _onPanStart(DragStartDetails d) {
    final pos = d.localPosition;
    setState(() {
      _dragStart = pos;
      switch (_tool) {
        case _Tool.pen:
          _penPoints = [pos];
          _active = _FreehandStroke(
              points: [pos], color: _color, width: _strokeWidth);
        case _Tool.arrow:
          _active = _ArrowStroke(
              start: pos, end: pos, color: _color, width: _strokeWidth);
        case _Tool.circle:
          _active = _CircleStroke(
              center: pos, rx: 0, ry: 0, color: _color, width: _strokeWidth);
        case _Tool.text:
          break; // handled in onTapUp
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final pos = d.localPosition;
    setState(() {
      switch (_tool) {
        case _Tool.pen:
          _penPoints = [..._penPoints, pos];
          _active = _FreehandStroke(
              points: _penPoints, color: _color, width: _strokeWidth);
        case _Tool.arrow:
          _active = _ArrowStroke(
              start: _dragStart!, end: pos, color: _color, width: _strokeWidth);
        case _Tool.circle:
          final dx = (pos.dx - _dragStart!.dx).abs();
          final dy = (pos.dy - _dragStart!.dy).abs();
          final center = Offset(
            (_dragStart!.dx + pos.dx) / 2,
            (_dragStart!.dy + pos.dy) / 2,
          );
          _active = _CircleStroke(
              center: center,
              rx: dx / 2,
              ry: dy / 2,
              color: _color,
              width: _strokeWidth);
        case _Tool.text:
          break;
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_active != null) {
      setState(() {
        _committed.add(_active!);
        _active = null;
        _penPoints = [];
        _dragStart = null;
      });
    }
  }

  void _onTapUp(TapUpDetails d) {
    if (_tool != _Tool.text) return;
    final pos = d.localPosition;
    _showTextInputDialog(pos);
  }

  Future<void> _showTextInputDialog(Offset position) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colSurface2,
        title: Text('Add label', style: AppTypography.headlineSmall(ctx)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: ctx.colTextPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. Pest damage, Ca deficiency…',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Place'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _committed.add(
            _TextStroke(position: position, text: result.trim(), color: _color),
          ));
    }
  }

  void _undo() {
    if (_committed.isNotEmpty) setState(() => _committed.removeLast());
  }

  void _clear() {
    setState(() {
      _committed.clear();
      _active = null;
    });
  }

  // ── Save ─────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_markup.png';
      final file = File(p.join(dir.path, name));
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) Navigator.pop(context, p.basename(file.path));
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              tool: _tool,
              onToolChanged: (t) => setState(() => _tool = t),
              onSave: _saving ? null : _save,
              saving: _saving,
              canUndo: _committed.isNotEmpty,
              onUndo: _undo,
              onClear: _committed.isNotEmpty ? _clear : null,
            ),
            // ── Canvas ────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : GestureDetector(
                      onPanStart: _tool != _Tool.text ? _onPanStart : null,
                      onPanUpdate: _tool != _Tool.text ? _onPanUpdate : null,
                      onPanEnd: _tool != _Tool.text ? _onPanEnd : null,
                      onTapUp: _tool == _Tool.text ? _onTapUp : null,
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: CustomPaint(
                          painter: _MarkupPainter(
                            photo: _photo,
                            committed: _committed,
                            active: _active,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
            ),
            // ── Bottom toolbar ────────────────────
            _BottomBar(
              palette: _palette,
              selectedColor: _color,
              strokeWidth: _strokeWidth,
              onColorChanged: (c) => setState(() => _color = c),
              onStrokeWidthChanged: (w) => setState(() => _strokeWidth = w),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top toolbar ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final _Tool tool;
  final void Function(_Tool) onToolChanged;
  final VoidCallback? onSave;
  final bool saving;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback? onClear;

  const _TopBar({
    required this.tool,
    required this.onToolChanged,
    required this.onSave,
    required this.saving,
    required this.canUndo,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          // Close
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Discard',
            onPressed: () => Navigator.pop(context),
          ),

          // Tool chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _Tool.values.map((t) {
                  final sel = t == tool;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xxs),
                    child: GestureDetector(
                      onTap: () => onToolChanged(t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.icon,
                                size: 14,
                                color: sel ? Colors.black : Colors.white),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.black : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Undo
          IconButton(
            icon: Icon(Icons.undo_rounded,
                color: canUndo
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3)),
            tooltip: 'Undo',
            onPressed: canUndo ? onUndo : null,
          ),

          // Clear all
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: AppColors.danger),
              tooltip: 'Clear all',
              onPressed: onClear,
            ),

          // Done / Save
          GestureDetector(
            onTap: onSave,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: onSave != null
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom toolbar ────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final List<Color> palette;
  final Color selectedColor;
  final double strokeWidth;
  final void Function(Color) onColorChanged;
  final void Function(double) onStrokeWidthChanged;

  const _BottomBar({
    required this.palette,
    required this.selectedColor,
    required this.strokeWidth,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          // ── Colour swatches ──────────────────────
          ...palette.map(
            (c) => GestureDetector(
              onTap: () => onColorChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: selectedColor == c ? 34 : 28,
                height: selectedColor == c ? 34 : 28,
                margin: const EdgeInsets.only(right: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == c
                        ? Colors.white
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selectedColor == c
                      ? [
                          BoxShadow(
                              color: c.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
              ),
            ),
          ),

          const Spacer(),

          // ── Stroke width ─────────────────────────
          _StrokeButton(
              size: 2,
              selected: strokeWidth == 2,
              color: selectedColor,
              onTap: () => onStrokeWidthChanged(2)),
          const SizedBox(width: AppSpacing.xs),
          _StrokeButton(
              size: 4,
              selected: strokeWidth == 4,
              color: selectedColor,
              onTap: () => onStrokeWidthChanged(4)),
          const SizedBox(width: AppSpacing.xs),
          _StrokeButton(
              size: 7,
              selected: strokeWidth == 7,
              color: selectedColor,
              onTap: () => onStrokeWidthChanged(7)),
        ],
      ),
    );
  }
}

class _StrokeButton extends StatelessWidget {
  final double size;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StrokeButton({
    required this.size,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Container(
          width: size + 8,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size / 2),
          ),
        ),
      ),
    );
  }
}
