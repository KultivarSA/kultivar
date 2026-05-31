import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../services/demo_data_service.dart';
import '../services/onboarding_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/strain_autocomplete_field.dart';
import 'paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding screen — 5 pages
//   0: Welcome         (value showcase splash)
//   1: Create Space    (required setup — creates first GrowSpace)
//   2: Add Plant       (optional — creates first Plant, skippable)
//   3: Community intro (anonymous benchmark explainer — informational only)
//   4: Pro Upsell      (skippable paywall intro — shown after community step)
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  bool _loadingDemo = false;

  // ── Step 1: Space ──────────────────────────────
  final _spaceNameCtrl = TextEditingController();
  String _spaceType = 'Indoor Tent';
  String? _createdSpaceId; // set after space is saved

  // ── Step 2: Plant ──────────────────────────────
  final _plantNameCtrl = TextEditingController();
  final _strainCtrl = TextEditingController();
  bool _isAutoflower = false;
  DateTime _plantStartDate = DateTime.now();

  static const _spaceTypes = [
    'Indoor Tent',
    'Flower Room',
    'Veg Room',
    'Greenhouse',
    'Outdoor',
    'Dry Room',
    'Other',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _spaceNameCtrl.dispose();
    _plantNameCtrl.dispose();
    _strainCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────

  void _goTo(int page) {
    setState(() => _page = page);
    _pageCtrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Page 0 → 1: advance to the space setup slide.
  void _onWelcomeNext() => _goTo(1);

  /// Page 1 → 2: space created (or skipped), move to plant setup.
  void _onSpaceNext({bool skip = false}) {
    if (!skip) {
      final name = _spaceNameCtrl.text.trim();
      if (name.isEmpty) return;
      final repo = context.read<GrowRepository>();
      final id = repo.newId();
      repo.addGrowSpace(GrowSpace(id: id, name: name, type: _spaceType));
      _createdSpaceId = id;
    }
    _goTo(2);
  }

  /// Page 2 → 3: save plant (or skip) then navigate to community intro.
  Future<void> _onPlantFinish({bool skip = false}) async {
    if (!skip) {
      final name = _plantNameCtrl.text.trim();
      if (name.isEmpty) return;
      final repo = context.read<GrowRepository>();
      // Plant needs a space — if user skipped step 1 we create a default space.
      final spaceId = _createdSpaceId ?? _ensureDefaultSpace(repo);
      repo.addPlant(Plant(
        id: repo.newId(),
        name: name,
        strain: _strainCtrl.text.trim().isEmpty
            ? 'Unknown'
            : _strainCtrl.text.trim(),
        startDate: _plantStartDate,
        growSpaceId: spaceId,
        isAutoflower: _isAutoflower,
      ));
    }
    // Flush to disk before advancing so the space + plant survive the
    // state transition regardless of how quickly the user taps through.
    await context.read<GrowRepository>().save();

    // Always show the community intro next — it's a quick read and explains
    // the anonymous data feature before the user starts logging grows.
    _goTo(3);
  }

  /// Page 3 → 4: community intro acknowledged.
  void _onCommunityNext() {
    final isPro = context.read<SubscriptionService>().isPro;
    if (isPro) {
      // Pro users skip the upsell page — complete onboarding immediately.
      _onProPageFinish();
    } else {
      _goTo(4);
    }
  }

  /// Page 0 → demo: seed sample data and complete onboarding immediately.
  Future<void> _onTryDemo() async {
    if (_loadingDemo) return;
    setState(() => _loadingDemo = true);
    final repo = context.read<GrowRepository>();
    await DemoDataService.seed(repo);
    KultivarApp.isDemoModeNotifier.value = true;
    widget.onComplete();
  }

  /// Page 4: Pro upsell done (either upgraded or skipped) — complete onboarding.
  Future<void> _onProPageFinish() async {
    await context.read<GrowRepository>().save();
    await OnboardingService.markComplete();
    widget.onComplete();
  }

  String _ensureDefaultSpace(GrowRepository repo) {
    if (repo.growSpaces.isNotEmpty) return repo.growSpaces.first.id;
    final id = repo.newId();
    repo.addGrowSpace(
        GrowSpace(id: id, name: 'My Grow Space', type: 'Indoor Tent'));
    return id;
  }

  // ── Build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Pages 1–2 are the two real setup steps (Space + Plant).
    // Community (page 3) and Pro upsell (page 4) show a back arrow only.
    final stepLabels = [
      l.onboardingProgress(1, 2, l.onboardingSpaceStepLabel),
      l.onboardingProgress(2, 2, l.onboardingPlantStepLabel),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            // • Page 0 (welcome):       no header
            // • Pages 1–2 (setup):      back arrow + segmented progress bar
            // • Pages 3–4 (community,
            //              pro upsell): back arrow only
            if (_page > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding, AppSpacing.md,
                    AppSpacing.pagePadding, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _goTo(_page - 1),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Icon(Icons.arrow_back_rounded,
                            color: context.colTextPrimary, size: 22),
                      ),
                    ),
                    if (_page >= 1 && _page <= 2)
                      Expanded(
                        child: _ProgressBar(
                          current: _page - 1,
                          total: 2,
                          label: stepLabels[_page - 1],
                        ),
                      ),
                  ],
                ),
              ),

            // ── Pages ────────────────────────
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  // 0: Welcome
                  _WelcomePage(
                    onNext: _onWelcomeNext,
                    onDemo: _onTryDemo,
                    loadingDemo: _loadingDemo,
                  ),
                  // 1: Create Space
                  _SpacePage(
                    nameCtrl: _spaceNameCtrl,
                    spaceType: _spaceType,
                    spaceTypes: _spaceTypes,
                    onTypeChanged: (t) => setState(() => _spaceType = t),
                    onNext: _onSpaceNext,
                  ),
                  // 2: Add Plant
                  _PlantPage(
                    nameCtrl: _plantNameCtrl,
                    strainCtrl: _strainCtrl,
                    isAutoflower: _isAutoflower,
                    startDate: _plantStartDate,
                    spaceName: _spaceNameCtrl.text.trim().isEmpty
                        ? null
                        : _spaceNameCtrl.text.trim(),
                    onAutoflowerChanged: (v) =>
                        setState(() => _isAutoflower = v),
                    onStartDateChanged: (d) =>
                        setState(() => _plantStartDate = d),
                    onFinish: _onPlantFinish,
                  ),
                  // 3: Community intro
                  _CommunityPage(
                    onNext: _onCommunityNext,
                  ),
                  // 4: Pro upsell
                  _ProPage(
                    onUpgrade: _onProPageFinish,
                    onSkip: _onProPageFinish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final String? label;

  const _ProgressBar({required this.current, required this.total, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(total, (i) {
            final active = i <= current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : context.colSurface3,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            );
          }),
        ),
        if (label != null) ...[
          const SizedBox(height: 5),
          Text(
            label!,
            style: AppTypography.bodySmall(context).copyWith(
              color: context.colTextMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 0 — Welcome (value showcase)
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  final Future<void> Function() onDemo;
  final bool loadingDemo;

  const _WelcomePage({
    required this.onNext,
    required this.onDemo,
    this.loadingDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),

          // ── Logo ─────────────────────────────
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.growing.withValues(alpha: 0.1),
              border: Border.all(
                  color: AppColors.growing.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.growing.withValues(alpha: 0.2),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child:
                  Icon(Icons.eco_rounded, color: AppColors.growing, size: 48),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            // The app name stays untranslated — same identity across locales.
            AppLocalizations.of(context).appTitle,
            style: AppTypography.displayMedium(context)
                .copyWith(color: AppColors.growing),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).onboardingWelcomeTagline,
            style: AppTypography.bodyLarge(context)
                .copyWith(color: context.colTextMuted),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Feature rows ─────────────────────
          const _FeatureRow(
            icon: Icons.insights_rounded,
            color: AppColors.primary,
            title: 'Yield analytics, per strain',
            example: '"Blue Dream averages 94g · 4.8★ across 6 runs"',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureRow(
            icon: Icons.thermostat_rounded,
            color: AppColors.drying,
            title: 'Environment tracking & VPD',
            example: '"Room A has been out of range for 3 days"',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureRow(
            icon: Icons.event_repeat_rounded,
            color: AppColors.secondary,
            title: 'Space-wide care schedules',
            example: '"Flower Room is due for watering today"',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureRow(
            icon: Icons.archive_rounded,
            color: AppColors.harvested,
            title: 'Harvest archive & grow reports',
            example: '"Your best run: 127g · 91 days from seed"',
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── CTA ──────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(AppLocalizations.of(context).onboardingWelcomeCta),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.growing,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: onNext,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Demo path ────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: loadingDemo ? null : onDemo,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colTextSecondary,
                side: BorderSide(color: context.colBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontSize: 15),
              ),
              child: loadingDemo
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Text(AppLocalizations.of(context).onboardingWelcomeDemo),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).onboardingWelcomeDemoCaption,
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String example;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.labelLarge(context)
                        .copyWith(fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  example,
                  style: AppTypography.bodySmall(context).copyWith(
                    color: color.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 — Community intro (informational — no consent prompt here)
// ─────────────────────────────────────────────────────────────────────────────

class _CommunityPage extends StatelessWidget {
  final VoidCallback onNext;

  const _CommunityPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),

          // ── Icon ─────────────────────────────
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.12),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.people_rounded,
                  color: AppColors.secondary, size: 40),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            AppLocalizations.of(context).onboardingCommunityTitle,
            style: AppTypography.displayMedium(context)
                .copyWith(color: AppColors.secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).onboardingCommunityBody,
            style: AppTypography.bodyMedium(context),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Three value propositions ──────────
          const _FeatureRow(
            icon: Icons.lock_rounded,
            color: AppColors.primary,
            title: 'Fully anonymous',
            example: 'No user ID, no IP address, no account ever required',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureRow(
            icon: Icons.insights_rounded,
            color: AppColors.secondary,
            title: 'Your yield in context',
            example:
                '"Your Blue Dream ranked top 25% across 48 community grows"',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureRow(
            icon: Icons.groups_rounded,
            color: AppColors.growing,
            title: 'Safety in numbers',
            example:
                'Data only surfaces after 5+ different growers submit — '
                'individual grows are never shown',
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Fine print ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colSurface2,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: context.colBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: context.colTextMuted, size: 14),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "You'll be asked to share after each harvest. "
                    'You can change this anytime in Settings → Community.',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: context.colTextMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── CTA ──────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(AppLocalizations.of(context).onboardingCommunityCta),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: onNext,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — Create your first grow space
// ─────────────────────────────────────────────────────────────────────────────

class _SpacePage extends StatefulWidget {
  final TextEditingController nameCtrl;
  final String spaceType;
  final List<String> spaceTypes;
  final ValueChanged<String> onTypeChanged;
  final void Function({bool skip}) onNext;

  const _SpacePage({
    required this.nameCtrl,
    required this.spaceType,
    required this.spaceTypes,
    required this.onTypeChanged,
    required this.onNext,
  });

  @override
  State<_SpacePage> createState() => _SpacePageState();
}

class _SpacePageState extends State<_SpacePage> {
  bool _hasName = false;

  @override
  void initState() {
    super.initState();
    widget.nameCtrl.addListener(_onNameChange);
  }

  @override
  void dispose() {
    widget.nameCtrl.removeListener(_onNameChange);
    super.dispose();
  }

  void _onNameChange() {
    final has = widget.nameCtrl.text.trim().isNotEmpty;
    if (has != _hasName) setState(() => _hasName = has);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),

          // ── Header ───────────────────────
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.12),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.add_home_work_rounded,
                    color: AppColors.secondary, size: 40),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppLocalizations.of(context).onboardingSpaceTitle,
            style: AppTypography.displayMedium(context)
                .copyWith(color: AppColors.secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              AppLocalizations.of(context).onboardingSpaceBody,
              style: AppTypography.bodyMedium(context),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Name ─────────────────────────
          TextField(
            controller: widget.nameCtrl,
            autofocus: false,
            style: TextStyle(color: context.colTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Space Name *',
              hintText: 'e.g. Veg Tent, Flower Room…',
              prefixIcon: Icon(Icons.label_rounded, size: 18),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Type chips ───────────────────
          Text('Type',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.spaceTypes.map((t) {
              final selected = widget.spaceType == t;
              return ChoiceChip(
                label: Text(t),
                selected: selected,
                selectedColor: AppColors.secondary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.black : context.colTextSecondary,
                ),
                onSelected: (_) => widget.onTypeChanged(t),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── CTA ──────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(AppLocalizations.of(context).onboardingSpaceCta),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _hasName ? AppColors.secondary : context.colSurface3,
                foregroundColor:
                    _hasName ? Colors.black : context.colTextMuted,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: _hasName ? () => widget.onNext() : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => widget.onNext(skip: true),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
              child: Text(
                AppLocalizations.of(context).onboardingSkip,
                style: AppTypography.labelLarge(context)
                    .copyWith(color: context.colTextMuted, fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 — Add your first plant (optional)
// ─────────────────────────────────────────────────────────────────────────────

class _PlantPage extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController strainCtrl;
  final bool isAutoflower;
  final DateTime startDate;
  /// Name of the space created in the previous step (null if skipped).
  final String? spaceName;
  final ValueChanged<bool> onAutoflowerChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final Future<void> Function({bool skip}) onFinish;

  const _PlantPage({
    required this.nameCtrl,
    required this.strainCtrl,
    required this.isAutoflower,
    required this.startDate,
    this.spaceName,
    required this.onAutoflowerChanged,
    required this.onStartDateChanged,
    required this.onFinish,
  });

  @override
  State<_PlantPage> createState() => _PlantPageState();
}

class _PlantPageState extends State<_PlantPage> {
  bool _hasName = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.nameCtrl.addListener(_onNameChange);
  }

  @override
  void dispose() {
    widget.nameCtrl.removeListener(_onNameChange);
    super.dispose();
  }

  void _onNameChange() {
    final has = widget.nameCtrl.text.trim().isNotEmpty;
    if (has != _hasName) setState(() => _hasName = has);
  }

  Future<void> _finish({bool skip = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    await widget.onFinish(skip: skip);
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),

          // ── Header ───────────────────────
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.growing.withValues(alpha: 0.12),
                border: Border.all(
                    color: AppColors.growing.withValues(alpha: 0.3),
                    width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.eco_rounded,
                    color: AppColors.growing, size: 40),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppLocalizations.of(context).onboardingPlantTitle,
            style: AppTypography.displayMedium(context)
                .copyWith(color: AppColors.growing),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              AppLocalizations.of(context).onboardingPlantBody,
              style: AppTypography.bodyMedium(context),
              textAlign: TextAlign.center,
            ),
          ),

          // ── Space indicator ──────────────
          if (widget.spaceName != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.add_home_work_rounded,
                    color: AppColors.secondary, size: 15),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppLocalizations.of(context)
                      .onboardingPlantAddingTo(widget.spaceName!),
                  style: AppTypography.bodySmall(context).copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // ── Plant name ───────────────────
          TextField(
            controller: widget.nameCtrl,
            style: TextStyle(color: context.colTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Plant Name *',
              hintText: 'e.g. Plant #1, Northern Lights…',
              prefixIcon: Icon(Icons.eco_rounded, size: 18),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Strain autocomplete ──────────
          StrainAutocompleteField(
            initialValue: widget.strainCtrl.text,
            onTextChanged: (v) => widget.strainCtrl.text = v,
            onStrainSelected: (strain) {
              widget.strainCtrl.text = strain.name;
              // Auto-toggle genetics when user picks a known auto strain.
              if (strain.isAutoflower) widget.onAutoflowerChanged(true);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Genetics ─────────────────────
          Text(AppLocalizations.of(context).onboardingPlantGenetics,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted)),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            _GeneticsChip(
              label: AppLocalizations.of(context).onboardingPlantPhotoperiod,
              selected: !widget.isAutoflower,
              color: AppColors.growing,
              onTap: () => widget.onAutoflowerChanged(false),
            ),
            const SizedBox(width: AppSpacing.sm),
            _GeneticsChip(
              label: AppLocalizations.of(context).onboardingPlantAutoflower,
              selected: widget.isAutoflower,
              color: AppColors.drying,
              onTap: () => widget.onAutoflowerChanged(true),
            ),
          ]),

          const SizedBox(height: AppSpacing.md),

          // ── Start date ───────────────────
          Text(AppLocalizations.of(context).onboardingPlantStartDate,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted)),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.startDate,
                firstDate:
                    DateTime.now().subtract(const Duration(days: 365 * 5)),
                lastDate: DateTime.now(),
              );
              if (picked != null) widget.onStartDateChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colSurface2,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: context.colBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _isToday(widget.startDate)
                          ? AppLocalizations.of(context).onboardingPlantStartToday
                          : _formatDate(widget.startDate),
                      style: AppTypography.bodyMedium(context)
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                  Text(
                    _isToday(widget.startDate)
                        ? AppLocalizations.of(context)
                            .onboardingPlantStartTapChange
                        : AppLocalizations.of(context)
                            .onboardingPlantStartDaysAgo(
                                DateTime.now()
                                    .difference(widget.startDate)
                                    .inDays),
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── CTA ──────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(AppLocalizations.of(context).onboardingPlantCta),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _hasName ? AppColors.growing : context.colSurface3,
                foregroundColor:
                    _hasName ? Colors.black : context.colTextMuted,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: (_hasName && !_loading) ? _finish : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _loading ? null : () => _finish(skip: true),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
              child: Text(
                AppLocalizations.of(context).onboardingSkip,
                style: AppTypography.labelLarge(context)
                    .copyWith(color: context.colTextMuted, fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 4 — Pro upsell (skippable)
// ─────────────────────────────────────────────────────────────────────────────

class _ProPage extends StatefulWidget {
  final VoidCallback onUpgrade; // called after a successful purchase
  final VoidCallback onSkip;    // called when the user taps "Maybe Later"

  const _ProPage({required this.onUpgrade, required this.onSkip});

  @override
  State<_ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<_ProPage> {
  Future<void> _openPaywall() async {
    final upgraded = await PaywallScreen.show(context);
    if (!mounted) return;
    if (upgraded) {
      widget.onUpgrade();
    }
    // If they close without buying we stay on this page — they can still skip.
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),

          // ── Crown icon ────────────────────────────────────────────────
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradientAmber,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.workspace_premium_rounded,
                  color: Colors.black, size: 44),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            AppLocalizations.of(context).onboardingProTitle,
            style: AppTypography.displayMedium(context).copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).onboardingProBody,
            style: AppTypography.bodyMedium(context)
                .copyWith(color: context.colTextSecondary),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Benefit rows ──────────────────────────────────────────────
          const _ProBenefit(
            icon: Icons.home_work_rounded,
            color: AppColors.secondary,
            title: 'Unlimited Spaces & Plants',
            body: 'Scale your operation without restriction.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ProBenefit(
            icon: Icons.bar_chart_rounded,
            color: AppColors.primary,
            title: 'Full Analytics History',
            body: 'Track every run, ever. Not just the last 60 days.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ProBenefit(
            icon: Icons.compare_arrows_rounded,
            color: AppColors.drying,
            title: 'Strain Compare + Full Profiles',
            body: 'Side-by-side VPD targets, feeding, terpenes, and more.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ProBenefit(
            icon: Icons.picture_as_pdf_rounded,
            color: AppColors.harvested,
            title: 'Export & Share Reports',
            body: 'PDF and CSV exports for every grow.',
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Pricing hint ──────────────────────────────────────────────
          //
          // Two anchor prices — Pro Cloud annual (low recurring) and
          // Lifetime Local (no recurring at all).  Mirrors the two
          // headline tiers on the full paywall so the upsell tap
          // doesn't feel like a surprise jump in price tiers.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.accent, size: 14),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Pro Cloud from \$2.50 / month',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'or own it forever — Lifetime Local \$49.99',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: context.colTextMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── CTA ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text(AppLocalizations.of(context).onboardingProCta),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
                shadowColor: AppColors.accent.withValues(alpha: 0.4),
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: _openPaywall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Skip ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: widget.onSkip,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
              child: Text(
                AppLocalizations.of(context).onboardingProSkip,
                style: AppTypography.labelLarge(context)
                    .copyWith(color: context.colTextMuted, fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ProBenefit extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _ProBenefit({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge(context).copyWith(
                    fontSize: 13,
                    color: context.colTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: AppTypography.bodySmall(context).copyWith(
                    color: context.colTextMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Genetics choice chip (page 2)
// ─────────────────────────────────────────────────────────────────────────────

class _GeneticsChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _GeneticsChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : context.colSurface2,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected ? color : context.colBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge(context).copyWith(
            color: selected ? color : context.colTextSecondary,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
