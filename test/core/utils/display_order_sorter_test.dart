import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/utils/display_order_sorter.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';

void main() {
  group('DisplayOrderSorter (PRD 6.9)', () {
    final t1 = DateTime(2025, 1, 1, 10, 0);
    final t2 = DateTime(2025, 1, 2, 10, 0);
    final t3 = DateTime(2025, 1, 3, 10, 0);
    final t4 = DateTime(2025, 1, 4, 10, 0);

    test('sorts folders first, then favorite files (newest favoritedAt top), then other files', () {
      final f1 = Folder(
        id: 'f1',
        relativePath: 'Work',
        name: 'Work',
        order: const [],
        createdAt: t1,
      );
      final f2 = Folder(
        id: 'f2',
        relativePath: 'Personal',
        name: 'Personal',
        order: const [],
        createdAt: t2,
      );

      final favOld = PageFile(
        id: 'fav_old',
        relativePath: 'FavOld.json',
        title: 'Fav Old',
        plainText: '',
        colorIndex: 0,
        favoritedAt: t2,
        createdAt: t1,
        updatedAt: t2,
      );
      final favNew = PageFile(
        id: 'fav_new',
        relativePath: 'FavNew.json',
        title: 'Fav New',
        plainText: '',
        colorIndex: 0,
        favoritedAt: t4,
        createdAt: t1,
        updatedAt: t4,
      );

      final other1 = PageFile(
        id: 'other1',
        relativePath: 'Other1.json',
        title: 'Other 1',
        plainText: '',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: t1,
        updatedAt: t1,
      );
      final other2 = PageFile(
        id: 'other2',
        relativePath: 'Other2.json',
        title: 'Other 2',
        plainText: '',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: t3,
        updatedAt: t3,
      );

      // Order array in parent folder: specifies ['f2', 'f1'] and other files ['other2', 'other1']
      final order = const ['f2', 'f1', 'other2', 'other1'];

      final unsorted = [other1, f1, favOld, other2, favNew, f2];
      final sorted = DisplayOrderSorter.sortEntries(
        entries: unsorted,
        order: order,
      );

      // 1. Folders per order: f2, then f1
      // 2. Favorites per favoritedAt desc: favNew (t4), then favOld (t2)
      // 3. Other files per order: other2, then other1
      expect(sorted.map((e) => e.id).toList(), [
        'f2',
        'f1',
        'fav_new',
        'fav_old',
        'other2',
        'other1',
      ]);
    });

    test('unlisted items in order fallback to createdAt ascending', () {
      final fA = Folder(
        id: 'fA',
        relativePath: 'A',
        name: 'A',
        order: const [],
        createdAt: t2,
      );
      final fB = Folder(
        id: 'fB',
        relativePath: 'B',
        name: 'B',
        order: const [],
        createdAt: t1,
      );

      final sorted = DisplayOrderSorter.sortEntries(
        entries: [fA, fB],
        order: const [],
      );

      expect(sorted.map((e) => e.id).toList(), ['fB', 'fA']);
    });
  });
}
