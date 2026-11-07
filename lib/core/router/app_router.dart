import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../di/injection_container.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_event.dart';
import '../../features/notes/presentation/cubit/deadline_calendar_cubit.dart';
import '../../features/notes/presentation/pages/editor_placeholder_page.dart';
import '../../features/notes/presentation/pages/home_page.dart';
import '../../features/notes/presentation/pages/list_editor_page.dart';
import '../../features/notes/presentation/pages/note_editor_page.dart';
import '../../features/notes/presentation/pages/reminders_page.dart';

class AppRouter {
  // Routes for Home, Folder, and Note Editor screens
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => sl<NoteListBloc>()..add(const LoadNotes()),
            ),
            BlocProvider(
              create: (_) =>
                  sl<DeadlineCalendarCubit>()..loadDeadlines(),
            ),
          ],
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: '/folder',
        name: 'folder',
        builder: (context, state) {
          final folderPath = state.uri.queryParameters['path'] ?? '';
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<NoteListBloc>()
                  ..add(LoadNotes(folderRelativePath: folderPath)),
              ),
              BlocProvider(
                create: (_) =>
                    sl<DeadlineCalendarCubit>()..loadDeadlines(),
              ),
            ],
            child: HomePage(folderRelativePath: folderPath),
          );
        },
      ),
      GoRoute(
        path: '/editor-placeholder/:type',
        name: 'editor-placeholder',
        builder: (context, state) {
          final type = state.pathParameters['type'] ?? 'Page';
          final folder = state.uri.queryParameters['folder'] ?? '';
          return EditorPlaceholderPage(
            fileType: type.toLowerCase() == 'list' ? 'List' : 'Page',
            folderRelativePath: folder,
          );
        },
      ),
      GoRoute(
        path: '/note/:id',
        name: 'note-editor',
        builder: (context, state) {
          final noteId = state.pathParameters['id'];
          final folder = state.uri.queryParameters['folder'] ?? '';
          return NoteEditorPage(
            noteId: noteId,
            folderRelativePath: folder,
          );
        },
      ),
      GoRoute(
        path: '/list/:id',
        name: 'list-editor',
        builder: (context, state) {
          final listId = state.pathParameters['id'];
          final folder = state.uri.queryParameters['folder'] ?? '';
          return ListEditorPage(
            noteId: listId,
            folderRelativePath: folder,
          );
        },
      ),
      GoRoute(
        path: '/reminders',
        name: 'reminders',
        builder: (context, state) => BlocProvider(
          create: (_) => sl<DeadlineCalendarCubit>()..loadDeadlines(),
          child: const RemindersPage(),
        ),
      ),
    ],
  );
}
