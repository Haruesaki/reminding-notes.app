import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../di/injection_container.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_event.dart';
import '../../features/notes/presentation/pages/home_page.dart';
import '../../features/notes/presentation/pages/note_editor_page.dart';

class AppRouter {
  // Routes for Home and Note Editor screens
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => BlocProvider(
          create: (_) => sl<NoteListBloc>()..add(const LoadNotes()),
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: '/note/:id',
        name: 'note-editor',
        builder: (context, state) {
          final noteId = state.pathParameters['id'];
          return NoteEditorPage(noteId: noteId);
        },
      ),
    ],
  );
}
