import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/form_tiles.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheet.dart';
import '../application/hostel_providers.dart';

Future<void> showSearchSheet(BuildContext context) => showAppSheet<void>(context, builder: (_) => const _SearchSheet());

/// Where / when / how many. Applies to the Explore list as one change, so the list restarts once, not three times.
class _SearchSheet extends ConsumerStatefulWidget {
  const _SearchSheet();

  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  late final TextEditingController _text;
  Timer? _debounce;
  String _query = '';
  String? _pickedCity;
  DateTime? _checkIn;
  DateTime? _checkOut;
  late int _guests;

  @override
  void initState() {
    super.initState();
    final p = ref.read(searchParamsProvider);
    _text = TextEditingController(text: p.destination ?? '');
    _pickedCity = p.city;
    _checkIn = p.checkIn;
    _checkOut = p.checkOut;
    _guests = p.guests;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onTyped(String v) {
    _pickedCity = null;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _query = v.trim());
    });
    setState(() {});
  }

  void _apply() {
    final text = _text.text.trim();
    ref.read(searchParamsProvider.notifier).update((p) => p.copyWith(
          city: _pickedCity != null && _pickedCity == text ? text : null,
          q: _pickedCity == null && text.isNotEmpty ? text : null,
          checkIn: _checkIn,
          checkOut: _checkOut,
          guests: _guests,
        ));
    Navigator.of(context).pop();
  }

  void _clear() {
    ref.read(searchParamsProvider.notifier).update((p) => p.copyWith(q: null, city: null, checkIn: null, checkOut: null, guests: 1));
    Navigator.of(context).pop();
  }

  Future<void> _pickDates() async {
    final now = today();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _checkIn != null && _checkOut != null ? DateTimeRange(start: _checkIn!, end: _checkOut!) : null,
      helpText: 'Select your stay',
      saveText: 'Done',
    );
    if (range == null) return;
    setState(() {
      _checkIn = dateOnly(range.start);
      _checkOut = range.end.isAfter(range.start) ? dateOnly(range.end) : dateOnly(range.start).add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final suggestions = _query.length >= 2 ? ref.watch(suggestionsProvider(_query)) : null;
    final cities = ref.watch(citiesProvider);

    return SheetFrame(
      title: 'Find a stay',
      footer: Row(
        children: [
          AppButton(label: 'Clear', onPressed: _clear, variant: AppButtonVariant.secondary, expand: false),
          const SizedBox(width: 12),
          Expanded(child: AppButton(label: 'Search', icon: Icons.search_rounded, onPressed: _apply)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Where to?',
            hint: 'City, area or property',
            controller: _text,
            prefixIcon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            onChanged: _onTyped,
            onSubmitted: (_) => _apply(),
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          if (suggestions != null)
            suggestions.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator(minHeight: 2)),
              error: (_, _) => Text('Suggestions are unavailable right now. You can still search.', style: t.bodySmall),
              data: (s) => s.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('No matches for "$_query". Search anyway to see nearby stays.', style: t.bodySmall))
                  : Column(
                      children: [
                        for (final city in s.cities)
                          _SuggestionRow(
                            icon: Icons.location_city_rounded,
                            title: city.city,
                            subtitle: '${city.state.isEmpty ? '' : '${city.state} · '}${plural(city.count, 'stay')}',
                            onTap: () => setState(() {
                              _text.text = city.city;
                              _text.selection = TextSelection.collapsed(offset: city.city.length);
                              _pickedCity = city.city;
                              _query = '';
                            }),
                          ),
                        for (final h in s.hostels)
                          _SuggestionRow(
                            icon: Icons.night_shelter_outlined,
                            title: h.name,
                            subtitle: h.city,
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push(Routes.hostel(h.slug, checkIn: _checkIn, checkOut: _checkOut, guests: _guests));
                            },
                          ),
                      ],
                    ),
            )
          else
            cities.maybeWhen(
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Popular destinations', style: t.labelMedium?.copyWith(color: c.mutedForeground)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final city in list.take(8))
                              ActionChip(
                                label: Text(city.city),
                                onPressed: () => setState(() {
                                  _text.text = city.city;
                                  _pickedCity = city.city;
                                }),
                                backgroundColor: c.card,
                                side: BorderSide(color: c.border),
                                shape: const StadiumBorder(),
                              ),
                          ],
                        ),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          const SizedBox(height: 20),
          TileRow(
            icon: Icons.calendar_month_outlined,
            label: 'Dates',
            value: _checkIn != null && _checkOut != null ? '${fmtRange(_checkIn!, _checkOut!)} · ${plural(nightsBetween(_checkIn!, _checkOut!), 'night')}' : 'Add dates',
            onTap: _pickDates,
            trailing: _checkIn == null
                ? null
                : Pressable(
                    onTap: () => setState(() {
                      _checkIn = null;
                      _checkOut = null;
                    }),
                    semanticLabel: 'Clear dates',
                    minSize: const Size(kMinTap, kMinTap),
                    child: Icon(Icons.close_rounded, size: 20, color: c.mutedForeground),
                  ),
          ),
          const SizedBox(height: 10),
          TileRow(
            icon: Icons.group_outlined,
            label: 'Guests',
            value: plural(_guests, 'guest'),
            trailing: CountStepper(value: _guests, min: 1, max: 30, onChanged: (v) => setState(() => _guests = v), noun: 'guests'),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.muted, borderRadius: Radii.baseR),
              child: Icon(icon, size: 20, color: c.mutedForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
