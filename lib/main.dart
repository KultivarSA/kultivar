import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_spacing.dart';
import 'config/supabase_config.dart';
import 'l10n/app_localizations.dart';
import 'repository/grow_repository.dart';
import 'screens/app_lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/analytics_service.dart';
import 'services/app_lock_service.dart';
import 'services/auto_backup_service.dart';
import 'services/currency_service.dart';
import 'services/hive_service.dart';
import 'services/local_crash_log.dart';
import 'services/notification_service.dart';
import 'services/onboarding_service.dart';
import 'services/review_prompt_service.dart';
import 'services/search_state_service.dart';
import 'services/sentry_bootstrap.dart';
import 'services/subscription_service.dart';
import 'services/telemetry_consent_service.dart';
import 'services/ui_preferences_service.dart';
import 'services/widget_update_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'utils/photo_path_resolver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bug fix v5 (real-device crash hunt):  install the local crash
  // logger BEFORE any other initialisation so a startup-time crash
  // still leaves a trace on disk.  The logger writes to a 64 KB
  // rolling file in the app's documents directory and never sends
  // anything off-device; the user opts in to share it via the
  // Settings → "Share Diagnostics" tile.  Lives alongside (not
  // instead of) the Sentry path -- Sentry stays gated on DSN +
  // consent; this captures every build, regardless of network.
  await LocalCrashLog.install();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // P1.5 — Explicit image-cache caps.
  //
  // Flutter's default ImageCache is 100 MB / 1000 entries.  After
  // P1.4 (decode-cap on every thumbnail) our average tile decodes to
  // ~150 KB, so a budget of ~200 MB keeps roughly 1,300 thumbnails
  // warm at once.  That's enough for an enthusiast user with several
  // active plants and a long photo timeline to scroll without hot
  // tiles getting evicted and re-decoded.
  //
  // The entry-count cap (2000) is raised in lockstep — without it,
  // the cache would evict by count long before the byte budget kicks
  // in for our small-thumbnail workload.
  //
  // These limits are deliberately *modest* by mobile standards.
  // Going much higher (say 500 MB) would risk crowding out other
  // app caches (Hive, Supabase HTTP, fonts) under memory pressure
  // and increase the chance of an iOS jetsam termination.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200 MB
  PaintingBinding.instance.imageCache.maximumSize = 2000;

  // ✅ Init Hive before anything else
  await HiveService.init();

  // ── Supabase (community layer) ─────────────────────────────────────────
  // Initialised once at startup when credentials were provided at build
  // time via --dart-define=SUPABASE_URL / --dart-define=SUPABASE_ANON_KEY.
  // When unconfigured the app runs normally — CommunityService short-
  // circuits to null/false, matching the offline-mode behaviour.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  // Cache the app documents directory path so PhotoPathResolver.resolve()
  // can be called synchronously from widgets.
  if (!kIsWeb) await PhotoPathResolver.init();

  // ── RevenueCat (freemium subscriptions) ───────────────────────────────────
  // Initialised early so Pro status is available on the first frame.
  // Fails silently when API keys are still placeholders or when offline.
  final subscriptionService = SubscriptionService();
  await subscriptionService.init();

  // ── Currency (settings-driven, applied to all expense displays) ───────────
  // Loaded before runApp so the very first frame shows the user's chosen
  // symbol — no '£' flash for users on '€' / '$' / etc.
  final currencyService = CurrencyService();
  await currencyService.init();

  if (!kIsWeb) {
    await NotificationService().initialize();
    // Request Android 13+ POST_NOTIFICATIONS runtime permission.
    // No-op on iOS (handled via DarwinInitializationSettings) and Android < 13.
    await NotificationService().requestAndroidPermission();
  }

  // ── SR6 — Telemetry consent ───────────────────────────────────────────────
  //
  // Loaded BEFORE the Sentry bootstrap so we know the user's stance
  // by the time we decide whether to init the SDK.  Privacy-first
  // default: a fresh install reports state == notAsked, which gates
  // Sentry off until the user explicitly grants consent via the
  // first-launch sheet (shell_screen) or the Settings toggle.
  final telemetryConsentService = TelemetryConsentService();
  await telemetryConsentService.init();

  // Task #87 — Record first-launch date once.  Cheap on every boot;
  // does nothing if already set.  The review prompt service uses
  // this to enforce its ≥ 7-day "settle in" window before any
  // automatic prompt fires.
  await ReviewPromptService.recordFirstLaunchIfMissing();

  // ── Q12 + SR6 — Sentry wiring ─────────────────────────────────────────────
  //
  // `bootstrapSentryAndRun` is a no-op when EITHER:
  //   • SENTRY_DSN wasn't provided at build time, OR
  //   • the user hasn't granted telemetry consent.
  //
  // In both cases the appRunner runs immediately and ErrorReporter
  // stays on its debug-only sink — no network egress, no SDK side
  // effects.  When BOTH are true:
  //   • SentryFlutter.init wraps `runApp` so unhandled framework
  //     errors are captured automatically.
  //   • Every existing `ErrorReporter.report(...)` callsite forwards
  //     through to Sentry without any further code changes.
  await bootstrapSentryAndRun(
    consentGranted: telemetryConsentService.hasGranted,
    appRunner: () => runApp(KultivarApp(
      subscriptionService: subscriptionService,
      currencyService: currencyService,
      telemetryConsentService: telemetryConsentService,
    )),
  );
}

