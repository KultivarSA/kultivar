import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/subscription_tier_config.dart';
import '../l10n/app_localizations.dart';
import '../legal/privacy_policy.dart';
import '../legal/terms_of_service.dart';
import '../main.dart';
import '../repository/grow_repository.dart';
import '../services/app_lock_service.dart';
import '../services/auto_backup_service.dart';
import '../services/backup_encryption_service.dart';
import '../services/currency_service.dart';
import '../services/demo_data_service.dart';
import '../services/local_crash_log.dart';
import '../services/notification_service.dart';
import '../services/onboarding_service.dart';
import '../services/review_prompt_service.dart';
import '../services/search_state_service.dart';
import '../services/subscription_service.dart';
import '../services/system_settings_service.dart';
import '../services/telemetry_consent_service.dart';
import '../services/ui_preferences_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/csv_export_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_sheet.dart';
import 'app_lock_screen.dart';
import 'legal_document_screen.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  /// UX1 — Localised subtitle for the Dark Mode tile.  Three cases:
  ///   * Theme mode == system → "Following system setting ({dark|light})"
  ///   * Theme mode == dark    → "Dark theme active"
  ///   * Theme mode == light   → "Light theme active"
  ///
  /// The mode token (`dark` / `light`) is *also* localised (it ends up
  /// inside the parenthetical), so English readers see "(dark)" and
  /// German readers see "(dunkel)".
  String _darkModeSubtitle(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mode = KultivarApp.themeNotifier.value;
    if (mode == ThemeMode.system) {
      final modeWord = _isDark(context) ? l.themeModeDark : l.themeModeLight;
      return l.settingsDarkModeFollowingSystem(modeWord);
    }
    return _isDark(context)
        ? l.settingsDarkModeDarkActive
        : l.settingsDarkModeLightActive;
  }

  /// UX1 — Localised "X time ago" phrase shared by the backup tile
  /// subtitle.  Bucketed identically to the original Dart logic:
  ///   * < 1 minute  → "just now"
  ///   * < 1 hour    → "Xmin ago"
  ///   * < 1 day     → "Xh ago"
  ///   * otherwise   → "Xd ago"
  String _formatAgo(BuildContext context, Duration diff) {
    final l = AppLocalizations.of(context);
    if (diff.inMinutes < 1) return l.agoJustNow;
    if (diff.inHours < 1) return l.agoMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l.agoHours(diff.inHours);
    return l.agoDays(diff.inDays);
  }

  /// Returns true when the UI is visually dark — either because the user
  /// explicitly chose dark mode, or because system mode resolves to dark.
  bool _isDark(BuildContext context) {
    final mode = KultivarApp.themeNotifier.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  bool _useFahrenheit = false;
  bool _dryingRemindersEnabled = true;
  bool _curingCompleteEnabled = true;
  bool _burpingEnabled = true;
  bool _envAlertsEnabled = true;
  bool _wateringEnabled = true;
  bool _feedingEnabled = true;
  bool _ipmEnabled = true;
  bool _targetHarvestEnabled = true;
  bool _appLockEnabled = false;
  bool _biometricAvailable = false;
  bool _useBiometric = false;
  bool _backupEncryptionEnabled = false;
  int _snoozeHours = 4;
  bool? _communityShareEnabled; // null = never asked
  String _version = '';
  DateTime? _lastBackupTime;

  // Task #178 — notification-reliability state.  Both default to the
  // "everything fine" value so the banner / prompt never flash during
  // the initial async load.
  bool _osNotificationsEnabled = true;
  bool _batteryExempt = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _useFahrenheit = KultivarApp.useFahrenheitNotifier.value;
    _loadNotifPrefs();
    _loadLockPrefs();
    _loadCommunityPrefs();
    _loadVersion();
    _loadLastBackupTime();
    _loadBackupEncryption();
    _loadSnoozeHours();
    _loadNotifSystemState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check OS-level notification state whenever the app resumes --
  // the user has likely just come back from the system settings page
  // our banner / battery tile deep-linked them to, and the banner
  // should clear immediately if they fixed it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotifSystemState();
    }
  }

  Future<void> _loadNotifSystemState() async {
    final results = await Future.wait([
      NotificationService().areNotificationsEnabled(),
      SystemSettingsService.isIgnoringBatteryOptimizations(),
    ]);
    if (!mounted) return;
    setState(() {
      _osNotificationsEnabled = results[0];
      _batteryExempt = results[1];
    });
  }

  Future<void> _loadSnoozeHours() async {
    final hours = await UiPreferencesService.loadSnoozeHours();
    if (!mounted) return;
    setState(() => _snoozeHours = hours);
  }

  Future<void> _loadBackupEncryption() async {
    final enabled = await BackupEncryptionService.isEnabled();
    if (!mounted) return;
    setState(() => _backupEncryptionEnabled = enabled);
  }

  Future<void> _loadLastBackupTime() async {
    final t = await UiPreferencesService.loadLastBackupTime();
    if (!mounted) return;
    setState(() => _lastBackupTime = t);
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = '${info.appName} v${info.version}+${info.buildNumber}');
  }

  Future<void> _loadNotifPrefs() async {
    final results = await Future.wait([
      UiPreferencesService.loadNotifDrying(),           // [0]
      UiPreferencesService.loadNotifCuring(),           // [1]
      UiPreferencesService.loadNotifBurping(),          // [2]
      UiPreferencesService.loadEnvAlertsEnabled(),      // [3]
      UiPreferencesService.loadNotifWatering(),         // [4]
      UiPreferencesService.loadNotifFeeding(),          // [5]
      UiPreferencesService.loadNotifIpm(),              // [6]
      UiPreferencesService.loadNotifTargetHarvest(),    // [7]
    ]);
    if (!mounted) return;
    setState(() {
      _dryingRemindersEnabled = results[0];
      _curingCompleteEnabled  = results[1];
      _burpingEnabled         = results[2];
      _envAlertsEnabled       = results[3];
      _wateringEnabled        = results[4];
      _feedingEnabled         = results[5];
      _ipmEnabled             = results[6];
      _targetHarvestEnabled   = results[7];
    });
  }

  Future<void> _loadCommunityPrefs() async {
    final v = await UiPreferencesService.loadCommunityShareEnabled();
    if (!mounted) return;
    setState(() => _communityShareEnabled = v);
  }

  Future<void> _loadLockPrefs() async {
    final results = await Future.wait([
      AppLockService.isEnabled(),
      AppLockService.canUseBiometric(),
      AppLockService.useBiometric(),
    ]);
    if (!mounted) return;
    setState(() {
      _appLockEnabled    = results[0];
      _biometricAvailable = results[1];
      _useBiometric      = results[2];
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    // Live count of enabled care reminders for the collapsed-group pill.
    // Recomputed on every rebuild, so flipping any toggle updates the
    // "N/8" badge on the Care reminders header immediately.
    const careReminderTotal = 8;
    final careRemindersOn = [
      _dryingRemindersEnabled,
      _curingCompleteEnabled,
      _burpingEnabled,
      _envAlertsEnabled,
      _wateringEnabled,
      _feedingEnabled,
      _ipmEnabled,
      _targetHarvestEnabled,
    ].where((e) => e).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.headlineMedium(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          // ── Appearance ──────────────────────
          _sectionHeader(AppLocalizations.of(context).settingsSectionAppearance),
          AppCard(
            child: Column(children: [
              _switchTile(
                icon: Icons.dark_mode,
                iconColor: AppColors.secondary,
                label: AppLocalizations.of(context).settingsDarkMode,
                subtitle: _darkModeSubtitle(context),
                value: _isDark(context),
                onChanged: (v) {
                  final mode = v ? ThemeMode.dark : ThemeMode.light;
                  KultivarApp.themeNotifier.value = mode;
                  UiPreferencesService.saveThemeMode(mode);
                  setState(() {});
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _switchTile(
                icon: Icons.thermostat_outlined,
                iconColor: AppColors.accent,
                label: AppLocalizations.of(context).settingsFahrenheit,
                subtitle: AppLocalizations.of(context).settingsFahrenheitSubtitle,
                value: _useFahrenheit,
                onChanged: (v) {
                  setState(() => _useFahrenheit = v);
                  KultivarApp.useFahrenheitNotifier.value = v;
                  UiPreferencesService.saveUseFahrenheit(v);
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              Consumer<CurrencyService>(
                builder: (ctx, currency, __) {
                  final l = AppLocalizations.of(ctx);
                  return _actionTile(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.harvested,
                    label: l.settingsCurrency,
                    subtitle: l.settingsCurrencySubtitle(currency.symbol),
                    onTap: () => _showCurrencyPicker(currency),
                  );
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              // F11 — Language picker.  Bound to KultivarApp.localeNotifier
              // so changing it triggers a rebuild app-wide; no restart.
              ValueListenableBuilder<Locale?>(
                valueListenable: KultivarApp.localeNotifier,
                builder: (ctx, locale, __) {
                  final l = AppLocalizations.of(ctx);
                  final label = _localeLabel(l, locale);
                  return _actionTile(
                    icon: Icons.language_rounded,
                    iconColor: AppColors.primary,
                    label: l.settingsLanguage,
                    subtitle: l.settingsLanguageSubtitle(label),
                    onTap: () => _showLanguagePicker(context),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Notifications ───────────────────
          _sectionHeader(AppLocalizations.of(context).settingsSectionNotifications),
          // Task #178 — recovery path for users who denied the
          // POST_NOTIFICATIONS prompt.  Android never re-asks after a
          // denial, so without this banner the only way back is
          // spelunking through system settings.  Tapping deep-links to
          // the per-app notification settings page; the lifecycle
          // observer re-checks on resume so the banner clears the
          // moment they return with it fixed.
          if (!_osNotificationsEnabled)
            const _BackupBanner(
              icon: Icons.notifications_off_rounded,
              color: AppColors.danger,
              message: 'Notifications are off — reminders won\'t fire. '
                  'Tap to enable them in system settings.',
              onTap: SystemSettingsService.openNotificationSettings,
            ),
          AppCard(
            child: Column(children: [
              // ── Care reminders (collapsed) ──
              // Eight stage/care toggles folded behind one row with a live
              // "N/8 on" pill so the state is visible without expanding.
              _CollapsibleGroup(
                icon: Icons.notifications_active_rounded,
                iconColor: AppColors.primary,
                label:
                    AppLocalizations.of(context).settingsGroupCareReminders,
                summary: '$careRemindersOn/$careReminderTotal',
                summaryColor: careRemindersOn == 0
                    ? AppColors.warning
                    : AppColors.primary,
                children: [
              _switchTile(
                icon: Icons.air,
                iconColor: AppColors.drying,
                label: AppLocalizations.of(context).settingsNotifDrying,
                subtitle: AppLocalizations.of(context).settingsNotifDryingSubtitle,
                value: _dryingRemindersEnabled,
                onChanged: (v) {
                  setState(() => _dryingRemindersEnabled = v);
                  UiPreferencesService.saveNotifDrying(v);
                  KultivarApp.notifDryingEnabled.value = v;
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _switchTile(
                icon: Icons.check_circle,
                iconColor: AppColors.completed,
                label: AppLocalizations.of(context).settingsNotifCuring,
                subtitle: AppLocalizations.of(context).settingsNotifCuringSubtitle,
                value: _curingCompleteEnabled,
                onChanged: (v) {
                  setState(() => _curingCompleteEnabled = v);
                  UiPreferencesService.saveNotifCuring(v);
                  KultivarApp.notifCuringEnabled.value = v;
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _switchTile(
                icon: Icons.notifications,
                iconColor: AppColors.curing,
                label: AppLocalizations.of(context).settingsNotifBurping,
                subtitle: AppLocalizations.of(context).settingsNotifBurpingSubtitle,
                value: _burpingEnabled,
                onChanged: (v) {
                  setState(() => _burpingEnabled = v);
                  UiPreferencesService.saveNotifBurping(v);
                  KultivarApp.notifBurpingEnabled.value = v;
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _switchTile(
                icon: Icons.thermostat_rounded,
                iconColor: AppColors.warning,
                label: AppLocalizations.of(context).settingsNotifEnvAlerts,
                subtitle: AppLocalizations.of(context).settingsNotifEnvAlertsSubtitle,
                value: _envAlertsEnabled,
                onChanged: (v) {
                  setState(() => _envAlertsEnabled = v);
                  UiPreferencesService.saveEnvAlertsEnabled(v);
                  KultivarApp.notifEnvAlertsEnabled.value = v;
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _switchTile(
                icon: Icons.water_drop_rounded,
                iconColor: AppColors.water,
                label: AppLocalizations.of(context).settingsNotifWatering,
                subtitle: AppLocalizations.of(context).settingsNotifWateringSubtitle,
                value: _wateringEnabled,
                onChanged: (v) {
                  setState(() => _wateringEnabled = v);
                  UiPreferencesService.saveNotifWatering(v);
                  KultivarApp.notifWateringEnabled.value = v;
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _switchTile(
                icon: Icons.restaurant_rounded,
                iconColor: AppColors.secondary,
                label: AppLocalizations.of(context).settingsNotifFeeding,
                subtitle: AppLocalizations.of(context).settingsNotifFeedingSubtitle,
                value: _feedingEnabled,
                onChanged: (v) {
                  setState(() => _feedingEnabled = v);
                  UiPreferencesService.saveNotifFeeding(v);
                  KultivarApp.notifFeedingEnabled.value = v;
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _switchTile(
                icon: Icons.bug_report_rounded,
                iconColor: AppColors.ipmColor,
                label: AppLocalizations.of(context).settingsNotifIpm,
                subtitle: AppLocalizations.of(context).settingsNotifIpmSubtitle,
                value: _ipmEnabled,
                onChanged: (v) {
                  setState(() => _ipmEnabled = v);
                  UiPreferencesService.saveNotifIpm(v);
                  KultivarApp.notifIpmEnabled.value = v;
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _switchTile(
                icon: Icons.event_rounded,
                iconColor: AppColors.primary,
                label: AppLocalizations.of(context).settingsNotifTargetHarvest,
                subtitle:
                    AppLocalizations.of(context).settingsNotifTargetHarvestSubtitle,
                value: _targetHarvestEnabled,
                onChanged: (v) {
                  setState(() => _targetHarvestEnabled = v);
                  UiPreferencesService.saveNotifTargetHarvest(v);
                  KultivarApp.notifTargetHarvestEnabled.value = v;
                },
              ),
                ],
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _actionTile(
                icon: Icons.snooze_rounded,
                iconColor: AppColors.harvested,
                label: AppLocalizations.of(context).settingsSnoozeDuration,
                subtitle: AppLocalizations.of(context)
                    .settingsSnoozeDurationSubtitle(_snoozeHours),
                onTap: () => _showSnoozeDurationPicker(context),
              ),
              // ── Troubleshooting (collapsed) ──
              // Battery-exemption + the two delivery-test tiles are
              // diagnostics most users never touch, so they fold behind a
              // single row instead of padding out the main list.
              if (!kIsWeb) ...[
                Divider(color: context.colBorderFaint, height: 1),
                _CollapsibleGroup(
                  icon: Icons.troubleshoot,
                  iconColor: AppColors.warning,
                  label: AppLocalizations.of(context)
                      .settingsGroupTroubleshooting,
                  children: [
                    // Task #178 — battery-optimization exemption.  Samsung
                    // One UI (and other OEM skins) kill background-scheduled
                    // notifications aggressively; exempting the app is the
                    // documented fix.  Only shown while NOT yet exempt.
                    if (!_batteryExempt) ...[
                      _actionTile(
                        icon: Icons.battery_saver_rounded,
                        iconColor: AppColors.warning,
                        label: 'Reliable reminders',
                        subtitle: 'Exempt Kultivar from battery optimization '
                            'so reminders aren\'t silently killed',
                        onTap: SystemSettingsService
                            .openBatteryOptimizationSettings,
                      ),
                      Divider(color: context.colBorderFaint, height: 1),
                    ],
                    // Task #178 — one-tap delivery check.  Verifies the
                    // whole chain (permission -> channel -> OEM policy).
                    _actionTile(
                      icon: Icons.notifications_active_rounded,
                      iconColor: AppColors.primary,
                      label: 'Send test notification',
                      subtitle: 'Check that reminders reach this device',
                      onTap: () async {
                        await NotificationService().showTestNotification();
                        if (!context.mounted) return;
                        AppToast.show(
                          context,
                          _osNotificationsEnabled
                              ? 'Test sent — check your notification shade.'
                              : 'Test sent, but notifications are off in '
                                  'system settings — nothing will appear.',
                          type: _osNotificationsEnabled
                              ? ToastType.success
                              : ToastType.info,
                        );
                      },
                    ),
                    // Task #180 — scheduler check.  The immediate test
                    // above bypasses the scheduler entirely (show() posts
                    // straight to the shade), so it can pass while every
                    // burping / watering reminder is broken.  This tile
                    // queues through the exact same zonedSchedule path
                    // reminders use and reports the OS pending-queue count.
                    Divider(color: context.colBorderFaint, height: 1),
                    _actionTile(
                      icon: Icons.schedule_send_rounded,
                      iconColor: AppColors.secondary,
                      label: 'Send scheduled test (~1 min)',
                      subtitle: 'Tests the reminder scheduler — Android may '
                          'delay delivery a few minutes',
                      onTap: () async {
                        final ns = NotificationService();
                        await ns.showScheduledTestNotification();
                        final pending = await ns.pendingNotificationCount();
                        if (!context.mounted) return;
                        AppToast.show(
                          context,
                          'Queued ($pending pending with the OS). Lock the '
                              'screen and wait — inexact scheduling can take '
                              'a few minutes, especially on Samsung.',
                          type: ToastType.success,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Data ────────────────────────────
          _sectionHeader(AppLocalizations.of(context).settingsSectionDataExport),
          AppCard(
            child: Column(children: [
              _actionTile(
                icon: Icons.folder_zip_rounded,
                iconColor: AppColors.primary,
                label: AppLocalizations.of(context).settingsExportAll,
                subtitle: AppLocalizations.of(context).settingsExportAllSubtitle,
                onTap: () async {
                  await CsvExportService.exportAllCsv(
                    plants: repo.plants,
                    spaces: repo.growSpaces,
                    harvestLogs: repo.harvestLogs,
                    envLogs: repo.environmentLogs,
                    notes: repo.notes,
                    expenses: repo.expenses,
                  );
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              // ── Export by type (collapsed) ──
              // "Export all" above covers the common case; the five
              // per-entity exports fold behind one row.
              _CollapsibleGroup(
                icon: Icons.category_rounded,
                iconColor: AppColors.secondary,
                label:
                    AppLocalizations.of(context).settingsGroupExportByType,
                children: [
              _actionTile(
                icon: Icons.eco_rounded,
                iconColor: AppColors.growing,
                label: AppLocalizations.of(context).settingsExportPlants,
                subtitle:
                    AppLocalizations.of(context).settingsExportPlantsSubtitle,
                onTap: () async {
                  await CsvExportService.exportPlants(
                    repo.plants,
                    repo.growSpaces,
                  );
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _actionTile(
                icon: Icons.download,
                iconColor: AppColors.harvested,
                label: AppLocalizations.of(context).settingsExportHarvests,
                subtitle:
                    AppLocalizations.of(context).settingsExportHarvestsSubtitle,
                onTap: () async {
                  await CsvExportService.exportHarvestLogs(
                    repo.harvestLogs,
                    repo.plants,
                  );
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _actionTile(
                icon: Icons.thermostat,
                iconColor: AppColors.drying,
                label: AppLocalizations.of(context).settingsExportEnv,
                subtitle:
                    AppLocalizations.of(context).settingsExportEnvSubtitle,
                onTap: () async {
                  await CsvExportService.exportEnvironmentLogs(
                    repo.environmentLogs,
                    repo.growSpaces,
                  );
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _actionTile(
                icon: Icons.notes_rounded,
                iconColor: AppColors.secondary,
                label: AppLocalizations.of(context).settingsExportNotes,
                subtitle:
                    AppLocalizations.of(context).settingsExportNotesSubtitle,
                onTap: () async {
                  await CsvExportService.exportNotes(
                    repo.notes,
                    repo.plants,
                  );
                },
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _actionTile(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.harvested,
                label: AppLocalizations.of(context).settingsExportExpenses,
                subtitle:
                    AppLocalizations.of(context).settingsExportExpensesSubtitle,
                onTap: () async {
                  await CsvExportService.exportExpenses(
                    repo.expenses,
                    repo.plants,
                    repo.growSpaces,
                  );
                },
              ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

// ── Backup & Restore ────────────────
          _sectionHeader(AppLocalizations.of(context).settingsSectionBackup),
          _backupStatusBanner(context),
          AppCard(
            child: Column(children: [
              _actionTile(
                icon: Icons.backup_rounded,
                iconColor: AppColors.primary,
                label: AppLocalizations.of(context).settingsExportBackup,
                // UX1 — subtitle is now fully localised; the "ago" phrase
                // resolves via _formatAgo which routes through ARB plurals.
                subtitle: _backupSubtitle(context),
                onTap: () => _exportBackup(context, repo),
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _actionTile(
                icon: Icons.restore_rounded,
                iconColor: AppColors.secondary,
                label: AppLocalizations.of(context).settingsImportBackup,
                subtitle:
                    AppLocalizations.of(context).settingsImportBackupSubtitle,
                onTap: () => _confirmImportBackup(context, repo),
              ),
              if (!kIsWeb) ...[
                Divider(color: context.colBorderFaint, height: 1),
                // ── More backup options (collapsed) ──
                // Export / Import above are the everyday actions; cloud
                // share, the how-to, and encryption fold behind one row.
                _CollapsibleGroup(
                  icon: Icons.tune_rounded,
                  iconColor: AppColors.secondary,
                  label: AppLocalizations.of(context)
                      .settingsGroupBackupOptions,
                  children: [
                _actionTile(
                  icon: Icons.cloud_upload_rounded,
                  iconColor: AppColors.secondary,
                  label: AppLocalizations.of(context).settingsBackupShareCloud,
                  subtitle: AppLocalizations.of(context)
                      .settingsBackupShareCloudSubtitle,
                  onTap: () => _shareLatestBackup(context),
                ),
                Divider(color: context.colBorderFaint, height: 1),
                _actionTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: context.colTextMuted,
                  label: AppLocalizations.of(context).settingsBackupAbout,
                  subtitle:
                      AppLocalizations.of(context).settingsBackupAboutSubtitle,
                  onTap: () => _showAutoBackupInfo(context),
                ),
                Divider(color: context.colBorderFaint, height: 1),
                _switchTile(
                  icon: Icons.enhanced_encryption_rounded,
                  iconColor: AppColors.harvested,
                  label: AppLocalizations.of(context).settingsBackupEncrypt,
                  subtitle: _backupEncryptionEnabled
                      ? AppLocalizations.of(context)
                          .settingsBackupEncryptSubtitleOn
                      : AppLocalizations.of(context)
                          .settingsBackupEncryptSubtitleOff,
                  value: _backupEncryptionEnabled,
                  onChanged: (v) => v
                      ? _setupBackupPassphrase(context)
                      : _forgetBackupPassphrase(context),
                ),
                  ],
                ),
              ],
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Privacy ─────────────────────────
          //
          // UX7 — when App Lock is enabled, the Biometrics + Change PIN
          // tiles are sub-options of it.  Unifying every row's icon
          // colour to `AppColors.primary` makes the three rows read as
          // one feature group (was previously primary / secondary /
          // primary which fragmented the visual hierarchy).  Sub-rows
          // also gain a subtle left indent so the parent-child
          // relationship is clear even before reading the labels.
          if (!kIsWeb) ...[
            _sectionHeader(AppLocalizations.of(context).settingsSectionPrivacy),
            AppCard(
              child: Column(children: [
                _switchTile(
                  icon: Icons.lock_rounded,
                  iconColor: AppColors.primary,
                  label: AppLocalizations.of(context).settingsAppLock,
                  subtitle: _appLockEnabled
                      ? AppLocalizations.of(context).settingsAppLockSubtitleOn
                      : AppLocalizations.of(context).settingsAppLockSubtitleOff,
                  value: _appLockEnabled,
                  onChanged: (v) => v
                      ? _enableAppLock(context)
                      : _disableAppLock(context),
                ),
                if (_appLockEnabled && _biometricAvailable) ...[
                  Divider(
                      color: context.colBorderFaint,
                      height: 1,
                      indent: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: _switchTile(
                      icon: Icons.fingerprint,
                      iconColor: AppColors.primary,
                      label: AppLocalizations.of(context).settingsUseBiometrics,
                      subtitle: AppLocalizations.of(context)
                          .settingsUseBiometricsSubtitle,
                      value: _useBiometric,
                      onChanged: (v) async {
                        await AppLockService.setUseBiometric(v);
                        setState(() => _useBiometric = v);
                      },
                    ),
                  ),
                ],
                if (_appLockEnabled) ...[
                  Divider(
                      color: context.colBorderFaint,
                      height: 1,
                      indent: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: _actionTile(
                      icon: Icons.pin_rounded,
                      iconColor: AppColors.primary,
                      label: AppLocalizations.of(context).settingsChangePin,
                      subtitle: AppLocalizations.of(context)
                          .settingsChangePinSubtitle,
                      onTap: () => _showPinSetup(context, isChange: true),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Subscription ─────────────────────
          //
          // Apple + Google both require cancellation to happen through
          // their own subscription-management UI, so this section
          // intentionally has no in-app cancel button.  What it does
          // expose is:
          //   * current Pro status + renewal/expiry date
          //   * "Restore Purchases" — required by Apple §3.1.1 so
          //     reinstalls can recover entitlements
          //   * "Manage Subscription" — deep-links to the platform's
          //     subscription page (RevenueCat handles the routing)
          //   * "Upgrade to Pro" — opens the paywall when on Free
          if (!kIsWeb) _subscriptionSection(context),

          // ── Community ───────────────────────
          _sectionHeader(AppLocalizations.of(context).settingsSectionCommunity),
          AppCard(
            child: _switchTile(
              icon: Icons.people_rounded,
              iconColor: AppColors.secondary,
              label: AppLocalizations.of(context).settingsCommunityShare,
              subtitle: _communityShareEnabled == true
                  ? AppLocalizations.of(context)
                      .settingsCommunityShareSubtitleOn
                  : _communityShareEnabled == false
                      ? AppLocalizations.of(context)
                          .settingsCommunityShareSubtitleOff
                      : AppLocalizations.of(context)
                          .settingsCommunityShareSubtitlePrompt,
              value: _communityShareEnabled == true,
              onChanged: (v) {
                setState(() => _communityShareEnabled = v);
                UiPreferencesService.saveCommunityShareEnabled(v);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── App ─────────────────────────────
          _sectionHeader(AppLocalizations.of(context).settingsSectionApp),
          AppCard(
            child: Column(children: [
              ValueListenableBuilder<bool>(
                valueListenable: KultivarApp.isDemoModeNotifier,
                builder: (_, isDemo, __) => isDemo
                    ? Column(
                        children: [
                          _actionTile(
                            icon: Icons.science_rounded,
                            iconColor: AppColors.warning,
                            label: AppLocalizations.of(context).settingsExitDemo,
                            subtitle: AppLocalizations.of(context)
                                .settingsExitDemoSubtitle,
                            onTap: () => _confirmExitDemo(context, repo),
                          ),
                          Divider(color: context.colBorderFaint, height: 1),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              // ── Maintenance (collapsed) ──
              // Storage cleanup + replaying the intro are occasional
              // housekeeping, folded behind one row.  Clear-all stays
              // visible below so the destructive action is never hidden.
              _CollapsibleGroup(
                icon: Icons.handyman_rounded,
                iconColor: AppColors.accent,
                label:
                    AppLocalizations.of(context).settingsGroupMaintenance,
                children: [
                  if (!kIsWeb) ...[
                    _actionTile(
                      icon: Icons.cleaning_services_rounded,
                      iconColor: AppColors.accent,
                      label:
                          AppLocalizations.of(context).settingsReclaimStorage,
                      subtitle: AppLocalizations.of(context)
                          .settingsReclaimStorageSubtitle,
                      onTap: () => _reclaimStorage(context, repo),
                    ),
                    Divider(color: context.colBorderFaint, height: 1),
                  ],
                  _actionTile(
                    icon: Icons.school_rounded,
                    iconColor: AppColors.secondary,
                    label:
                        AppLocalizations.of(context).settingsReplayOnboarding,
                    subtitle: AppLocalizations.of(context)
                        .settingsReplayOnboardingSubtitle,
                    onTap: () => _replayOnboarding(context),
                  ),
                ],
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _actionTile(
                icon: Icons.delete_forever,
                iconColor: AppColors.danger,
                label: AppLocalizations.of(context).settingsClearAll,
                subtitle:
                    AppLocalizations.of(context).settingsClearAllSubtitle,
                onTap: () => _confirmClearData(context, repo),
              ),
              // ── DEV-ONLY tier picker (Path A) ──
              //
              // Pre-launch payment-test groundwork while the bank +
              // merchant profile chain is still verifying.  Lets us
              // flip our own state to any tier without going through
              // RevenueCat or Play Billing, then screenshot every
              // paywall + gated screen at every tier.
              //
              // SubscriptionService.debugSetTier asserts kDebugMode
              // internally; the tile is also gated here so it never
              // ships in release builds.  No localisation -- dev-only.
              if (kDebugMode) ...[
                Divider(color: context.colBorderFaint, height: 1),
                Consumer<SubscriptionService>(
                  builder: (ctx, sub, _) => _actionTile(
                    icon: Icons.science_outlined,
                    iconColor: AppColors.accent,
                    label: 'DEV: subscription tier',
                    subtitle: 'Current: ${sub.tier.name} '
                        '(tap to change -- debug builds only)',
                    onTap: () => _showDevTierPicker(context, sub),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Legal (SR1 + SR2) ────────────────────
          //
          // App Store + Play Store require an in-app link to the
          // Privacy Policy.  Both docs live in `lib/legal/` as const
          // markdown and render through the same `LegalDocumentScreen`
          // viewer.  Position: after "App" actions, before the
          // version-string footer — same neighbourhood as About
          // information in most apps' settings.
          _sectionHeader(AppLocalizations.of(context).settingsSectionLegal),
          AppCard(
            child: Column(children: [
              _actionTile(
                icon: Icons.privacy_tip_rounded,
                iconColor: AppColors.primary,
                label: 'Privacy Policy',
                subtitle:
                    'How your grow data is stored and what we never share',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalDocumentScreen(
                      title: 'Privacy Policy',
                      markdown: kPrivacyPolicyMarkdown,
                      version: kPrivacyPolicyVersion,
                    ),
                  ),
                ),
              ),
              Divider(color: context.colBorderFaint, height: 1),
              _actionTile(
                icon: Icons.gavel_rounded,
                iconColor: AppColors.secondary,
                label: 'Terms of Service',
                subtitle:
                    'The deal between you and Kultivar — plain-English version',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalDocumentScreen(
                      title: 'Terms of Service',
                      markdown: kTermsOfServiceMarkdown,
                      version: kTermsOfServiceVersion,
                    ),
                  ),
                ),
              ),
              Divider(color: context.colBorderFaint, height: 1),
              // SR6 — Telemetry consent toggle.  Reactive to the
              // TelemetryConsentService so flipping it elsewhere
              // (e.g. via the first-launch sheet) updates immediately.
              // The subtitle is intentionally honest about the
              // "takes effect on next app launch" caveat — the
              // Sentry SDK wraps `runApp` in its error zone at boot
              // and can't be initialised retroactively.
              Consumer<TelemetryConsentService>(
                builder: (ctx, consent, _) {
                  return _switchTile(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.primary,
                    label: 'Help improve Kultivar',
                    subtitle: consent.hasGranted
                        ? 'Sending anonymous crash + performance data. '
                            'Changes take effect on next app launch.'
                        : 'No telemetry is being sent. Toggle on to '
                            'share anonymous crash + performance data.',
                    value: consent.hasGranted,
                    onChanged: (v) async {
                      if (v) {
                        await consent.grant();
                      } else {
                        await consent.decline();
                      }
                    },
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Support Kultivar ────────────────────────
          //
          // Task #87 — Manual entry point for the App Store / Play
          // review prompt.  Tapping this fires the native UI
          // immediately, bypassing every automatic-prompt cooldown.
          // Apple still caps at 3 prompts / 365 days per user, but a
          // manual tap is treated as user-driven and counts toward
          // (not against) Apple's ranking signal of "responsive
          // developer".
          //
          // Placed AFTER Legal so the section reads as "the
          // boring necessary stuff, then the optional warm thing"
          // rather than a transactional ask at the top.
          _sectionHeader(AppLocalizations.of(context).settingsSectionSupport),
          AppCard(
            child: Column(children: [
              _actionTile(
                icon: Icons.star_rounded,
                iconColor: AppColors.accent,
                label: 'Rate Kultivar',
                subtitle: 'Help other growers find the app',
                onTap: () async {
                  await ReviewPromptService.showManualPrompt();
                },
              ),
              // Primary path:  open the user's mail client with the
              // crash log inlined in the body and support@kultivar.io
              // pre-filled.  Removes the friction of the generic
              // share sheet (which would let the user pick anything,
              // including no-ops like Drive that don't actually
              // surface the log to us).
              _actionTile(
                icon: Icons.mail_outline_rounded,
                iconColor: AppColors.primary,
                label: 'Email Support',
                subtitle: 'Send the crash log to support@kultivar.io',
                onTap: () => _emailDiagnostics(context),
              ),
              // Secondary path:  the original generic share for users
              // who prefer WhatsApp / Slack / Drive / etc.  Stays on
              // disk until they tap.
              _actionTile(
                icon: Icons.share_rounded,
                iconColor: AppColors.textMuted,
                label: 'Share Diagnostics',
                subtitle: 'Hand off to another app',
                onTap: () => _shareDiagnostics(context),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: Text(
              _version.isNotEmpty ? _version : 'Kultivar',
              style: AppTypography.bodySmall(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // ── Backup helpers ────────────────────────────

  /// UX1 — Localised subtitle for the Export Backup tile.  Two cases:
  ///   * No backup yet     → "All data + photos as ZIP archive"
  ///   * Backup exists     → "Last backup: <ago>" (uses [_formatAgo])
  ///
  /// Takes BuildContext so it can resolve `AppLocalizations.of(context)`;
  /// the call site (`_actionTile(... subtitle: _backupSubtitle(context))`)
  /// already has a context in scope.
  String _backupSubtitle(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_lastBackupTime == null) return l.settingsBackupSubtitleNever;
    final ago =
        _formatAgo(context, DateTime.now().difference(_lastBackupTime!));
    return l.settingsBackupSubtitleAgo(ago);
  }

  /// Returns null when no banner should be shown (backup is recent / never run).
  Widget _backupStatusBanner(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_lastBackupTime == null) {
      // Never backed up — show a gentle prompt.
      return _BackupBanner(
        icon: Icons.cloud_off_rounded,
        color: AppColors.warning,
        message: l.settingsBackupBannerNoBackup,
        onTap: null,
      );
    }

    final daysSince =
        DateTime.now().difference(_lastBackupTime!).inDays;

    if (daysSince >= 14) {
      return _BackupBanner(
        icon: Icons.warning_amber_rounded,
        color: AppColors.danger,
        message: l.settingsBackupBannerStale(daysSince),
        onTap: null,
      );
    }

    if (daysSince >= 7) {
      return _BackupBanner(
        icon: Icons.schedule_rounded,
        color: AppColors.warning,
        message: l.settingsBackupBannerAging(daysSince),
        onTap: null,
      );
    }

    // Backup is fresh — no banner needed.
    return const SizedBox.shrink();
  }

  // ── App lock helpers ──────────────────────────

  void _enableAppLock(BuildContext context) {
    _showPinSetup(context, isChange: false);
  }

  Future<void> _disableAppLock(BuildContext ctx) async {
    final ok = await _confirmCurrentAuth(ctx);
    if (!ok || !mounted) return;
    await AppLockService.clearAll();
    KultivarApp.sessionUnlocked = false;
    if (!mounted) return;
    setState(() {
      _appLockEnabled = false;
      _useBiometric = false;
    });
    AppToast.show(context, 'App Lock disabled', type: ToastType.info);
  }

  Future<bool> _confirmCurrentAuth(BuildContext context) async {
    // Try biometric first if available and preferred.
    if (_useBiometric && _biometricAvailable) {
      return AppLockService.authenticateWithBiometric();
    }
    // Otherwise show a quick PIN prompt.
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => _ConfirmPinSheet(),
    );
    return result == true;
  }

  /// Bottom sheet with the snooze-duration choices from
  /// [UiPreferencesService.snoozeHourChoices].  Selection is applied
  /// immediately and persists across launches.  See U15.
  // ── DEV-only tier picker ──
  //
  // Bottom sheet wired to SubscriptionService.debugSetTier.  Each row
  // describes what unlocks at that tier so dev-mode walkthroughs match
  // the screens the user will see post-purchase.  Selection persists
  // across hot restarts (handled by SubscriptionService via the
  // `dev_tier_override` SharedPreferences key).
  //
  // No localisation -- this never ships in release; it's a dev tool
  // for screenshotting the paywall + gated screens at every tier
  // while we wait for the bank-verified merchant profile.
  void _showDevTierPicker(BuildContext context, SubscriptionService sub) {
    const rows = <(SubscriptionTier, String, String)>[
      (
        SubscriptionTier.free,
        'Free',
        '1 space, 3 plants, 60-day analytics window',
      ),
      (
        SubscriptionTier.lifetimeLocal,
        'Lifetime Local',
        'Unlimited local features, no community / cloud',
      ),
      (
        SubscriptionTier.proCloud,
        'Pro Cloud',
        'Everything + community benchmarking + future sync',
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  0,
                  AppSpacing.pagePadding,
                  AppSpacing.xs,
                ),
                child: Text(
                  'DEV: subscription tier',
                  style: AppTypography.headlineMedium(ctx),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  0,
                  AppSpacing.pagePadding,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Pin the local entitlement without touching Play Billing '
                  'or RevenueCat. Persists across hot restarts. '
                  'Debug builds only.',
                  style: AppTypography.bodySmall(ctx)
                      .copyWith(color: ctx.colTextMuted),
                ),
              ),
              for (final (tier, label, summary) in rows)
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(
                      tier == SubscriptionTier.free
                          ? Icons.lock_outline_rounded
                          : tier == SubscriptionTier.lifetimeLocal
                              ? Icons.all_inclusive_rounded
                              : Icons.workspace_premium_rounded,
                      size: 20,
                      color: AppColors.accent,
                    ),
                  ),
                  title: Text(label, style: AppTypography.labelLarge(ctx)),
                  subtitle: Text(
                    summary,
                    style: AppTypography.bodySmall(ctx)
                        .copyWith(color: ctx.colTextMuted),
                  ),
                  trailing: tier == sub.tier
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () async {
                    await sub.debugSetTier(tier);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!context.mounted) return;
                    AppToast.show(
                      context,
                      'Tier set to ${tier.name}',
                      type: ToastType.info,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnoozeDurationPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, 0,
                    AppSpacing.pagePadding, AppSpacing.sm),
                child: Text('Snooze Duration',
                    style: AppTypography.headlineMedium(ctx)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, 0,
                    AppSpacing.pagePadding, AppSpacing.sm),
                child: Text(
                  'How long to defer a care reminder when you tap '
                  '"Snooze" on the notification.',
                  style: AppTypography.bodySmall(ctx)
                      .copyWith(color: ctx.colTextMuted),
                ),
              ),
              for (final hours in UiPreferencesService.snoozeHourChoices)
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.harvested.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      '${hours}h',
                      style: AppTypography.labelLarge(ctx).copyWith(
                          color: AppColors.harvested,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(_snoozeLabel(hours),
                      style: AppTypography.labelLarge(ctx)),
                  trailing: hours == _snoozeHours
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () async {
                    await UiPreferencesService.saveSnoozeHours(hours);
                    if (!mounted) return;
                    setState(() => _snoozeHours = hours);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _snoozeLabel(int hours) {
    switch (hours) {
      case 1:
        return '1 hour later';
      case 2:
        return '2 hours later';
      case 4:
        return '4 hours later (default)';
      case 8:
        return '8 hours later';
      default:
        return '$hours hours later';
    }
  }

  // ── F11 — Language picker ─────────────────────
  //
  // Resolves the localized name for the currently-active locale; falls
  // back to "System default" when the user has no explicit choice.
  String _localeLabel(AppLocalizations l, Locale? locale) {
    if (locale == null) return l.settingsLanguageSystem;
    switch (locale.languageCode) {
      case 'es':
        return l.settingsLanguageSpanish;
      case 'de':
        return l.settingsLanguageGerman;
      case 'fr':
        return l.settingsLanguageFrench;
      case 'pt':
        return l.settingsLanguagePortuguese;
      case 'it':
        return l.settingsLanguageItalian;
      case 'nl':
        return l.settingsLanguageDutch;
      // F12 — South Africa expansion.
      case 'af':
        return l.settingsLanguageAfrikaans;
      case 'zu':
        return l.settingsLanguageZulu;
      case 'en':
      default:
        return l.settingsLanguageEnglish;
    }
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final current = KultivarApp.localeNotifier.value;
    // Pseudo-locale 'system' sentinel is represented as null; null
    // tells MaterialApp to fall back to the OS-reported locale.
    final options = <(String? tag, String label)>[
      (null, l.settingsLanguageSystem),
      ('en', l.settingsLanguageEnglish),
      ('es', l.settingsLanguageSpanish),
      ('de', l.settingsLanguageGerman),
      ('fr', l.settingsLanguageFrench),
      ('pt', l.settingsLanguagePortuguese),
      ('it', l.settingsLanguageItalian),
      ('nl', l.settingsLanguageDutch),
      // F12 — South Africa expansion.  isiZulu uses an autonym
      // ("isiZulu") rather than an exonym so the option reads
      // naturally to a Zulu-first user scanning the picker.
      ('af', l.settingsLanguageAfrikaans),
      ('zu', l.settingsLanguageZulu),
    ];

    await showModalBottomSheet<void>(
      context: context,
      // `isScrollControlled: true` lets the sheet grow taller than the
      // 50%-of-screen default — required once the language list grew
      // past 5-6 items, otherwise the bottom rows clip with the "54px
      // overflow" yellow-striped warning bar.
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        // Cap the sheet at 80% of screen height — past that, the inner
        // ListView scrolls.  Title stays pinned at the top.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      0,
                      AppSpacing.pagePadding,
                      AppSpacing.sm),
                  child: Text(l.settingsLanguage,
                      style: AppTypography.headlineMedium(ctx)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (tag, label) in options)
                        ListTile(
                          leading: Icon(
                            tag == null
                                ? Icons.smartphone_rounded
                                : Icons.language_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(label,
                              style: AppTypography.labelLarge(ctx)),
                          trailing: (current?.languageCode == tag) ||
                                  (current == null && tag == null)
                              ? const Icon(Icons.check_rounded,
                                  color: AppColors.primary, size: 20)
                              : null,
                          onTap: () async {
                            await UiPreferencesService.saveLocaleTag(tag);
                            KultivarApp.localeNotifier.value =
                                tag == null ? null : Locale(tag);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ── Subscription section ──────────────────────────────────────────
  ///
  /// Renders inside the Settings ListView.  Status + actions adapt
  /// based on which RevenueCat tier the user owns:
  ///
  ///   * **Free** → "Upgrade" tile (opens the three-tier paywall)
  ///   * **Lifetime Local** → "Lifetime Local" tile, NO manage-sub row
  ///     (no recurring charge to manage) but a subtle "Upgrade to
  ///     Pro Cloud" entry so users with second thoughts can convert.
  ///   * **Pro Cloud, renewing** → "Kultivar Pro · renews on …" +
  ///     "Manage Subscription" deep link.
  ///   * **Pro Cloud, lapsing**  → "Kultivar Pro · expires on …".
  ///
  /// The Restore tile is always present — both lifetime IAP and
  /// subscriptions get restored through the same RevenueCat call.
  Widget _subscriptionSection(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (ctx, sub, _) {
        final tier = sub.tier;
        final isFree = tier == SubscriptionTier.free;
        final isLifetime = tier == SubscriptionTier.lifetimeLocal;
        final isCloud = tier == SubscriptionTier.proCloud;
        final expiry = sub.proExpiryDate;
        final willRenew = sub.willRenew;

        String statusSubtitle;
        if (isFree) {
          statusSubtitle =
              'Free plan · unlock unlimited features with Lifetime Local or Pro Cloud';
        } else if (isLifetime) {
          statusSubtitle =
              'One-time purchase active · all local features unlocked forever';
        } else if (expiry == null) {
          // Pro Cloud without expiry (rare — promo / lifetime sub plan).
          statusSubtitle = 'Pro Cloud active';
        } else {
          final date = '${expiry.day.toString().padLeft(2, '0')}/'
              '${expiry.month.toString().padLeft(2, '0')}/'
              '${expiry.year}';
          statusSubtitle = willRenew
              ? 'Pro Cloud · renews on $date'
              : 'Pro Cloud · expires on $date';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                AppLocalizations.of(ctx).settingsSectionSubscription),
            AppCard(
              child: Column(children: [
                // ── Status / Upgrade tile ──
                _actionTile(
                  icon: isFree
                      ? Icons.lock_open_rounded
                      : Icons.workspace_premium_rounded,
                  iconColor:
                      isFree ? AppColors.primary : AppColors.accent,
                  label: isFree ? 'Upgrade' : tier.label,
                  subtitle: statusSubtitle,
                  // Lifetime users tap to *visit* the paywall (so they
                  // can see the Pro Cloud upgrade path); Pro Cloud
                  // users tap to manage the subscription; Free users
                  // tap to start the upgrade flow.
                  onTap: isCloud
                      ? () => sub.openManageSubscriptions()
                      : () => PaywallScreen.show(ctx),
                ),
                Divider(color: ctx.colBorderFaint, height: 1),
                // ── Manage Subscription (Pro Cloud only) ──
                //
                // Lifetime Local has nothing to manage — there's no
                // recurring charge.  Hiding this row prevents confused
                // taps that would deep-link them to an empty App Store
                // subscriptions page.
                if (isCloud) ...[
                  _actionTile(
                    icon: Icons.open_in_new_rounded,
                    iconColor: ctx.colTextMuted,
                    label: 'Manage Subscription',
                    subtitle:
                        'Change plan or cancel · opens the App Store / Play Store',
                    onTap: () => sub.openManageSubscriptions(),
                  ),
                  Divider(color: ctx.colBorderFaint, height: 1),
                ],
                // ── Add cloud features (Lifetime → Pro Cloud upsell) ──
                //
                // A Lifetime owner may later want community benchmarking
                // or cross-device sync.  Surfacing the upgrade path
                // here is the only place inside the app where a paying
                // customer can self-serve the conversion.
                if (isLifetime) ...[
                  _actionTile(
                    icon: Icons.cloud_outlined,
                    iconColor: AppColors.accent,
                    label: 'Add cloud features',
                    subtitle:
                        'Pro Cloud — community benchmarks and sync, rolling out soon',
                    onTap: () => PaywallScreen.show(ctx),
                  ),
                  Divider(color: ctx.colBorderFaint, height: 1),
                ],
                // ── Restore Purchases ──
                _actionTile(
                  icon: Icons.restore_rounded,
                  iconColor: AppColors.secondary,
                  label: 'Restore Purchases',
                  subtitle: sub.isPurchasing
                      ? 'Checking…'
                      : 'Recover a previous purchase on this Apple ID / Google account',
                  onTap: () async {
                    // Guard inside the callback rather than disabling the
                    // tile, so the user gets visual feedback that we
                    // received the tap even while a previous request is
                    // still in flight.
                    if (sub.isPurchasing) return;
                    final restored = await sub.restorePurchases();
                    if (!ctx.mounted) return;
                    AppToast.show(
                      ctx,
                      restored
                          ? 'Purchase restored — thanks for coming back!'
                          : 'No previous purchase found on this account.',
                      type: restored
                          ? ToastType.success
                          : ToastType.info,
                    );
                  },
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }

  void _showCurrencyPicker(CurrencyService currency) {
    showModalBottomSheet<void>(
      context: context,
      // `isScrollControlled: true` + the 80% height cap below let the
      // sheet grow tall enough to show the title + quick-row chips
      // without clipping into the system home indicator (the "54px
      // overflow" warning) once the choices list grew to 24+ entries.
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding, 0, AppSpacing.pagePadding,
                    AppSpacing.sm),
                child: Text('Choose Currency',
                    style: AppTypography.headlineMedium(ctx)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding, 0, AppSpacing.pagePadding,
                    AppSpacing.sm),
                child: Text(
                  'Applies to all expense and cost-per-gram displays. '
                  'Existing values stay unchanged — only the symbol is updated.',
                  style: AppTypography.bodySmall(ctx)
                      .copyWith(color: ctx.colTextMuted),
                ),
              ),

              // ── UX5 — quick-row of the four most-used currency symbols.
              // Lets the common case (£/$/€/¥) finish in one tap instead
              // of scrolling the 10-row list.  Selected chip pulses the
              // primary color; tapping pops the sheet identical to the
              // long-list rows below.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding, 0, AppSpacing.pagePadding,
                    AppSpacing.sm),
                child: Row(
                  children: [
                    for (final symbol in const ['£', '\$', '€', '¥'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _CurrencyQuickChip(
                            symbol: symbol,
                            selected: currency.symbol == symbol,
                            onTap: () async {
                              await currency.setSymbol(symbol);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding),
                child: Divider(color: ctx.colBorderFaint, height: 1),
              ),
              const SizedBox(height: AppSpacing.xs),

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: CurrencyService.choices.length,
                  itemBuilder: (_, i) {
                    final choice = CurrencyService.choices[i];
                    final selected = choice.symbol == currency.symbol;
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.harvested.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          choice.symbol,
                          style: AppTypography.labelLarge(ctx).copyWith(
                              color: AppColors.harvested,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(choice.label,
                          style: AppTypography.labelLarge(ctx)),
                      trailing: selected
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 20)
                          : null,
                      onTap: () async {
                        await currency.setSymbol(choice.symbol);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // ── Backup encryption ─────────────────────────

  Future<void> _setupBackupPassphrase(BuildContext context) async {
    final result = await _showPassphraseDialog(
      context,
      title: 'Set Backup Passphrase',
      body: 'You will need this passphrase to restore from any backup '
          'created from now on. Save it somewhere safe — without it, '
          'encrypted backups CANNOT be recovered, even by us.',
      requireConfirmation: true,
      submitLabel: 'Set & Enable',
    );
    if (result == null) return;
    try {
      await BackupEncryptionService.setPassphrase(result);
      // Use `context.mounted` rather than the State's `mounted` so the
      // analyzer can see the guard refers to *this* BuildContext —
      // otherwise the `use_build_context_synchronously` lint trips.
      if (!context.mounted) return;
      setState(() => _backupEncryptionEnabled = true);
      AppToast.show(context, 'Backups will now be encrypted',
          type: ToastType.success);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Could not save passphrase: $e',
          type: ToastType.error);
    }
  }

  Future<void> _forgetBackupPassphrase(BuildContext context) async {
    final confirmed = await ConfirmSheet.show(
      context,
      icon: Icons.lock_open_rounded,
      iconColor: AppColors.warning,
      title: 'Disable backup encryption?',
      body: 'New backups will be saved unencrypted. '
          'Existing encrypted backups will still require the passphrase '
          'to restore — make sure you have it written down before '
          'forgetting it here.',
      confirmLabel: 'Disable encryption',
      confirmColor: AppColors.warning,
    );
    if (!confirmed) return;
    await BackupEncryptionService.forgetPassphrase();
    if (!context.mounted) return;
    setState(() => _backupEncryptionEnabled = false);
    AppToast.show(context, 'Backup encryption disabled',
        type: ToastType.info);
  }

  /// Generic passphrase prompt — reused for setup and for the restore
  /// flow when an encrypted backup is selected.
  Future<String?> _showPassphraseDialog(
    BuildContext context, {
    required String title,
    required String body,
    bool requireConfirmation = false,
    String submitLabel = 'Submit',
  }) {
    final pwCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    bool obscured = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: pwCtrl,
                  obscureText: obscured,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Passphrase',
                    suffixIcon: IconButton(
                      icon: Icon(obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      tooltip: obscured ? 'Show passphrase' : 'Hide passphrase',
                      onPressed: () => ss(() => obscured = !obscured),
                    ),
                  ),
                ),
                if (requireConfirmation) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscured,
                    decoration: const InputDecoration(
                      labelText: 'Confirm passphrase',
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(error!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pw = pwCtrl.text;
                if (pw.trim().isEmpty) {
                  ss(() => error = 'Passphrase cannot be empty.');
                  return;
                }
                if (pw.trim().length < 6) {
                  ss(() => error =
                      'Use at least 6 characters for any real protection.');
                  return;
                }
                if (requireConfirmation && pw != confirmCtrl.text) {
                  ss(() => error = 'Passphrases don\'t match.');
                  return;
                }
                Navigator.pop(ctx, pw.trim());
              },
              child: Text(submitLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _showPinSetup(BuildContext context, {required bool isChange}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => PinSetupSheet(
        isChange: isChange,
        onComplete: () {
          setState(() => _appLockEnabled = true);
          KultivarApp.sessionUnlocked = true;
          AppToast.show(
            context,
            isChange ? 'PIN updated' : 'App Lock enabled',
            type: ToastType.success,
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(title,
            style: AppTypography.labelSmall(context)
                .copyWith(letterSpacing: 1.2, color: context.colTextMuted)),
      );

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      ListTile(
        leading: _iconBox(icon, iconColor),
        title: Text(label, style: AppTypography.labelLarge(context)),
        subtitle: Text(subtitle, style: AppTypography.bodySmall(context)),
        trailing: Switch(
          value: value,
          activeThumbColor: AppColors.primary,
          onChanged: onChanged,
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: _iconBox(icon, iconColor),
        title: Text(label, style: AppTypography.labelLarge(context)),
        subtitle: Text(subtitle, style: AppTypography.bodySmall(context)),
        trailing: Icon(Icons.chevron_right,
            color: context.colTextMuted, size: 18),
        onTap: onTap,
      );

  Widget _iconBox(IconData icon, Color color) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(icon, color: color, size: 18),
      );

  /// Support inbox.  When this address changes, swap it here and in
  /// `lib/legal/privacy_policy.dart` + `terms_of_service.dart`.  A
  /// follow-up could lift this to `lib/config/support_contact.dart`
  /// and have the legal markdown templates interpolate, but it's not
  /// worth the indirection until we add a third surface.
  static const String _supportEmail = 'support@kultivar.io';

  Future<void> _emailDiagnostics(BuildContext context) async {
    // Open the user's default mail app with everything pre-filled:
    // To, Subject (with app version baked in for fast triage), and
    // the full crash log inline in the body.  Drops user friction
    // from "share -> pick app -> type address -> attach -> compose"
    // to a single tap; if their device has no mail handler at all
    // (rare on Android, possible on cheap tablets) we fall through
    // to the generic share path so they still have a way out.
    final log = await LocalCrashLog.readLog();
    if (!context.mounted) return;
    if (log.isEmpty) {
      AppToast.show(context, 'No crash log yet — nothing to send.',
          type: ToastType.info);
      return;
    }

    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    final subject = 'Kultivar crash log — v${info.version}+${info.buildNumber}';
    final body = 'Hi Kultivar support,\n\n'
        'Below is the diagnostic log from my device.  '
        '(Anything personal? Feel free to redact before sending.)\n\n'
        'App: ${info.appName} ${info.version} (build ${info.buildNumber})\n'
        '---\n\n'
        '$log';

    // mailto: encoding: spaces -> %20 (NOT +, which mail clients
    // interpret literally), CR/LF -> %0D%0A.  Uri.encodeComponent
    // is the safest standard-library handler.
    final mailto = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );

    try {
      final launched = await launchUrl(
        mailto,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        // No mail handler registered.  Drop down to the generic share
        // sheet so the user still has a one-tap path.  They'll have to
        // type support@kultivar.io themselves into whatever app they
        // pick, but the friction is better than a dead-end toast.
        AppToast.show(
          context,
          'No mail app found — opening the share sheet instead.',
          type: ToastType.info,
        );
        await _shareDiagnostics(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Email launch failed: $e', type: ToastType.error);
    }
  }

  Future<void> _shareDiagnostics(BuildContext context) async {
    // Bug fix v5 (real-device crash hunt): bundle the local crash
    // log and hand it off to the system share sheet so Marco can
    // send it to support without USB-tethering.
    final log = await LocalCrashLog.readLog();
    if (!context.mounted) return;
    if (log.isEmpty) {
      AppToast.show(context, 'No crash log yet — nothing to share.',
          type: ToastType.info);
      return;
    }
    final file = LocalCrashLog.logFile;
    try {
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/plain', name: 'kultivar-crash.log')],
          subject: 'Kultivar crash log',
          text: 'Crash log from Kultivar — captures Flutter framework + '
              'uncaught async errors since the last clear.',
        );
      } else {
        // Fallback: file resolution failed during install -- share text.
        await Share.share(log, subject: 'Kultivar crash log');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Share failed: $e', type: ToastType.error);
    }
  }

  Future<void> _exportBackup(
    BuildContext context,
    GrowRepository repo,
  ) async {
    try {
      await repo.exportBackup();
      if (!context.mounted) return;
      AppToast.show(context, 'Backup exported successfully');
      await _loadLastBackupTime();
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Export failed: $e', type: ToastType.error);
    }
  }

  /// F2 — Send the most recent auto-backup ZIP through the system share
  /// sheet so the user can route it into iCloud Drive, Google Drive,
  /// Dropbox, OneDrive, email, etc.  This is the practical alternative
  /// to bespoke cloud-provider integrations: iOS exposes "Save to Files"
  /// (which can target iCloud Drive) and Android exposes "Save to Drive"
  /// natively from the share sheet, with no extra OAuth or SDKs.
  ///
  /// If no backup exists yet, we trigger one first so the user always
  /// gets *something* to share — there's nothing worse than tapping a
  /// "share" button and getting a "no file" error.
  Future<void> _shareLatestBackup(BuildContext context) async {
    final repo = context.read<GrowRepository>();
    try {
      final dir = await AutoBackupService.backupDirectory();
      var files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.zip'))
          .toList()
        ..sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));

      // No backup yet — make one on the fly so the share is meaningful.
      if (files.isEmpty) {
        if (!context.mounted) return;
        AppToast.show(context, 'Creating backup…', type: ToastType.info);
        await repo.exportBackup();
        if (!mounted) return;
        await _loadLastBackupTime();
        files = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.zip'))
            .toList()
          ..sort((a, b) =>
              b.statSync().modified.compareTo(a.statSync().modified));
      }

      if (files.isEmpty) {
        if (!context.mounted) return;
        AppToast.show(context, 'No backup file available',
            type: ToastType.error);
        return;
      }

      final latest = files.first;
      await Share.shareXFiles(
        [XFile(latest.path, mimeType: 'application/zip')],
        subject: 'Kultivar backup',
        text:
            'Save to iCloud Drive / Google Drive / Dropbox to keep this off-device.',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Share failed: $e', type: ToastType.error);
    }
  }

  /// Explainer dialog describing where auto-backups live and how to make
  /// them cloud-synced.  The auto-backup file itself already sits in the
  /// app's Documents directory which is surfaced via the system Files app
  /// on both iOS and Android; from there the user can move/copy to any
  /// cloud destination without extra plumbing in the app.
  void _showAutoBackupInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colSurface2,
        title: const Text('Auto-Backup & Cloud Sync'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kultivar writes a fresh backup ZIP locally every '
                '${AutoBackupService.staleThresholdDays} days while you '
                'use the app. The three most recent are kept.',
                style: AppTypography.bodySmall(ctx),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('iCloud Drive (iOS / iPadOS)',
                  style: AppTypography.labelLarge(ctx)
                      .copyWith(color: AppColors.primary)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Open the Files app → Browse → "On My iPhone" → Kultivar → '
                'Kultivar Backups, then drag/move to "iCloud Drive". '
                'Future backups can be moved the same way, or use '
                '"Send to Cloud / Drive" above for a one-tap share.',
                style: AppTypography.bodySmall(ctx),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Google Drive / OneDrive (Android)',
                  style: AppTypography.labelLarge(ctx)
                      .copyWith(color: AppColors.primary)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Tap "Send to Cloud / Drive" above and pick "Save to Drive" '
                'or "OneDrive" from the share sheet. Android also includes '
                'Kultivar in Google\'s system Auto Backup if enabled.',
                style: AppTypography.bodySmall(ctx),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Encrypted backups (see toggle below) protect the ZIP with a '
                'passphrase before it leaves the device — important if you '
                'plan to store backups in any cloud provider.',
                style: AppTypography.bodySmall(ctx)
                    .copyWith(color: ctx.colTextMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _confirmImportBackup(
    BuildContext context,
    GrowRepository repo,
  ) {
    ConfirmSheet.show(
      context,
      icon: Icons.restore_rounded,
      iconColor: AppColors.secondary,
      title: 'Import Backup?',
      body: 'This will replace ALL current data with the '
          'contents of the backup. This cannot be undone.',
      confirmLabel: 'Import & Replace',
      confirmColor: AppColors.secondary,
      onConfirm: () async {
        final error = await repo.importBackup(
          onRequestPassphrase: () async {
            if (!context.mounted) return null;
            return _showPassphraseDialog(
              context,
              title: 'Encrypted Backup',
              body: 'This backup is protected. Enter the passphrase '
                  'you used when creating it.',
              submitLabel: 'Decrypt',
            );
          },
        );
        if (!context.mounted) return;
        if (error != null) {
          AppToast.show(context, error, type: ToastType.error);
        } else {
          AppToast.show(context, 'Backup restored successfully');
        }
      },
    );
  }

  Future<void> _reclaimStorage(
    BuildContext context,
    GrowRepository repo,
  ) async {
    final count = await repo.reclaimPhotoStorage();
    if (!context.mounted) return;
    AppToast.show(
      context,
      count == 0
          ? 'No orphan photos found'
          : '$count orphan photo${count == 1 ? '' : 's'} deleted',
      type: count == 0 ? ToastType.info : ToastType.success,
    );
  }

  void _confirmExitDemo(BuildContext context, GrowRepository repo) {
    ConfirmSheet.show(
      context,
      icon: Icons.delete_sweep_rounded,
      iconColor: AppColors.warning,
      title: 'Exit Demo Mode?',
      body: 'This removes all sample data and walks you through '
          'setting up your own journal.',
      confirmLabel: 'Clear & Start Fresh',
      confirmColor: AppColors.warning,
      onConfirm: () async {
        await DemoDataService.clear(repo);
        KultivarApp.isDemoModeNotifier.value = false;
        if (!context.mounted) return;
        AppToast.show(context, 'Demo data cleared', type: ToastType.info);
      },
    );
  }

  /// Resets the onboarding-complete flag and pushes the onboarding screen
  /// on top of the current navigator.  The user's actual data is NOT
  /// touched — they can replay the intro and then resume their grow.
  Future<void> _replayOnboarding(BuildContext context) async {
    await OnboardingService.reset();
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (innerCtx) => OnboardingScreen(
          // Re-mark complete and pop back to Settings.  Unlike the
          // first-run path (which routes into the shell), the replay
          // flow should leave the user exactly where they were.
          onComplete: () async {
            await OnboardingService.markComplete();
            if (innerCtx.mounted) Navigator.of(innerCtx).pop();
          },
        ),
      ),
    );
  }

  void _confirmClearData(BuildContext context, GrowRepository repo) {
    ConfirmSheet.show(
      context,
      icon: Icons.delete_forever_rounded,
      iconColor: AppColors.danger,
      title: 'Clear All Data?',
      body: 'Permanently deletes all plants, spaces, logs, '
          'notes and strains. This cannot be undone.',
      confirmLabel: 'Delete Everything',
      onConfirm: () async {
        await repo.clearAllData();
        if (!context.mounted) return;
        // Also clear the UI services that hold breadcrumbs of the
        // user's session — Search state, etc.  Done at the call site
        // (not inside the repo) so the data layer has no UI deps.
        context.read<SearchStateService>().reset();
        AppToast.show(context, 'All data cleared', type: ToastType.error);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsible settings group — a tappable header row that expands to reveal a
// cluster of related rows.  Keeps long sections (care reminders, exports,
// backup options) scannable by folding rarely-touched rows behind a single
// summary row.  Visually matches _actionTile: same icon box, typography, and
// trailing chevron — the chevron just rotates to point down when open.
// ─────────────────────────────────────────────────────────────────────────────

class _CollapsibleGroup extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  /// Optional short, locale-neutral status shown as a pill on the header
  /// (e.g. "8/8" for how many reminders are on).  Null hides the pill.
  final String? summary;
  final Color summaryColor;

  /// Body rows, already interleaved with Dividers by the caller so the
  /// expanded group is indistinguishable from the surrounding card.
  final List<Widget> children;

  const _CollapsibleGroup({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.children,
    this.summary,
    this.summaryColor = AppColors.primary,
  });

  @override
  State<_CollapsibleGroup> createState() => _CollapsibleGroupState();
}

class _CollapsibleGroupState extends State<_CollapsibleGroup> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `expanded` in the semantics node lets TalkBack / VoiceOver
        // announce "collapsed" / "expanded" so screen-reader users know
        // the row is a disclosure, not a navigation target.
        Semantics(
          button: true,
          expanded: _expanded,
          label: widget.label,
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 18),
            ),
            title: Text(widget.label, style: AppTypography.labelLarge(context)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.summary != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.summaryColor.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      widget.summary!,
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: widget.summaryColor),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right,
                      color: context.colTextMuted, size: 18),
                ),
              ],
            ),
            onTap: _toggle,
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0, width: double.infinity),
          secondChild: Column(children: widget.children),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm-PIN sheet — used when disabling App Lock to verify identity.
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmPinSheet extends StatefulWidget {
  @override
  State<_ConfirmPinSheet> createState() => _ConfirmPinSheetState();
}

class _ConfirmPinSheetState extends State<_ConfirmPinSheet>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 4;
  String _entered = '';
  String? _error;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_entered.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length == _pinLength) _verify();
  }

  void _onBack() {
    if (_entered.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(
        () => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify() async {
    final ok = await AppLockService.verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _entered = '';
        _error = 'Incorrect PIN';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colBorder,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          Text('Confirm PIN',
              style: AppTypography.headlineMedium(context)),
          const SizedBox(height: AppSpacing.xxs),
          Text('Enter your current PIN to continue',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted)),
          const SizedBox(height: AppSpacing.xl),

          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                  _shakeCtrl.isAnimating
                      ? 10 * (0.5 - _shakeAnim.value) * 2
                      : 0,
                  0),
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_pinLength, (i) {
                final filled = i < _entered.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: filled ? AppColors.primary : context.colBorder,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),

          SizedBox(
            height: 28,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 12)),
                  )
                : null,
          ),

          const SizedBox(height: AppSpacing.md),

          Column(children: [
            _row(context, ['1', '2', '3']),
            const SizedBox(height: AppSpacing.sm),
            _row(context, ['4', '5', '6']),
            const SizedBox(height: AppSpacing.sm),
            _row(context, ['7', '8', '9']),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 64, height: 64),
                _dBtn(context, '0'),
                GestureDetector(
                  onTap: _onBack,
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    child: Icon(Icons.backspace_outlined,
                        color: context.colTextMuted, size: 22),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: context.colTextSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext ctx, List<String> ds) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ds.map((d) => _dBtn(ctx, d)).toList(),
      );

  Widget _dBtn(BuildContext ctx, String d) => GestureDetector(
        onTap: () => _onDigit(d),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ctx.colSurface3,
            border: Border.all(color: ctx.colBorder),
          ),
          alignment: Alignment.center,
          child: Text(d,
              style: AppTypography.headlineMedium(ctx)
                  .copyWith(fontSize: 22)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Backup status banner
// ─────────────────────────────────────────────────────────────────────────────

class _BackupBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final VoidCallback? onTap;

  const _BackupBanner({
    required this.icon,
    required this.color,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UX5 — Currency picker quick-chip
// ─────────────────────────────────────────────────────────────────────────────

/// One-tap currency chip surfaced at the top of the currency picker sheet
/// for the four highest-frequency symbols (£/$/€/¥).  Selected state uses
/// the primary fill so the active currency is unmistakable at a glance.
class _CurrencyQuickChip extends StatelessWidget {
  final String symbol;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyQuickChip({
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.black : AppColors.harvested;
    final bg = selected
        ? AppColors.harvested
        : AppColors.harvested.withValues(alpha: 0.12);
    final border = selected
        ? AppColors.harvested
        : AppColors.harvested.withValues(alpha: 0.3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: border, width: selected ? 1.5 : 1),
        ),
        child: Text(
          symbol,
          style: AppTypography.headlineMedium(context).copyWith(
            color: fg,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
