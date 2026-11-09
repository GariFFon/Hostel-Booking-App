import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/amenity_icon.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../application/hostel_providers.dart';
import '../data/search_params.dart';
import '../domain/enums.dart';

Future<void> showFiltersSheet(BuildContext context) => showAppSheet<void>(context, builder: (_) => const _FiltersSheet());

Future<void> showSortSheet(BuildContext context) => showAppSheet<void>(context, builder: (_) => const _SortSheet());

const int _maxRupees = 10000;
const int _step = 250;

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet();

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late SearchParams _draft = ref.read(searchParamsProvider);
  late RangeValues _price = RangeValues(
    ((_draft.minPricePaise ?? 0) / 100).clamp(0, _maxRupees).toDouble(),
    ((_draft.maxPricePaise ?? _maxRupees * 100) / 100).clamp(0, _maxRupees).toDouble(),
  );

  void _set(SearchParams p) => setState(() => _draft = p);

  void _apply() {
    final minP = _price.start.round();
    final maxP = _price.end.round();
    ref.read(searchParamsProvider.notifier).set(_draft.copyWith(
          minPricePaise: minP <= 0 ? null : minP * 100,
          maxPricePaise: maxP >= _maxRupees ? null : maxP * 100,
        ));
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _draft = _draft.clearFilters();
      _price = const RangeValues(0, _maxRupees * 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final amenities = ref.watch(amenitiesProvider);
    final lo = _price.start.round();
    final hi = _price.end.round();
    final priceLabel = (lo <= 0 && hi >= _maxRupees)
        ? 'Any price'
        : '${money(lo * 100)} – ${hi >= _maxRupees ? '${money(_maxRupees * 100)}+' : money(hi * 100)}';

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: t.titleMedium), const SizedBox(height: 10), child]),
        );

    return SheetFrame(
      title: 'Filters',
      footer: Row(
        children: [
          AppButton(label: 'Clear all', onPressed: _reset, variant: AppButtonVariant.secondary, expand: false),
          const SizedBox(width: 12),
          Expanded(child: AppButton(label: 'Show results', onPressed: _apply)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(
            'Price per night',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(priceLabel, style: t.bodyMedium?.tabular),
                RangeSlider(
                  values: _price,
                  min: 0,
                  max: _maxRupees.toDouble(),
                  divisions: _maxRupees ~/ _step,
                  labels: RangeLabels(money(lo * 100), hi >= _maxRupees ? '${money(_maxRupees * 100)}+' : money(hi * 100)),
                  onChanged: (v) => setState(() => _price = v),
                ),
              ],
            ),
          ),
          section(
            'Property',
            AppSegmented<PropertyType?>(
              semanticLabel: 'Property type',
              options: const [(value: null, label: 'Any'), (value: PropertyType.hostel, label: 'Hostel'), (value: PropertyType.pg, label: 'PG')],
              value: _draft.propertyType,
              onChanged: (v) => _set(_draft.copyWith(propertyType: v)),
            ),
          ),
          section(
            'Room type',
            AppSegmented<RoomKind?>(
              semanticLabel: 'Room type',
              options: const [(value: null, label: 'Any'), (value: RoomKind.dorm, label: 'Dorm bed'), (value: RoomKind.private, label: 'Private room')],
              value: _draft.roomKind,
              onChanged: (v) => _set(_draft.copyWith(roomKind: v)),
            ),
          ),
          section(
            'Suitable for',
            AppSegmented<String?>(
              semanticLabel: 'Suitable for',
              options: const [(value: null, label: 'Anyone'), (value: 'MALE', label: 'Men'), (value: 'FEMALE', label: 'Women')],
              value: _draft.gender,
              onChanged: (v) => _set(_draft.copyWith(gender: v)),
            ),
          ),
          section(
            'Guest rating',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in <(String, double?)>[('Any', null), ('3+', 3.0), ('4+', 4.0), ('4.5+', 4.5)])
                  ChoiceChip(
                    label: Text(label),
                    selected: _draft.minRating == value,
                    onSelected: (_) => _set(_draft.copyWith(minRating: value)),
                    showCheckmark: false,
                    selectedColor: c.accent,
                    backgroundColor: c.card,
                    side: BorderSide(color: _draft.minRating == value ? c.primary : c.border),
                    shape: const StadiumBorder(),
                    labelStyle: t.labelMedium?.copyWith(color: _draft.minRating == value ? c.accentForeground : c.foreground),
                  ),
              ],
            ),
          ),
          section(
            'Booking',
            MergeSemantics(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _draft.instantBook,
                onChanged: (v) => _set(_draft.copyWith(instantBook: v)),
                title: Text('Instant book only', style: t.bodyLarge),
                subtitle: Text('Confirm straight away, no waiting for the host.', style: t.bodySmall),
              ),
            ),
          ),
          section(
            'Amenities',
            amenities.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, _) => Text('Amenities could not be loaded.', style: t.bodySmall),
              data: (list) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in list)
                    FilterChip(
                      avatar: Icon(amenityIcon(a.code), size: 18, color: _draft.amenities.contains(a.code) ? c.accentForeground : c.mutedForeground),
                      label: Text(a.label),
                      selected: _draft.amenities.contains(a.code),
                      showCheckmark: false,
                      onSelected: (on) => _set(_draft.copyWith(amenities: on ? {..._draft.amenities, a.code} : ({..._draft.amenities}..remove(a.code)))),
                      selectedColor: c.accent,
                      backgroundColor: c.card,
                      side: BorderSide(color: _draft.amenities.contains(a.code) ? c.primary : c.border),
                      shape: const StadiumBorder(),
                      labelStyle: t.labelMedium?.copyWith(color: _draft.amenities.contains(a.code) ? c.accentForeground : c.foreground),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortSheet extends ConsumerWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final current = ref.watch(searchParamsProvider).sort;
    const options = [SearchSort.recommended, SearchSort.priceAsc, SearchSort.priceDesc, SearchSort.rating, SearchSort.newest];
    return SheetFrame(
      title: 'Sort by',
      child: RadioGroup<SearchSort>(
        groupValue: current,
        onChanged: (v) {
          if (v == null) return;
          ref.read(searchParamsProvider.notifier).update((p) => p.copyWith(sort: v));
          Navigator.of(context).pop();
        },
        child: Column(
          children: [
            for (final o in options)
              RadioListTile<SearchSort>.adaptive(
                value: o,
                contentPadding: EdgeInsets.zero,
                activeColor: c.primary,
                title: Text(o.label, style: context.text.bodyLarge),
              ),
          ],
        ),
      ),
    );
  }
}
