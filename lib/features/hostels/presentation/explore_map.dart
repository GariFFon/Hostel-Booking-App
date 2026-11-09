import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/format/format.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/pressable.dart';
import '../application/hostel_providers.dart';
import '../domain/hostel_models.dart';

const LatLng _india = LatLng(21.5, 79.0);

/// Map view of the current search: price pills for every stay inside the visible area (refetched after the camera settles),
/// OpenStreetMap tiles with attribution, a card for the tapped marker.
class ExploreMap extends ConsumerStatefulWidget {
  const ExploreMap({super.key});

  @override
  ConsumerState<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends ConsumerState<ExploreMap> {
  final MapController _controller = MapController();
  Timer? _settle;
  String? _bbox;
  String? _selectedId;
  bool _ready = false;
  bool _fitted = false;

  @override
  void dispose() {
    _settle?.cancel();
    _controller.dispose();
    return super.dispose();
  }

  void _readBounds() {
    final b = _controller.camera.visibleBounds;
    final box = '${b.west.toStringAsFixed(3)},${b.south.toStringAsFixed(3)},${b.east.toStringAsFixed(3)},${b.north.toStringAsFixed(3)}';
    if (box != _bbox && mounted) setState(() => _bbox = box);
  }

  void _fitTo(List<HostelCard> items) {
    final pts = [for (final h in items) if (h.location != null) LatLng(h.location!.latitude, h.location!.longitude)];
    if (pts.isEmpty || !_ready) return;
    _fitted = true;
    if (pts.length == 1) {
      _controller.move(pts.first, 13);
    } else {
      _controller.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(56), maxZoom: 14));
    }
    _readBounds();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final env = ref.watch(envProvider);
    final params = ref.watch(searchParamsProvider);
    final firstPage = ref.watch(searchResultsProvider).value?.items ?? const <HostelCard>[];

    ref.listen(searchParamsProvider, (_, _) => _fitted = false);
    ref.listen(searchResultsProvider, (_, next) {
      final items = next.value?.items;
      if (!_fitted && items != null && items.isNotEmpty) _fitTo(items);
    });

    final markers = _bbox == null ? const AsyncData<List<MapMarker>>([]) : ref.watch(mapMarkersProvider(MapQuery(params, _bbox!)));
    final list = markers.value ?? const <MapMarker>[];
    final selected = list.where((m) => m.id == _selectedId).firstOrNull;
    final selectedCard = selected == null ? null : firstPage.where((h) => h.id == selected.id).firstOrNull;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _india,
            initialZoom: 4.6,
            minZoom: 3,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              _ready = true;
              if (firstPage.isNotEmpty) {
                _fitTo(firstPage);
              } else {
                _readBounds();
              }
            },
            onTap: (_, _) => setState(() => _selectedId = null),
            onPositionChanged: (camera, hasGesture) {
              _settle?.cancel();
              _settle = Timer(const Duration(milliseconds: 450), _readBounds);
            },
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: env.osmUserAgent, maxNativeZoom: 19),
            MarkerLayer(
              markers: [
                for (final m in list)
                  Marker(
                    point: LatLng(m.latitude, m.longitude),
                    width: 92,
                    height: 40,
                    child: _PricePin(marker: m, selected: m.id == _selectedId, onTap: () => setState(() => _selectedId = m.id)),
                  ),
              ],
            ),
            const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
          ],
        ),
        if (markers.isLoading)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
        if (markers.hasError)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: _MapNote(icon: Icons.cloud_off_rounded, text: "Couldn't load stays for this area.", onRetry: () => ref.invalidate(mapMarkersProvider)),
          )
        else if (!markers.isLoading && _bbox != null && list.isEmpty)
          const Positioned(top: 8, left: 16, right: 16, child: _MapNote(icon: Icons.zoom_out_map_rounded, text: 'No stays in this area. Move or zoom out the map.')),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _SelectedCard(marker: selected, card: selectedCard, onOpen: () => context.push(Routes.hostel(selected.slug, checkIn: params.checkIn, checkOut: params.checkOut, guests: params.hasDates ? params.guests : null))),
          ),
        Positioned(
          right: 12,
          bottom: selected != null ? 124 : 28,
          child: Pressable(
            semanticLabel: 'Show all results',
            minSize: const Size(kMinTap, kMinTap),
            onTap: () => _fitTo(firstPage),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.border), boxShadow: [BoxShadow(color: c.foreground.withValues(alpha: 0.12), blurRadius: 8)]),
              child: Icon(Icons.zoom_out_map_rounded, color: c.foreground),
            ),
          ),
        ),
      ],
    );
  }
}

class _PricePin extends StatelessWidget {
  const _PricePin({required this.marker, required this.selected, required this.onTap});
  final MapMarker marker;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = marker.fromPricePaise == null ? marker.name : money(marker.fromPricePaise);
    return Pressable(
      onTap: onTap,
      semanticLabel: '${marker.name}, ${marker.fromPricePaise == null ? 'no price' : '${money(marker.fromPricePaise)} per night'}',
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: Motion.of(context, Motion.enter),
        curve: Motion.easeOut,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? c.primary : c.card,
            borderRadius: Radii.pillR,
            border: Border.all(color: selected ? c.primary : c.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: selected ? c.onPrimary : c.foreground, fontWeight: FontWeight.w700).tabular),
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.marker, required this.card, required this.onOpen});
  final MapMarker marker;
  final HostelCard? card;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Pressable(
      onTap: onOpen,
      scale: 0.985,
      semanticLabel: 'Open ${marker.name}',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.card, borderRadius: Radii.cardR, border: Border.all(color: c.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 16, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 84, height: 84, child: AppImage(url: card?.coverUrl, cacheWidth: 168))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(marker.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [InfoPill(marker.propertyType.label), RatingBadge(rating: marker.avgRating, reviews: marker.reviewCount)]),
                  const SizedBox(height: 4),
                  Text(marker.fromPricePaise == null ? 'No rooms listed yet' : '${money(marker.fromPricePaise)} per night', style: t.labelMedium?.tabular),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _MapNote extends StatelessWidget {
  const _MapNote({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.card, borderRadius: Radii.baseR, border: Border.all(color: c.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.mutedForeground),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.text.bodySmall?.copyWith(color: c.foreground))),
          if (onRetry != null) Pressable(onTap: onRetry, minSize: const Size(kMinTap, kMinTap), child: Text('Retry', style: context.text.labelMedium?.copyWith(color: c.primary))),
        ],
      ),
    );
  }
}
