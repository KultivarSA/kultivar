import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/strain_library.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain.dart';
import '../repository/grow_repository.dart';
import '../services/search_state_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_state_art.dart';
import '../widgets/strain_preview_sheet.dart';
import 'plant_detail_screen.dart';
import 'space_detail_screen.dart' as space_screen;
import 'strain_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _ctrl;
  late String _query;
  late String _filter; // all | plants | notes | strains | spaces

  /// Debounces the keystroke → filter pipeline.  At 200 ms the user has
  /// usually committed to a partial word, so we wait that long before
  /// re-running [_matchPlants] / [_matchNotes] / etc. — which iterate
  /// every plant + every note + every strain in the library.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Read the previously-used query + filter from the Provider-scoped
    // service.  Survives pop/push within an app session; cleared on
    // [GrowRepository.clearAllData].  See SearchStateService for the
    // lifetime rationale.
    final state = context.read<SearchStateService>();
    _query = state.query;
    _filter = state.filter;
    _ctrl = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Updates `_query` from a TextField keystroke.  Throttled to 200 ms so
  /// fast typing doesn't trigger a full repository scan per character.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _query = value.toLowerCase();
        context.read<SearchStateService>().setQuery(_query);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    final plantById = {for (final p in repo.plants) p.id: p};
    final plants = _matchPlants(repo.plants);
    final notes = _matchNotes(repo.notes, plantById);
    final strains = _matchStrains(repo.strains);
    final catalogStrains = _matchCatalogStrains(repo);
    final spaces = _matchSpaces(repo.growSpaces);

    final showPlants = _filter == 'all' || _filter == 'plants';
    final showNotes = _filter == 'all' || _filter == 'notes';
    final showStrains = _filter == 'all' || _filter == 'strains';
    final showSpaces = _filter == 'all' || _filter == 'spaces';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: AppTypography.bodyLarge(context)
              .copyWith(color: context.colTextPrimary),
          decoration: InputDecoration(
            hintText: 'Search plants, notes, strains, #tags…',
            hintStyle: AppTypography.bodyLarge(context)
                .copyWith(color: context.colTextMuted),
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
          onChanged: _onQueryChanged,
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: context.colTextMuted),
              tooltip: 'Clear search',
              onPressed: () {
                _ctrl.clear();
                _debounce?.cancel(); // bypass debounce — explicit action
                setState(() {
                  _query = '';
                  context.read<SearchStateService>().setQuery('');
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips — counts shown only while a query is active.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                _chip('All', 'all',
                    count: plants.length +
                        notes.length +
                        strains.length +
                        catalogStrains.length +
                        spaces.length),
                const SizedBox(width: AppSpacing.xs),
                _chip('Plants', 'plants', count: plants.length),
                const SizedBox(width: AppSpacing.xs),
                _chip('Notes', 'notes', count: notes.length),
                const SizedBox(width: AppSpacing.xs),
                _chip('Spaces', 'spaces', count: spaces.length),
                const SizedBox(width: AppSpacing.xs),
                _chip('Strains', 'strains',
                    count: strains.length + catalogStrains.length),
              ],
            ),
          ),

          Expanded(
            child: _query.isEmpty
                ? const EmptyState(
                    art: EmptyArt.search,
                    title: 'Search Everything',
                    subtitle: 'Start typing to find plants,\nnotes and strains.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    children: [
                      if (showPlants && plants.isNotEmpty) ...[
                        _sectionHeader('Plants', plants.length),
                        ...plants.map((p) => _plantTile(context, p)),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (showNotes && notes.isNotEmpty) ...[
                        _sectionHeader('Notes', notes.length),
                        ...notes.map(
                            (entry) => _noteTile(context, entry.$1, entry.$2)),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (showSpaces && spaces.isNotEmpty) ...[
                        _sectionHeader('Spaces', spaces.length),
                        ...spaces.map((s) => _spaceTile(context, s, repo)),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (showStrains &&
                          (strains.isNotEmpty ||
                              catalogStrains.isNotEmpty)) ...[
                        _sectionHeader('Strains',
                            strains.length + catalogStrains.length),
                        if (strains.isNotEmpty) ...[
                          ...strains.map((s) => _strainTile(context, s)),
                        ],
                        if (catalogStrains.isNotEmpty) ...[
                          if (strains.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 4, bottom: 2),
                              child: Text('Strain catalog',
                                  style: AppTypography.labelSmall(context)
                                      .copyWith(
                                          color: context.colTextMuted,
                                          letterSpacing: 0.4)),
                            ),
                          ...catalogStrains
                              .take(8)
                              .map((s) => _catalogStrainTile(context, s,
                                  repo)),
                          if (catalogStrains.length > 8)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xxs),
                              child: Text(
                                '+ ${catalogStrains.length - 8} more in strain library',
                                style: AppTypography.bodySmall(context)
                                    .copyWith(color: context.colTextMuted),
                              ),
                            ),
                        ],
                      ],
                      // Empty state — show whenever the CURRENT filter has
                      // zero visible results, not just when every category
                      // is empty.  Without this, picking "Spaces" while
                      // your query only matches notes shows a blank
                      // screen with no explanation.
                      if (_isFilteredEmpty(plants, notes, spaces,
                          strains, catalogStrains))
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xl),
                          child: EmptyState(
                            art: EmptyArt.search,
                            title: 'No Results',
                            subtitle: _filter == 'all'
                                ? 'Nothing matched "$_query".\nTry a different search term.'
                                : 'Nothing in ${_filterLabel(_filter)} matched "$_query".\nTry "All" to broaden the search.',
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Highlight helper ──────────────────────────
  //
  // Returns an InlineSpan that bolds the first occurrence of [_query] inside
  // [text].  Falls back to a plain TextSpan when the query is empty or absent.

  InlineSpan _hl(String text, TextStyle style) {
    if (_query.isEmpty) return TextSpan(text: text, style: style);
    final lower = text.toLowerCase();
    final idx = lower.indexOf(_query);
    if (idx < 0) return TextSpan(text: text, style: style);
    final boldStyle = style.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    );
    return TextSpan(children: [
      if (idx > 0) TextSpan(text: text.substring(0, idx), style: style),
      TextSpan(text: text.substring(idx, idx + _query.length), style: boldStyle),
      if (idx + _query.length < text.length)
        TextSpan(text: text.substring(idx + _query.length), style: style),
    ]);
  }

  // ── Helpers ───────────────────────────────────

  String _formatNoteDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Filter-aware empty-state ──────────────────

  /// Returns true when the active filter would render nothing — used to
  /// drive the "no results" empty state.  Only meaningful while a query
  /// is active (callers gate on `_query.isEmpty` separately).
  bool _isFilteredEmpty(
    List<Plant> plants,
    List<(PlantNote, Plant?)> notes,
    List<GrowSpace> spaces,
    List<Strain> strains,
    List<BuiltInStrain> catalogStrains,
  ) {
    if (_query.isEmpty) return false;
    switch (_filter) {
      case 'plants':
        return plants.isEmpty;
      case 'notes':
        return notes.isEmpty;
      case 'spaces':
        return spaces.isEmpty;
      case 'strains':
        return strains.isEmpty && catalogStrains.isEmpty;
      case 'all':
      default:
        return plants.isEmpty &&
            notes.isEmpty &&
            spaces.isEmpty &&
            strains.isEmpty &&
            catalogStrains.isEmpty;
    }
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'plants':
        return 'Plants';
      case 'notes':
        return 'Notes';
      case 'spaces':
        return 'Spaces';
      case 'strains':
        return 'Strains';
      default:
        return 'All';
    }
  }

  // ── Filters ───────────────────────────────────

  /// F8 — when the query starts with `#` we treat it as a tag-only
  /// search.  Normalises identically to TagEditor (lower-case, strip
  /// `#`) so #Mother and #mother and mother all match.  The remaining
  /// term is matched against the plant's [Plant.tags] / note's
  /// [PlantNote.tags] sets via equality, not substring — keeps
  /// `#sog` from accidentally matching `#sog-trial-2`.
  bool get _isTagQuery => _query.startsWith('#');
  String get _tagToken =>
      _query.startsWith('#') ? _query.substring(1).toLowerCase() : '';

  List<Plant> _matchPlants(List<Plant> all) {
    if (_query.isEmpty) return [];
    if (_isTagQuery) {
      final tok = _tagToken;
      if (tok.isEmpty) return [];
      return all.where((p) => p.tags.any((t) => t.contains(tok))).toList();
    }
    return all
        .where((p) =>
            p.name.toLowerCase().contains(_query) ||
            p.strain.toLowerCase().contains(_query) ||
            (p.phenotypeTag?.toLowerCase().contains(_query) ?? false) ||
            p.statusLabel.toLowerCase().contains(_query) ||
            // Plain (non-#) queries fall through to tag content too —
            // typing "mother" finds the #mother-tagged plant without
            // forcing users to remember the leading #.
            p.tags.any((t) => t.contains(_query)))
        .toList();
  }

  List<(PlantNote, Plant?)> _matchNotes(
      List<PlantNote> all, Map<String, Plant> plantById) {
    if (_query.isEmpty) return [];
    if (_isTagQuery) {
      final tok = _tagToken;
      if (tok.isEmpty) return [];
      return all
          .where((n) => n.tags.any((t) => t.contains(tok)))
          .map((n) => (n, plantById[n.plantId]))
          .toList();
    }
    return all
        .where((n) =>
            n.content.toLowerCase().contains(_query) ||
            n.categoryLabel.toLowerCase().contains(_query) ||
            (n.issueName?.toLowerCase().contains(_query) ?? false) ||
            n.tags.any((t) => t.contains(_query)))
        .map((n) => (n, plantById[n.plantId]))
        .toList();
  }

  List<Strain> _matchStrains(List<Strain> all) => _query.isEmpty
      ? []
      : all
          .where((s) =>
              s.name.toLowerCase().contains(_query) ||
              s.genetics.toLowerCase().contains(_query) ||
              (s.breeder?.toLowerCase().contains(_query) ?? false) ||
              s.type.toLowerCase().contains(_query))
          .toList();

  /// Searches the built-in catalog.  Excludes entries already saved in the
  /// user's library (they appear in [_matchStrains] instead).
  List<BuiltInStrain> _matchCatalogStrains(GrowRepository repo) {
    if (_query.isEmpty) return [];
    final savedNames =
        repo.strains.map((s) => s.name.toLowerCase()).toSet();
    return kStrainLibrary
        .where((s) =>
            !savedNames.contains(s.name.toLowerCase()) &&
            (s.name.toLowerCase().contains(_query) ||
                (s.lineage?.toLowerCase().contains(_query) ?? false) ||
                (s.breeder?.toLowerCase().contains(_query) ?? false) ||
                s.type.toLowerCase().contains(_query)))
        .toList();
  }

  List<GrowSpace> _matchSpaces(List<GrowSpace> all) => _query.isEmpty
      ? []
      : all
          .where((s) =>
              s.name.toLowerCase().contains(_query) ||
              s.type.toLowerCase().contains(_query) ||
              (s.notes?.toLowerCase().contains(_query) ?? false))
          .toList();

  // ── Tile builders ─────────────────────────────

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(children: [
        Text(label, style: AppTypography.headlineSmall(context)),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.colSurface3,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text('$count', style: AppTypography.labelSmall(context)),
        ),
      ]),
    );
  }

  Widget _plantTile(BuildContext context, Plant plant) {
    final color = AppColors.statusColor(plant.statusLabel);
    final nameStyle = AppTypography.labelLarge(context);
    final subStyle = AppTypography.bodySmall(context);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: plant))),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(_hl(plant.name, nameStyle)),
                if (plant.strain.isNotEmpty)
                  Text.rich(_hl(plant.strain, subStyle)),
              ],
            ),
          ),
          Text(plant.statusLabel,
              style: subStyle.copyWith(color: color)),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, size: 16, color: context.colTextMuted),
        ]),
      ),
    );
  }

  Widget _noteTile(BuildContext context, PlantNote note, Plant? plant) {
    final color = note.categoryColor;
    final contentStyle = AppTypography.bodyMedium(context);
    return GestureDetector(
      onTap: plant != null
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PlantDetailScreen(plant: plant)))
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(note.categoryIcon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(note.categoryLabel,
                  style:
                      AppTypography.labelSmall(context).copyWith(color: color)),
              const Spacer(),
              if (plant != null) ...[
                Icon(Icons.yard_rounded,
                    size: 11, color: context.colTextMuted),
                const SizedBox(width: 3),
                Text(plant.name,
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted)),
              ],
            ]),
            const SizedBox(height: AppSpacing.xxs),
            Text.rich(
              TextSpan(children: [_hl(note.content, contentStyle)]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _formatNoteDate(note.createdAt),
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strainTile(BuildContext context, Strain strain) {
    final nameStyle = AppTypography.labelLarge(context);
    final subStyle = AppTypography.bodySmall(context);
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => StrainDetailScreen(strain: strain))),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colBorder),
        ),
        child: Row(children: [
          Icon(Icons.science, size: 16, color: context.colTextMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(_hl(strain.name, nameStyle)),
                if (strain.genetics.isNotEmpty)
                  Text.rich(
                    TextSpan(children: [_hl(strain.genetics, subStyle)]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(strain.type, style: subStyle),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, size: 16, color: context.colTextMuted),
        ]),
      ),
    );
  }

  Widget _catalogStrainTile(
      BuildContext context, BuiltInStrain strain, GrowRepository repo) {
    final isSaved =
        repo.strains.any((s) => s.name.toLowerCase() == strain.name.toLowerCase());
    final nameStyle = AppTypography.labelLarge(context);
    final subStyle = AppTypography.bodySmall(context);
    final typeColor = strain.type == 'Indica'
        ? AppColors.curing
        : strain.type == 'Sativa'
            ? AppColors.harvested
            : AppColors.growing;
    return GestureDetector(
      onTap: () => StrainPreviewSheet.show(
        context,
        strain,
        isSaved: isSaved,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: typeColor.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(Icons.science_rounded, color: typeColor, size: 14),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(_hl(strain.name, nameStyle)),
                if (strain.lineage != null)
                  Text.rich(
                    TextSpan(children: [_hl(strain.lineage!, subStyle)]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(strain.type,
                  style: subStyle.copyWith(color: typeColor, fontSize: 10)),
              if (isSaved)
                Text('Saved',
                    style: subStyle.copyWith(
                        color: AppColors.growing, fontSize: 9)),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, size: 16, color: context.colTextMuted),
        ]),
      ),
    );
  }

  Widget _spaceTile(
      BuildContext context, GrowSpace space, GrowRepository repo) {
    final activePlants = repo.plants
        .where((p) => p.growSpaceId == space.id && !p.isArchived)
        .length;
    final nameStyle = AppTypography.labelLarge(context);
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  space_screen.SpaceDetailScreen(space: space))),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(Icons.home_work_rounded,
                color: AppColors.secondary, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(_hl(space.name, nameStyle)),
                Text(
                  '$activePlants active ${activePlants == 1 ? 'plant' : 'plants'} · ${space.type}',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: context.colTextMuted),
        ]),
      ),
    );
  }

  Widget _chip(String label, String value, {int count = 0}) {
    final selected = _filter == value;
    // Show count badge only when a query is active.
    final showCount = _query.isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() {
        _filter = value;
        context.read<SearchStateService>().setFilter(value);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.colSurface3,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
              color: selected ? AppColors.primary : context.colBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.labelLarge(context).copyWith(
                    color:
                        selected ? Colors.black : context.colTextSecondary)),
            if (showCount) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.black.withValues(alpha: 0.18)
                      : context.colSurface1,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.labelSmall(context).copyWith(
                    color: selected
                        ? Colors.black
                        : context.colTextMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
