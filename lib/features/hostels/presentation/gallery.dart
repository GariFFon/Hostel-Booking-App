import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/pressable.dart';
import '../domain/hostel_models.dart';

/// Photo header of the detail page: swipe through photos, "3 / 12" counter, tap to open full screen.
/// With no photos it shows a neutral tile at the same height, so the page never jumps.
class HostelGallery extends StatefulWidget {
  const HostelGallery({super.key, required this.photos, required this.name});
  final List<HostelMedia> photos;
  final String name;

  @override
  State<HostelGallery> createState() => _HostelGalleryState();
}

class _HostelGalleryState extends State<HostelGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return AspectRatio(
      aspectRatio: 1.2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            const AppImage(url: null)
          else
            PageView.builder(
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Semantics(
                button: true,
                onTapHint: 'Open photos full screen',
                child: GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => GalleryViewer(photos: photos, initial: i, name: widget.name),
                    ),
                  ),
                  child: AppImage(
                    url: photos[i].cardUrl,
                    semanticLabel: photos[i].altText ?? '${widget.name}, photo ${i + 1} of ${photos.length}',
                    cacheWidth: 900,
                  ),
                ),
              ),
            ),
          if (photos.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: Radii.pillR),
                child: Text('${_page + 1} / ${photos.length}', style: context.text.labelMedium?.copyWith(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen photo viewer: pinch to zoom, swipe between photos, close button always reachable.
class GalleryViewer extends StatefulWidget {
  const GalleryViewer({super.key, required this.photos, required this.initial, required this.name});
  final List<HostelMedia> photos;
  final int initial;
  final String name;

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  late final PageController _controller = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: AppImage(
                  url: widget.photos[i].fullUrl,
                  fit: BoxFit.contain,
                  semanticLabel: widget.photos[i].altText ?? '${widget.name}, photo ${i + 1}',
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => context.pop(),
                    semanticLabel: 'Close photos',
                    minSize: const Size(kMinTap, kMinTap),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text('${_page + 1} / ${widget.photos.length}', style: context.text.labelMedium?.copyWith(color: Colors.white)),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
