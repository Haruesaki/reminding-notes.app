import '../../features/explorer/domain/entities/entities.dart';

class DisplayOrderSorter {
  /// Mengurutkan entri dalam satu folder sesuai PRD 6.9:
  /// 1. Folder (urut sesuai `order`, anak yang tidak ada di `order` ditaruh di akhir urut `createdAt`).
  /// 2. File favorit (urut `favoritedAt` terbaru di atas).
  /// 3. File lainnya (urut sesuai `order`, anak yang tidak ada di `order` ditaruh di akhir urut `createdAt`).
  static List<NodeEntry> sortEntries({
    required List<NodeEntry> entries,
    required List<String> order,
  }) {
    final folders = entries.whereType<Folder>().toList();
    final files = entries.whereType<FileEntry>().toList();

    final favoriteFiles = files.where((f) => f.isFavorite).toList();
    final otherFiles = files.where((f) => !f.isFavorite).toList();

    // Urutkan folders berdasarkan order list
    final sortedFolders = _sortByOrder(
      items: folders,
      order: order,
      getId: (f) => f.id,
      compareFallback: (a, b) => a.createdAt.compareTo(b.createdAt),
    );

    // Urutkan favorite files: ikuti order jika ada, fallback ke favoritedAt terbaru di atas
    final sortedFavoriteFiles = _sortByOrder(
      items: favoriteFiles,
      order: order,
      getId: (f) => f.id,
      compareFallback: (a, b) {
        final aFav = a.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bFav = b.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = bFav.compareTo(aFav);
        if (cmp != 0) return cmp;
        return a.createdAt.compareTo(b.createdAt);
      },
    );

    // Urutkan other files berdasarkan order list
    final sortedOtherFiles = _sortByOrder(
      items: otherFiles,
      order: order,
      getId: (f) => f.id,
      compareFallback: (a, b) => a.createdAt.compareTo(b.createdAt),
    );

    return [
      ...sortedFolders,
      ...sortedFavoriteFiles,
      ...sortedOtherFiles,
    ];
  }

  static List<T> _sortByOrder<T>({
    required List<T> items,
    required List<String> order,
    required String Function(T item) getId,
    required int Function(T a, T b) compareFallback,
  }) {
    final orderMap = <String, int>{};
    for (int i = 0; i < order.length; i++) {
      orderMap[order[i]] = i;
    }

    final inOrder = <T>[];
    final notInOrder = <T>[];

    for (final item in items) {
      if (orderMap.containsKey(getId(item))) {
        inOrder.add(item);
      } else {
        notInOrder.add(item);
      }
    }

    inOrder.sort((a, b) => orderMap[getId(a)]!.compareTo(orderMap[getId(b)]!));
    notInOrder.sort(compareFallback);

    return [...inOrder, ...notInOrder];
  }
}
