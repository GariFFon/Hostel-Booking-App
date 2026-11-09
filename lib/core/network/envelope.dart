/// The `{ data, meta }` success envelope of the backend.
class Envelope {
  const Envelope({required this.data, this.requestId, this.nextCursor, this.total});

  final Object? data;
  final String? requestId;
  final String? nextCursor;
  final int? total;

  factory Envelope.fromBody(Object? body) {
    if (body is Map<String, dynamic>) {
      final meta = body['meta'];
      return Envelope(
        data: body['data'],
        requestId: meta is Map ? meta['requestId'] as String? : null,
        nextCursor: meta is Map ? meta['nextCursor'] as String? : null,
        total: meta is Map && meta['total'] is num ? (meta['total'] as num).toInt() : null,
      );
    }
    return const Envelope(data: null);
  }
}

/// One page of a keyset-paginated list. Pass [nextCursor] back with the same filters to continue.
class Paged<T> {
  const Paged({required this.items, this.nextCursor, this.total});

  final List<T> items;
  final String? nextCursor;
  final int? total;

  bool get hasMore => nextCursor != null;

  static Paged<T> empty<T>() => Paged<T>(items: <T>[]);
}

typedef JsonMap = Map<String, dynamic>;

JsonMap asMap(Object? v) => v is Map<String, dynamic> ? v : (v is Map ? v.cast<String, dynamic>() : <String, dynamic>{});

List<JsonMap> asList(Object? v) => v is List ? v.map(asMap).toList() : <JsonMap>[];
