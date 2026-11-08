import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../di/injection_container.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_event.dart';
import '../../features/notes/presentation/cubit/copy_move_cubit.dart';
import '../../features/notes/presentation/cubit/deadline_calendar_cubit.dart';
import '../../features/notes/presentation/pages/editor_placeholder_page.dart';
import '../../features/notes/presentation/pages/home_page.dart';
import '../../features/notes/presentation/pages/list_editor_page.dart';
import '../../features/notes/presentation/pages/note_editor_page.dart';
import '../../features/notes/presentation/pages/reminders_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

class AppRouter {
  /// Transisi halaman: Fade-through/shared-axis horizontal 250ms (PRD 4.4)
  static Page<dynamic> _buildFadeThroughPage(GoRouterState state, Widget child) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.04, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation);
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
    );
  }

  // Routes for Home, Folder, and Note Editor screens
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => _buildFadeThroughPage(
          state,
          MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<NoteListBloc>()..add(const LoadNotes()),
              ),
              BlocProvider(
                create: (_) =>
                    sl<DeadlineCalendarCubit>()..loadDeadlines(),
              ),
              BlocProvider.value(
                value: sl<CopyMoveCubit>(),
              ),
            ],
            child: const HomePage(),
          ),
        ),
      ),
      GoRoute(
        path: '/folder',
        name: 'folder',
        pageBuilder: (context, state) {
          final folderPath = state.uri.queryParameters['path'] ?? '';
          return _buildFadeThroughPage(
            state,
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => sl<NoteListBloc>()
                    ..add(LoadNotes(folderRelativePath: folderPath)),
                ),
                BlocProvider(
                  create: (_) =>
                      sl<DeadlineCalendarCubit>()..loadDeadlines(),
                ),
                BlocProvider.value(
                  value: sl<CopyMoveCubit>(),
                ),
              ],
              child: HomePage(folderRelativePath: folderPath),
            ),
          );
        },
      ),
      GoRoute(
        path: '/editor-placeholder/:type',
        name: 'editor-placeholder',
        pageBuilder: (context, state) {
          final type = state.pathParameters['type'] ?? 'Page';
          final folder = state.uri.queryParameters['folder'] ?? '';
          return _buildFadeThroughPage(
            state,
            EditorPlaceholderPage(
              fileType: type.toLowerCase() == 'list' ? 'List' : 'Page',
              folderRelativePath: folder,
            ),
          );
        },
      ),
      GoRoute(
        path: '/note/:id',
        name: 'note-editor',
        pageBuilder: (context, state) {
          final noteId = state.pathParameters['id'];
          final folder = state.uri.queryParameters['folder'] ?? '';
          return _buildFadeThroughPage(
            state,
            NoteEditorPage(
              noteId: noteId,
              folderRelativePath: folder,
            ),
          );
        },
      ),
      GoRoute(
        path: '/list/:id',
        name: 'list-editor',
        pageBuilder: (context, state) {
          final listId = state.pathParameters['id'];
          final folder = state.uri.queryParameters['folder'] ?? '';
          return _buildFadeThroughPage(
            state,
            ListEditorPage(
              noteId: listId,
              folderRelativePath: folder,
            ),
          );
        },
      ),
      GoRoute(
        path: '/reminders',
        name: 'reminders',
        pageBuilder: (context, state) => _buildFadeThroughPage(
          state,
          BlocProvider(
            create: (_) => sl<DeadlineCalendarCubit>()..loadDeadlines(),
            child: const RemindersPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => _buildFadeThroughPage(
          state,
          const SettingsPage(),
        ),
      ),
    ],
  );
}
