import 'package:flutter/foundation.dart';
import '../../features/explorer/domain/entities/entities.dart';
import '../../features/explorer/domain/repositories/explorer_repository.dart';

/// Seeder for demo data conforming to PRD Section 11 and Figma Home designs.
/// Active ONLY in debug mode when `--dart-define=SEED_DEMO=true`.
/// Never runs in release mode and never touches existing data.
class DemoSeeder {
  static const bool isDemoFlagEnabled =
      bool.fromEnvironment('SEED_DEMO', defaultValue: false);

  static Future<void> seedIfEmpty(ExplorerRepository repository) async {
    // Only in debug mode and if SEED_DEMO=true
    if (!kDebugMode || !isDemoFlagEnabled) {
      return;
    }

    // Never touch existing data
    final existingContents = await repository.getFolderContents('');
    if (existingContents.isNotEmpty) {
      return;
    }

    final now = DateTime.now();

    // 1. Product Meeting (ListFile)
    await repository.saveList(ListFile(
      id: 'demo-list-product-meeting',
      relativePath: 'Product Meeting.json',
      title: 'Product Meeting',
      colorIndex: 0,
      favoritedAt: null,
      tasks: const [
        Task(id: 'pm-1', text: 'Review of Previous Action Items', done: false),
        Task(id: 'pm-2', text: 'Product Development Update', done: false),
        Task(id: 'pm-3', text: 'User Feedback and Customer Insights', done: false),
        Task(id: 'pm-4', text: 'Competitive Analysis', done: false),
        Task(id: 'pm-5', text: 'Roadmap Discussion', done: false),
      ],
      createdAt: now,
      updatedAt: now,
    ));

    // 2. To-do list (ListFile)
    await repository.saveList(ListFile(
      id: 'demo-list-todo',
      relativePath: 'To-do list.json',
      title: 'To-do list',
      colorIndex: 1,
      favoritedAt: null,
      tasks: const [
        Task(id: 'todo-1', text: 'Reply to emails', done: false),
        Task(id: 'todo-2', text: 'Prepare presentation slides for the marketing meeting', done: false),
        Task(id: 'todo-3', text: 'Conduct research on competitor products', done: false),
        Task(id: 'todo-4', text: 'Schedule and plan customer interviews', done: false),
        Task(id: 'todo-5', text: 'Take a break and recharge', done: false),
      ],
      createdAt: now,
      updatedAt: now,
    ));

    // 3. Shopping list (ListFile)
    await repository.saveList(ListFile(
      id: 'demo-list-shopping',
      relativePath: 'Shopping list.json',
      title: 'Shopping list',
      colorIndex: 2,
      favoritedAt: null,
      tasks: const [
        Task(id: 'shop-1', text: 'Rice', done: false),
        Task(id: 'shop-2', text: 'Pasta', done: false),
        Task(id: 'shop-3', text: 'Cereal', done: false),
        Task(id: 'shop-4', text: 'Yogurt', done: false),
        Task(id: 'shop-5', text: 'Cheese', done: false),
        Task(id: 'shop-6', text: 'Butter', done: false),
      ],
      createdAt: now,
      updatedAt: now,
    ));

    // 4. Important (PageFile)
    await repository.savePage(PageFile(
      id: 'demo-page-important',
      relativePath: 'Important.json',
      title: 'Important',
      plainText:
          '  - Summarize the key action items identified during the meeting.\n  - Assign responsible team members and set deadlines for each action item.\n  - Clarify the next steps and ensure everyone is clear on their respective tasks.',
      colorIndex: 3,
      favoritedAt: null,
      createdAt: now,
      updatedAt: now,
    ));

    // 5. Notes (PageFile)
    await repository.savePage(PageFile(
      id: 'demo-page-notes',
      relativePath: 'Notes.json',
      title: 'Notes',
      plainText:
          '  - Share insights and findings from recent competitive analysis.',
      colorIndex: 4,
      favoritedAt: null,
      createdAt: now,
      updatedAt: now,
    ));
  }
}
