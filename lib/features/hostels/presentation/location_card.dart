import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/launcher.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/feedback.dart';
import '../domain/hostel_models.dart';

/// Small non-interactive map (so it never fights the page scroll) with the address and a "Get directions" hand-off.
class LocationCard extends ConsumerWidget {
  const LocationCard({super.key, required this.name, required this.address, required this.location});
  final String name;
  final HostelAddress address;
  final GeoPoint location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final env = ref.watch(envProvider);
    final point = LatLng(location.latitude, location.longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: Radii.cardR,
          child: SizedBox(
            height: 180,
            child: Semantics(
              label: 'Map showing the location of $name',
              child: FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 14.5, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: env.osmUserAgent),
                  MarkerLayer(markers: [Marker(point: point, width: 44, height: 44, child: Icon(Icons.location_on_rounded, size: 44, color: c.primary))]),
                  const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(address.oneLine, style: context.text.bodyMedium),
        const SizedBox(height: 8),
        AppButton(
          label: 'Get directions',
          icon: Icons.directions_rounded,
          variant: AppButtonVariant.secondary,
          compact: true,
          onPressed: () async {
            final ok = await openMaps(location.latitude, location.longitude, label: name);
            if (!ok && context.mounted) showToast(context, "Couldn't open a maps app.", error: true);
          },
        ),
      ],
    );
  }
}
