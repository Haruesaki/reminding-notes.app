import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../explorer/domain/entities/entities.dart';
import '../../data/datasources/tones_local_data_source.dart';
import '../../data/services/alarm_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/permission_service.dart';
import '../../domain/services/reminder_calculator.dart';
import '../bloc/list_editor/list_editor_bloc.dart';
import '../bloc/list_editor/list_editor_event.dart';
import '../bloc/list_editor/list_editor_state.dart';
import '../widgets/task_settings_dialog.dart';

class ListEditorPage extends StatelessWidget {
  final String? noteId;
  final String folderRelativePath;
  final ListFile? initialList;

  const ListEditorPage({
    super.key,
    this.noteId,
    this.folderRelativePath = '',
    this.initialList,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ListEditorBloc>()
        ..add(InitializeList(
          listId: (noteId == null || noteId == 'new') ? null : noteId,
          folderRelativePath: folderRelativePath,
          initialList: initialList,
        )),
      child: const _ListEditorView(),
    );
  }
}

class _ListEditorView extends StatefulWidget {
  const _ListEditorView();

  @override
  State<_ListEditorView> createState() => _ListEditorViewState();
}

class _ListEditorViewState extends State<_ListEditorView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TextEditingController _titleController;
  final ScrollController _scrollController = ScrollController();

  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnimation;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  String? _focusTargetId;

  Timer? _debounceTimer;
  bool _isTitleInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController = TextEditingController();
    _titleController.addListener(_onTitleChanged);

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _heartAnimController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveImmediate();
    }
  }

  void _onTitleChanged() {
    final bloc = context.read<ListEditorBloc>();
    bloc.add(UpdateListTitle(_titleController.text));
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveImmediate();
    });
  }

  void _syncControllersToBloc() {
    if (!mounted) return;
    final bloc = context.read<ListEditorBloc>();
    final state = bloc.state;
    if (state is! ListEditorLoaded) return;

    if (_titleController.text != state.listFile.title) {
      bloc.add(UpdateListTitle(_titleController.text));
    }
    for (final task in state.listFile.tasks) {
      final ctrl = _controllers[task.id];
      if (ctrl != null && ctrl.text != task.text) {
        bloc.add(UpdateListTaskText(taskId: task.id, newText: ctrl.text));
      }
      for (final st in task.subtasks) {
        final subCtrl = _controllers[st.id];
        if (subCtrl != null && subCtrl.text != st.text) {
          bloc.add(UpdateListSubtaskText(
            taskId: task.id,
            subtaskId: st.id,
            newText: subCtrl.text,
          ));
        }
      }
    }
  }

  void _saveImmediate() {
    _debounceTimer?.cancel();
    if (!mounted) return;
    _syncControllersToBloc();
    context.read<ListEditorBloc>().add(const SaveListEvent());
  }

  void _onExit() {
    _debounceTimer?.cancel();
    final state = context.read<ListEditorBloc>().state;
    if (state is ListEditorLoaded) {
      final file = state.listFile;
      final isEmpty = file.title.trim().isEmpty &&
          file.tasks.every((t) =>
              t.text.trim().isEmpty &&
              t.subtasks.every((st) => st.text.trim().isEmpty));
      if (isEmpty) {
        context.read<ListEditorBloc>().add(const DiscardEmptyListEvent());
      } else {
        _saveImmediate();
      }
    }
  }

  void _handleBack() {
    _onExit();
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  void _copyPlainText(ListFile listFile) async {
    final buffer = StringBuffer();
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      buffer.writeln(title);
      buffer.writeln();
    }
    for (final task in listFile.tasks) {
      final mark = task.done ? '[x]' : '[ ]';
      buffer.writeln('$mark ${task.text}');
      for (final st in task.subtasks) {
        final subMark = st.done ? '[x]' : '[ ]';
        buffer.writeln('  $subMark ${st.text}');
      }
    }

    final textToCopy = buffer.toString().trimRight();
    try {
      await Clipboard.setData(ClipboardData(text: textToCopy));
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disalin'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleFavorite() {
    _heartAnimController.forward(from: 0.0);
    context.read<ListEditorBloc>().add(const ToggleListPinInEditor());
  }

  TextEditingController _getController(String id, String text) {
    if (!_controllers.containsKey(id)) {
      _controllers[id] = TextEditingController(text: text);
    } else {
      final ctrl = _controllers[id]!;
      if (ctrl.text != text && !(_focusNodes[id]?.hasFocus ?? false)) {
        ctrl.text = text;
      }
    }
    return _controllers[id]!;
  }

  FocusNode _getFocusNode(String id) {
    if (!_focusNodes.containsKey(id)) {
      _focusNodes[id] = FocusNode();
    }
    return _focusNodes[id]!;
  }

  void _cleanUpUnusedControllers(List<Task> tasks) {
    final activeIds = <String>{};
    for (final t in tasks) {
      activeIds.add(t.id);
      for (final st in t.subtasks) {
        activeIds.add(st.id);
      }
    }

    _controllers.removeWhere((id, ctrl) {
      if (!activeIds.contains(id)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });

    _focusNodes.removeWhere((id, node) {
      if (!activeIds.contains(id)) {
        node.dispose();
        return true;
      }
      return false;
    });
  }

  void _deleteTaskWithUndo(int index, Task task) {
    final bloc = context.read<ListEditorBloc>();
    bloc.add(DeleteListTask(task.id));
    _scheduleAutoSave();
    if (task.deadline != null) {
      sl<NotificationService>().cancelTaskReminders(task.id);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tugas dihapus'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Urungkan',
          textColor: AppColors.textPrimary,
          onPressed: () {
            bloc.add(RestoreListTask(index: index, task: task));
            _scheduleAutoSave();
            if (task.deadline != null) {
              _scheduleReminderIfPresent(task);
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _scrollController.dispose();
    _heartAnimController.dispose();
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ListEditorBloc, ListEditorState>(
      listener: (context, state) {
        if (state is ListEditorLoaded) {
          if (!_isTitleInitialized) {
            _titleController.text = state.listFile.title;
            _isTitleInitialized = true;
          }
          _cleanUpUnusedControllers(state.listFile.tasks);

          if (_focusTargetId != null) {
            final targetId = _focusTargetId!;
            _focusTargetId = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _focusNodes.containsKey(targetId)) {
                _focusNodes[targetId]?.requestFocus();
              }
            });
          }
        }
      },
      builder: (context, state) {
        if (state is ListEditorLoading || state is ListEditorInitial) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.textPrimary),
            ),
          );
        }

        if (state is ListEditorError) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary),
                onPressed: _handleBack,
              ),
            ),
            body: Center(child: Text(state.message)),
          );
        }

        final loaded = state as ListEditorLoaded;
        final listFile = loaded.listFile;
        final isFavorite = listFile.isFavorite;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            _onExit();
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Stack(
                children: [
                  // Main Scrollable Area
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppConstants.screenMargin,
                            68,
                            AppConstants.screenMargin,
                            100,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          // Title (Large, Bold, Multi-line)
                          TextField(
                            key: const Key('list_title_input'),
                            controller: _titleController,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111111),
                              height: 1.15,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Tanpa judul',
                              hintStyle: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFCCCCCC),
                                height: 1.15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tasks List
                          ...listFile.tasks.asMap().entries.map((entry) {
                            final taskIndex = entry.key;
                            final task = entry.value;
                            return _buildTaskItem(taskIndex, task);
                          }),

                          // "+ Tambah tugas" button row
                          const SizedBox(height: 8),
                          InkWell(
                            key: const Key('add_task_button'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              final bloc = context.read<ListEditorBloc>();
                              bloc.add(const AddListTask());
                              _scheduleAutoSave();
                              // Schedule focus to newest task
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final currentState = bloc.state;
                                if (currentState is ListEditorLoaded &&
                                    currentState.listFile.tasks.isNotEmpty) {
                                  final lastTask =
                                      currentState.listFile.tasks.last;
                                  _getFocusNode(lastTask.id).requestFocus();
                                }
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 22,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tambah tugas',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 150),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Pinned Header & Gradient Scroll Fade
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      height: 56,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Row(
                            children: [
                              IconButton(
                                key: const Key('editor_back_button'),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Color(0xFF111111),
                                  size: 24,
                                ),
                                tooltip: 'Kembali',
                                onPressed: _handleBack,
                              ),
                              const Spacer(),
                              // Clipboard action
                              IconButton(
                                key: const Key('editor_copy_button'),
                                icon: const Icon(
                                  Icons.content_copy_rounded,
                                  color: Color(0xFF111111),
                                  size: 22,
                                ),
                                tooltip: 'Salin teks',
                                onPressed: () => _copyPlainText(listFile),
                              ),
                              // Favorite heart toggle with pop animation
                              ScaleTransition(
                                scale: _heartScaleAnimation,
                                child: IconButton(
                                  key: const Key('editor_favorite_button'),
                                  icon: Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFavorite
                                        ? const Color(0xFFE53935)
                                        : const Color(0xFF111111),
                                    size: 24,
                                  ),
                                  tooltip:
                                      isFavorite ? 'Hapus favorit' : 'Favorit',
                                  onPressed: _toggleFavorite,
                                ),
                              ),
                              // Share action (placeholder for M8)
                              IconButton(
                                key: const Key('editor_share_button'),
                                icon: const Icon(
                                  Icons.share_rounded,
                                  color: Color(0xFF111111),
                                  size: 22,
                                ),
                                tooltip: 'Bagikan',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Fitur bagikan hadir di M8'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                        // Gradient Scroll Fade (no BackdropFilter)
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(int taskIndex, Task task) {
    final bloc = context.read<ListEditorBloc>();
    final controller = _getController(task.id, task.text);
    final focusNode = _getFocusNode(task.id);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Parent Task Row (Dismissible for swipe-left to delete)
            Dismissible(
              key: ValueKey('dismiss_task_${task.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              onDismissed: (_) {
                _deleteTaskWithUndo(taskIndex, task);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Checkbox
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        key: Key('task_checkbox_${task.id}'),
                        value: task.done,
                        onChanged: (val) {
                          bloc.add(ToggleListTaskDone(task.id));
                          _scheduleAutoSave();
                          if (task.deadline != null) {
                            if (!task.done) {
                              sl<NotificationService>().cancelTaskReminders(task.id);
                            } else {
                              final updatedTask = task.copyWith(done: false);
                              _scheduleReminderIfPresent(updatedTask);
                            }
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        activeColor: const Color(0xFF111111),
                        checkColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Inline Editable Text & Deadline Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            key: Key('task_text_${task.id}'),
                            controller: controller,
                            focusNode: focusNode,
                            maxLines: null,
                            style: TextStyle(
                              fontSize: 16,
                              color: task.done
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Tulis tugas...',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                color: Color(0xFFCCCCCC),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                            ),
                            onChanged: (val) {
                              bloc.add(UpdateListTaskText(
                                taskId: task.id,
                                newText: val,
                              ));
                              _scheduleAutoSave();
                            },
                            onSubmitted: (val) {
                              if (val.trim().isEmpty) {
                                bloc.add(DeleteListTask(task.id));
                                _scheduleAutoSave();
                              } else {
                                bloc.add(AddListTask(afterTaskId: task.id));
                                _scheduleAutoSave();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  final currentState = bloc.state;
                                  if (currentState is ListEditorLoaded) {
                                    final idx = currentState.listFile.tasks
                                        .indexWhere((t) => t.id == task.id);
                                    if (idx != -1 &&
                                        idx + 1 <
                                            currentState.listFile.tasks.length) {
                                      final nextTask =
                                          currentState.listFile.tasks[idx + 1];
                                      _getFocusNode(nextTask.id).requestFocus();
                                    }
                                  }
                                });
                              }
                            },
                          ),
                          if (task.deadline != null) _buildDeadlineBadge(task),
                        ],
                      ),
                    ),

                    // Action 1: Three dots menu (⋮)
                    PopupMenuButton<String>(
                      key: Key('task_menu_${task.id}'),
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'add_subtask',
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Tambahkan sub task'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Pengaturan'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 20, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text(
                                'Hapus',
                                style: TextStyle(color: Color(0xFFEF4444)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'add_subtask') {
                          bloc.add(AddListSubtask(parentTaskId: task.id));
                          _scheduleAutoSave();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final currentState = bloc.state;
                            if (currentState is ListEditorLoaded) {
                              final t = currentState.listFile.tasks.firstWhere(
                                  (element) => element.id == task.id,
                                  orElse: () => task);
                              if (t.subtasks.isNotEmpty) {
                                final newSt = t.subtasks.last;
                                _getFocusNode(newSt.id).requestFocus();
                              }
                            }
                          });
                        } else if (val == 'settings') {
                          _openTaskSettings(task);
                        } else if (val == 'delete') {
                          _deleteTaskWithUndo(taskIndex, task);
                        }
                      },
                    ),

                    // Action 2: Chevron expand/collapse (HANYA tampil jika punya sub task)
                    if (task.subtasks.isNotEmpty)
                      IconButton(
                        key: Key('task_chevron_${task.id}'),
                        icon: Icon(
                          task.collapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32),
                        onPressed: () {
                          bloc.add(ToggleListTaskCollapse(task.id));
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Sub tasks (One level, Indented)
            if (task.subtasks.isNotEmpty && !task.collapsed)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: task.subtasks.map((st) {
                    return _buildSubtaskItem(task, st);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtaskItem(Task parentTask, Subtask subtask) {
    final bloc = context.read<ListEditorBloc>();
    final controller = _getController(subtask.id, subtask.text);
    final focusNode = _getFocusNode(subtask.id);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Subtask Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                key: Key('subtask_checkbox_${subtask.id}'),
                value: subtask.done,
                onChanged: (val) {
                  bloc.add(ToggleListSubtaskDone(
                    taskId: parentTask.id,
                    subtaskId: subtask.id,
                  ));
                  _scheduleAutoSave();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                activeColor: const Color(0xFF111111),
                checkColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),

            // Inline Editable Text
            Expanded(
              child: TextField(
                key: Key('subtask_text_${subtask.id}'),
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                style: TextStyle(
                  fontSize: 15,
                  color: subtask.done
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  decoration: subtask.done
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tulis sub task...',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFCCCCCC),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
                onChanged: (val) {
                  bloc.add(UpdateListSubtaskText(
                    taskId: parentTask.id,
                    subtaskId: subtask.id,
                    newText: val,
                  ));
                  _scheduleAutoSave();
                },
                onSubmitted: (val) {
                  if (val.trim().isEmpty) {
                    bloc.add(DeleteListSubtask(
                      taskId: parentTask.id,
                      subtaskId: subtask.id,
                    ));
                    _scheduleAutoSave();
                  } else {
                    bloc.add(AddListSubtask(parentTaskId: parentTask.id));
                    _scheduleAutoSave();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final currentState = bloc.state;
                      if (currentState is ListEditorLoaded) {
                        final t = currentState.listFile.tasks.firstWhere(
                          (element) => element.id == parentTask.id,
                          orElse: () => parentTask,
                        );
                        if (t.subtasks.isNotEmpty) {
                          final lastSub = t.subtasks.last;
                          _getFocusNode(lastSub.id).requestFocus();
                        }
                      }
                    });
                  }
                },
              ),
            ),

            // Subtask Menu (Hanya berisi "Hapus")
            PopupMenuButton<String>(
              key: Key('subtask_menu_${subtask.id}'),
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 20, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text(
                        'Hapus',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (val) {
                if (val == 'delete') {
                  bloc.add(DeleteListSubtask(
                    taskId: parentTask.id,
                    subtaskId: subtask.id,
                  ));
                  _scheduleAutoSave();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineBadge(Task task) {
    final dl = task.deadline;
    if (dl == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final status = ReminderCalculator.getDeadlineBadgeStatus(dl.at, now);
    final badgeText = ReminderCalculator.formatDeadlineBadge(dl.at);

    Color bg;
    Color fg;
    Color border;

    switch (status) {
      case DeadlineBadgeStatus.urgent:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        border = const Color(0xFFFCA5A5);
        break;
      case DeadlineBadgeStatus.neutral:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        border = const Color(0xFFD1D5DB);
        break;
      case DeadlineBadgeStatus.relaxed:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        border = const Color(0xFF86EFAC);
        break;
    }

    return InkWell(
      key: Key('deadline_badge_${task.id}'),
      onTap: () => _openTaskSettings(task),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_filled_rounded, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              badgeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scheduleReminderIfPresent(Task task) async {
    final bloc = context.read<ListEditorBloc>();
    final state = bloc.state;
    if (state is! ListEditorLoaded) return;
    if (task.deadline == null) return;

    ToneRef? tone;
    final toneId = task.deadline?.notificationToneId;
    if (toneId != null) {
      tone = await sl<TonesLocalDataSource>().getToneById(toneId);
    }

    await sl<NotificationService>().scheduleTaskReminders(
      task: task,
      fileTitle: state.listFile.title,
      fileId: state.listFile.id,
      tone: tone,
    );
  }

  Future<void> _openTaskSettings(Task task) async {
    final bloc = context.read<ListEditorBloc>();
    final result = await TaskSettingsDialog.show(context, task: task);
    if (result == null || !mounted) return;

    if (result.deadlineModified && result.task.deadline != null) {
      final granted =
          await sl<PermissionService>().requestNotificationPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin notifikasi tidak diberikan. Pengingat mungkin tidak muncul.',
            ),
          ),
        );
      }
    }

    if (result.task.deadline != null) {
      await _scheduleReminderIfPresent(result.task);
    } else if (result.deadlineModified) {
      await sl<NotificationService>().cancelTaskReminders(result.task.id);
    }

    if (result.alarmModified &&
        result.task.alarm != null &&
        result.task.alarm!.enabled) {
      String? ringtoneUri;
      if (result.task.alarm?.toneId != null) {
        final tone = await sl<TonesLocalDataSource>()
            .getToneById(result.task.alarm!.toneId!);
        ringtoneUri = tone?.contentUri;
      }

      final res = await sl<AlarmService>().createAlarm(
        scheduledTime: result.task.alarm!.at,
        message:
            result.task.text.isNotEmpty ? result.task.text : 'Pengingat Tugas',
        ringtoneUri: ringtoneUri,
      );
      if (!mounted) return;
      if (res == AlarmResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarm berhasil dibuat di aplikasi Jam'),
          ),
        );
      } else if (res == AlarmResult.failedNoClockApp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka aplikasi Jam ponsel'),
          ),
        );
      }
    }

    if (!mounted) return;
    bloc.add(UpdateTaskSettings(result.task));
    _scheduleAutoSave();
  }
}
