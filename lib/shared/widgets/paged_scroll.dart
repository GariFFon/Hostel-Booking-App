import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/paging/paged_notifier.dart';
import '../../core/theme/tokens.dart';
import 'app_button.dart';
import 'states.dart';

/// Pull-to-refresh + infinite scroll over a [PagedNotifier] state, with loading skeleton, empty state and error state built in.
class PagedScroll<T> extends StatelessWidget {
  const PagedScroll({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    required this.empty,
    this.loading,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.separator = 12,
    this.controller,
    this.bottomPadding = 0,
  });

  final AsyncValue<PageState<T>> value;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget empty;
  final Widget? loading;
  final Widget? header;
  final EdgeInsets padding;
  final double separator;
  final ScrollController? controller;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      loading: () => loading ?? const RowSkeletonList(),
      error: (e, _) => ErrorState(error: e, onRetry: () => onRefresh()),
      data: (page) {
        if (page.isEmpty) {
          return RefreshIndicator.adaptive(
            onRefresh: onRefresh,
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [?header, empty]),
                ),
              ),
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 600) onLoadMore();
            return false;
          },
          child: RefreshIndicator.adaptive(
            onRefresh: onRefresh,
            child: CustomScrollView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (header != null) SliverToBoxAdapter(child: header),
                SliverPadding(
                  padding: padding.copyWith(bottom: 0),
                  sliver: SliverList.separated(
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => SizedBox(height: separator),
                    itemBuilder: (context, i) => itemBuilder(context, page.items[i], i),
                  ),
                ),
                SliverToBoxAdapter(child: _Footer(page: page, onRetry: onLoadMore, bottom: padding.bottom + bottomPadding)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.page, required this.onRetry, required this.bottom});
  final PageState<dynamic> page;
  final VoidCallback onRetry;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    if (page.loadingMore) {
      return Padding(padding: EdgeInsets.fromLTRB(0, 20, 0, bottom), child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (page.moreError != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
        child: Column(
          children: [
            Text(errorText(page.moreError!), textAlign: TextAlign.center, style: context.text.bodySmall),
            const SizedBox(height: 8),
            AppButton(label: 'Try again', onPressed: onRetry, variant: AppButtonVariant.secondary, expand: false, compact: true),
          ],
        ),
      );
    }
    return SizedBox(height: bottom);
  }
}