class KultivarApp extends StatefulWidget {
  final SubscriptionService subscriptionService;
  final CurrencyService currencyService;
  final TelemetryConsentService telemetryConsentService;

  const KultivarApp({
    super.key,
    required this.subscriptionService,
    required this.currencyService,
    required this.telemetryConsentService,
  });

  // ✅ Global theme notifier accessible from anywhere
  // Starts with system default; overridden by persisted preference in _AppEntryState._check().
  static final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  // ✅ Global temperature-unit notifier (false = °C, true = °F)
  static final useFahrenheitNotifier = ValueNotifier<bool>(false);

  // F11 — Global locale notifier.  `null` means "follow the OS / system
  // locale" (Flutter then picks the best match from supportedLocales).
  // Non-null forces a specific locale regardless of system settings.
  // Loaded from UiPreferencesService on startup.
  static final localeNotifier = ValueNotifier<Locale?>(null);

  // ✅ Notification preference notifiers — loaded from SharedPreferences at startup
  static final notifDryingEnabled         = ValueNotifier<bool>(true);
  static final notifCuringEnabled         = ValueNotifier<bool>(true);
  static final notifBurpingEnabled        = ValueNotifier<bool>(true);
  static final notifEnvAlertsEnabled      = ValueNotifier<bool>(true);
  static final notifWateringEnabled       = ValueNotifier<bool>(true);
  static final notifFeedingEnabled        = ValueNotifier<bool>(true);
  static final notifIpmEnabled            = ValueNotifier<bool>(true);
  /// Whether to fire 7-day and 1-day-before reminders for target harvest dates.
  static final notifTargetHarvestEnabled  = ValueNotifier<bool>(true);

  // ✅ Demo mode — true when running with seeded sample data.
  static final isDemoModeNotifier = ValueNotifier<bool>(false);

  // ✅ App lock — true while the current session has been authenticated.
  // Reset to false when the app goes to background.
  static bool sessionUnlocked = false;

  @override
  State<KultivarApp> createState() => _KultivarAppState();
}

