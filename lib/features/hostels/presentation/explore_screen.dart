import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/states.dart';
import '../application/hostel_providers.dart';
import '../data/search_params.dart';
import 'explore_map.dart';
import 'filters_sheet.dart';
import 'hostel_card.dart';
import 'search_sheet.dart';

enum _View { list, map }

/// The home tab: a search pill, filters, sort, and the results as a list or on a map.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  _View _view = _View.list;

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(searchParamsProvider);
    final results = ref.watch(searchResultsProvider);
    final total = results.value?.total;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(child: _SearchPill(params: params)),
                  const SizedBox(width: 10),
                  _FilterButton(count: params.filterCount),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 170,
                    child: AppSegmented<_View>(
                      semanticLabel: 'Results view',
                      options: const [(value: _View.list, label: 'List'), (value: _View.map, label: 'Map')],
                      value: _view,
                      onChanged: (v) => setState(() => _view = v),
                    ),
                  ),
                  const Spacer(),
                  _SortChip(sort: params.sort),
                ],
              ),
            ),
            Expanded(
              child: _view == _View.map
                  ? const ExploreMap()
                  : PagedScroll(
                      value: results,
                      loading: const CardSkeletonList(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      separator: 24,
                      header: _ListHeader(params: params, total: total),
                      onLoadMore: () => ref.read(searchResultsProvider.notifier).loadMore(),
                      onRefresh: () async {
                        ref.invalidate(searchResultsProvider);
                        await ref.read(searchResultsProvider.future);
                      },
                      empty: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No stays match',
                        message: params.hasDates
                            ? 'Nothing is free for those dates and guests. Try other dates or fewer filters.'
                            : 'Try a different destination or remove some filters.',
                        actionLabel: params.filterCount > 0 ? 'Clear filters' : (params.destination != null || params.hasDates ? 'Clear search' : null),
                        onAction: () => ref.read(searchParamsProvider.notifier).update((p) => params.filterCount > 0 ? p.clearFilters() : const SearchParams()),
                      ),
                      itemBuilder: (context, h, _) => HostelCardView(hostel: h, checkIn: params.checkIn, checkOut: params.checkOut, guests: params.hasDates ? params.guests : null),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPill extends ConsumerWidget {
  const _SearchPill({required this.params});
  final SearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final active = params.destination != null || params.hasDates || params.guests > 1;
    return Pressable(
      onTap: () => showSearchSheet(context),
      scale: 0.985,
      semanticLabel: 'Search. ${params.destination ?? 'Anywhere'}, ${stayLabel(params)}',
      child: Container(
        height: 56,
        padding: const EdgeInsets.only(left: 16, right: 4),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: c.foreground.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: c.foreground, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(params.destination ?? 'Where to?', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  Text(stayLabel(params), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ],
              ),
            ),
            if (active)
              Pressable(
                onTap: () => ref.read(searchParamsProvider.notifier).update((p) => p.copyWith(q: null, city: null, checkIn: null, checkOut: null, guests: 1)),
                semanticLabel: 'Clear search',
                minSize: const Size(kMinTap, kMinTap),
                scale: 0.9,
                child: Icon(Icons.close_rounded, size: 20, color: c.mutedForeground),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => showFiltersSheet(context),
      semanticLabel: count == 0 ? 'Filters' : 'Filters, $count active',
      scale: 0.95,
      child: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: c.primary,
        textColor: c.onPrimary,
        offset: const Offset(-4, 4),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: count > 0 ? c.accent : c.card, borderRadius: Radii.cardR, border: Border.all(color: count > 0 ? c.primary : c.border)),
          child: Icon(Icons.tune_rounded, color: count > 0 ? c.accentForeground : c.foreground, size: 22),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.sort});
  final SearchSort sort;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => showSortSheet(context),
      minSize: const Size(kMinTap, kMinTap),
      semanticLabel: 'Sort: ${sort.label}',
      scale: 0.95,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert_rounded, size: 18, color: c.mutedForeground),
          const SizedBox(width: 4),
          Text(sort.label, style: context.text.labelMedium?.copyWith(color: c.foreground)),
        ],
      ),
    );
  }
}

class _ListHeader extends ConsumerWidget {
  const _ListHeader({required this.params, required this.total});
  final SearchParams params;
  final int? total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final c = context.colors;
    final cities = ref.watch(citiesProvider).value ?? const [];
    final showCities = params.destination == null && cities.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCities) ...[
            Text('Popular destinations', style: t.labelMedium?.copyWith(color: c.mutedForeground)),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: cities.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final city = cities[i];
                  return ActionChip(
                    label: Text('${city.city} · ${count(city.count)}'),
                    onPressed: () => ref.read(searchParamsProvider.notifier).update((p) => p.copyWith(city: city.city, q: null)),
                    backgroundColor: c.card,
                    side: BorderSide(color: c.border),
                    shape: const StadiumBorder(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (total != null) Text(plural(total!, 'stay'), style: t.bodySmall?.tabular),
        ],
      ),
    );
  }
}
