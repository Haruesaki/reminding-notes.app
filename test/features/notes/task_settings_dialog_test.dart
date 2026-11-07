import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reminding/features/explorer/domain/entities/task.dart';
import 'package:reminding/features/explorer/domain/entities/tone_ref.dart';
import 'package:reminding/features/notes/presentation/bloc/tones/tones_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/tones/tones_state.dart';
import 'package:reminding/features/notes/presentation/widgets/task_settings_dialog.dart';

class FakeTonesBloc extends Fake implements TonesBloc {
  @override
  TonesState get state => const TonesState(
        status: TonesStatus.loaded,
        tones: [
          ToneRef(id: 'tone_1', name: 'Suara Lonceng', relativePath: 'tones/1.mp3'),
        ],
      );

  @override
  Stream<TonesState> get stream => const Stream.empty();

  @override
  Future<void> close() async {}
}

void main() {
  late FakeTonesBloc fakeTonesBloc;

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    fakeTonesBloc = FakeTonesBloc();
  });

  Widget buildTestWidget({required Task task}) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<TonesBloc>.value(
          value: fakeTonesBloc,
          child: TaskSettingsDialog(task: task),
        ),
      ),
    );
  }

  group('TaskSettingsDialog Widget Tests (PRD 7.6 & 8.3)', () {
    testWidgets('renders 3 tabs: Deadline, Nada, and Alarm', (tester) async {
      final task = Task(
        id: 't_1',
        text: 'Selesaikan laporan',
        done: false,
      );

      await tester.pumpWidget(buildTestWidget(task: task));
      await tester.pumpAndSettle();

      expect(find.text('Deadline'), findsOneWidget);
      expect(find.text('Nada'), findsOneWidget);
      expect(find.text('Alarm'), findsOneWidget);
    });

    testWidgets('Tab 1 Deadline: shows toggle, stepper, and default reminder times', (tester) async {
      final task = Task(
        id: 't_1',
        text: 'Selesaikan laporan',
        done: false,
      );

      await tester.pumpWidget(buildTestWidget(task: task));
      await tester.pumpAndSettle();

      // Initially deadline toggle is off
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Turn on deadline switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Check default reminder times chips: 09:00, 15:00, 20:00 (PRD 7.6)
      expect(find.widgetWithText(Chip, '09:00'), findsOneWidget);
      expect(find.widgetWithText(Chip, '15:00'), findsOneWidget);
      expect(find.widgetWithText(Chip, '20:00'), findsOneWidget);

      // Check default stepper is H-3 (PRD 7.6)
      expect(find.text('H-3'), findsOneWidget);
    });

    testWidgets('Tab 2 Nada: lists Bawaan sistem and loaded tones', (tester) async {
      final task = Task(
        id: 't_1',
        text: 'Beli buku',
        done: false,
      );

      await tester.pumpWidget(buildTestWidget(task: task));
      await tester.pumpAndSettle();

      // Switch to Nada tab
      await tester.tap(find.text('Nada'));
      await tester.pumpAndSettle();

      expect(find.text('Bawaan sistem'), findsOneWidget);
      expect(find.text('Suara Lonceng'), findsOneWidget);
      expect(find.textContaining('Unggah Nada Baru'), findsOneWidget);
    });

    testWidgets('Tab 3 Alarm: displays clock app disclaimer (PRD 7.6 Tab 3)', (tester) async {
      final task = Task(
        id: 't_1',
        text: 'Bangun pagi',
        done: false,
      );

      await tester.pumpWidget(buildTestWidget(task: task));
      await tester.pumpAndSettle();

      // Switch to Alarm tab
      await tester.tap(find.text('Alarm'));
      await tester.pumpAndSettle();

      // Turn on alarm switch
      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Alarm dibuat di aplikasi Jam bawaan ponsel'),
        findsOneWidget,
      );
    });
  });
}