class _KultivarAppState extends State<KultivarApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // `lazy: false` so the repo starts loading immediately at app
        // launch rather than on the first `context.read<GrowRepository>()`
        // — which, before this change, didn't happen until the user
        // tapped a button inside the onboarding wizard.  Combined with
        // the in-memory-writes guard inside [GrowRepository.load], this
        // closes the race that could orphan the first plant created
        // during onboarding.
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => GrowRepository()..load(),
        ),
        ProxyProvider<GrowRepository, AnalyticsService>(
          update: (_, repo, __) => AnalyticsService(repo),
        ),
        // SubscriptionService is pre-initialised in main() so Pro status is
        // available immediately on the first frame.
        ChangeNotifierProvider<SubscriptionService>.value(
          value: widget.subscriptionService,
        ),
        // CurrencyService is pre-initialised so the first frame already shows
        // the user's chosen symbol.
        ChangeNotifierProvider<CurrencyService>.value(
          value: widget.currencyService,
        ),
        // SR6 — Telemetry consent.  Pre-initialised so the Sentry gate
        // already had the user's stance before this MultiProvider built;
        // provided here so the first-launch consent sheet (shell_screen)
        // and the Settings → Privacy toggle can drive grant() / decline().
        ChangeNotifierProvider<TelemetryConsentService>.value(
          value: widget.telemetryConsentService,
        ),
        // Lightweight in-memory holder for the Search tab's last query
        // and filter — survives pop/push but resets with the app process.
        ChangeNotifierProvider<SearchStateService>(
          create: (_) => SearchStateService(),
        ),
      ],
      // F11 — nested ValueListenableBuilders: theme + locale.  When
      // either changes, MaterialApp rebuilds with the new value and
      // every descendant that called `AppLocalizations.of(context)`
      // re-resolves automatically.  No app restart required.
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: KultivarApp.themeNotifier,
        builder: (_, mode, __) => ValueListenableBuilder<Locale?>(
          valueListenable: KultivarApp.localeNotifier,
          builder: (_, locale, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Kultivar',
            theme: AppTheme.light, // ✅ actual light theme
            darkTheme: AppTheme.dark,
            themeMode: mode,
            // null = follow system; otherwise force the chosen locale.
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const _AppEntry(),
          ),
        ),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> with WidgetsBindingObserver {
  bool? _onboardingDone;
  bool _lockEnabled = false;
  bool _showingLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Lock the session whenever the app goes to background.
      KultivarApp.sessionUnlocked = false;
    } else if (state == AppLifecycleState.resumed) {
      _checkLockOnResume();
      _triggerAutoBackup();
      _rescheduleStaleEnvAlerts();
      _refreshHomeWidget();
    }
  }

  /// Fire-and-forget auto-backup. Runs after the current frame so the
  /// Provider tree is guaranteed to be available on resume.
  void _triggerAutoBackup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final repo = context.read<GrowRepository>();
      AutoBackupService.maybeAutoBackup(repo);
    });
  }

  /// Pushes the latest env + care summary to the home-screen widget.
  void _refreshHomeWidget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final repo = context.read<GrowRepository>();
      WidgetUpdateService.update(
        spaces: repo.growSpaces,
        envLogs: repo.environmentLogs,
        plants: repo.plants,
        notes: repo.notes,
      );
    });
  }

  /// Re-arms stale-env alerts on every resume so that the 48 h window is
  /// always calculated relative to the *most recent* log rather than a
  /// stale fire-time from when the app was last open.
  ///
  /// Only runs when the env-alerts preference is enabled; no-ops on web.
  void _rescheduleStaleEnvAlerts() {
    if (!KultivarApp.notifEnvAlertsEnabled.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _doRescheduleStaleEnvAlerts(context.read<GrowRepository>());
    });
  }

  /// Loops through all grow spaces and re-schedules a stale-env alert that
  /// fires 48 h after the space's most recent environment log.
  /// Spaces with no logs at all are skipped (nothing to go stale from).
  static void _doRescheduleStaleEnvAlerts(GrowRepository repo) {
    final notif = NotificationService();
    for (final space in repo.growSpaces) {
      final spaceLogs = repo.environmentLogs
          .where((l) => l.growSpaceId == space.id)
          .toList();
      if (spaceLogs.isEmpty) continue;

      spaceLogs.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      final latest = spaceLogs.first;
      final fireAt = latest.recordedAt.add(const Duration(hours: 48));

      notif.scheduleStaleEnvAlert(
        spaceId: space.id,
        spaceName: space.name,
        fireAt: fireAt,
      );
    }
  }

  Future<void> _checkLockOnResume() async {
    if (_showingLock || _onboardingDone != true) return;
    final locked = await AppLockService.isEnabled();
    if (!mounted) return;
    // Keep _lockEnabled in sync so build reflects current pref.
    if (locked != _lockEnabled) setState(() => _lockEnabled = locked);
    if (locked && !KultivarApp.sessionUnlocked) {
      _pushLockScreen();
    }
  }

  void _pushLockScreen() {
    if (_showingLock) return;
    _showingLock = true;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => AppLockScreen(
          onUnlocked: () {
            KultivarApp.sessionUnlocked = true;
            _showingLock = false;
            Navigator.of(context).pop();
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _check() async {
    final results = await Future.wait([
      OnboardingService.isComplete(),                      // [0]
      UiPreferencesService.loadUseFahrenheit(),            // [1]
      UiPreferencesService.loadThemeMode(),                // [2]
      UiPreferencesService.loadNotifDrying(),              // [3]
      UiPreferencesService.loadNotifCuring(),              // [4]
      UiPreferencesService.loadNotifBurping(),             // [5]
      UiPreferencesService.loadEnvAlertsEnabled(),         // [6]
      UiPreferencesService.loadNotifWatering(),            // [7]
      UiPreferencesService.loadNotifFeeding(),             // [8]
      UiPreferencesService.loadNotifIpm(),                 // [9]
      UiPreferencesService.loadIsDemoMode(),               // [10]
      UiPreferencesService.loadNotifTargetHarvest(),       // [11]
      UiPreferencesService.loadLocaleTag(),                // [12]
    ]);
    KultivarApp.useFahrenheitNotifier.value         = results[1] as bool;
    KultivarApp.themeNotifier.value                 = results[2] as ThemeMode;
    KultivarApp.notifDryingEnabled.value            = results[3] as bool;
    KultivarApp.notifCuringEnabled.value            = results[4] as bool;
    KultivarApp.notifBurpingEnabled.value           = results[5] as bool;
    KultivarApp.notifEnvAlertsEnabled.value         = results[6] as bool;
    KultivarApp.notifWateringEnabled.value          = results[7] as bool;
    KultivarApp.notifFeedingEnabled.value           = results[8] as bool;
    KultivarApp.notifIpmEnabled.value               = results[9] as bool;
    KultivarApp.isDemoModeNotifier.value            = results[10] as bool;
    KultivarApp.notifTargetHarvestEnabled.value     = results[11] as bool;
    // F11 — `null` tag means "follow system" so we hand MaterialApp a
    // null locale; otherwise force the saved BCP-47 tag.
    final localeTag = results[12] as String?;
    KultivarApp.localeNotifier.value =
        (localeTag == null) ? null : Locale(localeTag);
    final lockEnabled = await AppLockService.isEnabled();
    if (mounted) {
      setState(() {
        _onboardingDone = results[0] as bool;
        _lockEnabled = lockEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🌿', style: TextStyle(fontSize: 64)),
              SizedBox(height: AppSpacing.md),
              Text(
                'Kultivar',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 28),
              CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      );
    }

    if (!_onboardingDone!) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingDone = true),
      );
    }

    // Show lock screen directly (no Navigator.push) on cold open.
    if (_lockEnabled && !KultivarApp.sessionUnlocked) {
      return AppLockScreen(
        onUnlocked: () => setState(() {
          KultivarApp.sessionUnlocked = true;
        }),
      );
    }

    return const ShellScreen();
  }
}
