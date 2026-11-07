import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/explorer/domain/entities/alarm_settings.dart';
import '../../../../features/explorer/domain/entities/deadline_settings.dart';
import '../../../../features/explorer/domain/entities/task.dart';
import '../../../../features/explorer/domain/entities/tone_ref.dart';
import '../../domain/services/reminder_calculator.dart';
import '../bloc/tones/tones_bloc.dart';
import '../bloc/tones/tones_event.dart';
import '../bloc/tones/tones_state.dart';

class TaskSettingsResult {
  final Task task;
  final bool deadlineModified;
  final bool alarmModified;

  const TaskSettingsResult({
    required this.task,
    this.deadlineModified = false,
    this.alarmModified = false,
  });
}

class TaskSettingsDialog extends StatefulWidget {
  final Task task;

  const TaskSettingsDialog({
    super.key,
    required this.task,
  });

  static Future<TaskSettingsResult?> show(
    BuildContext context, {
    required Task task,
  }) {
    return showModalBottomSheet<TaskSettingsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => BlocProvider(
        create: (_) => sl<TonesBloc>()..add(const LoadTones()),
        child: TaskSettingsDialog(task: task),
      ),
    );
  }

  @override
  State<TaskSettingsDialog> createState() => _TaskSettingsDialogState();
}

class _TaskSettingsDialogState extends State<TaskSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Deadline Tab State
  bool _hasDeadline = false;
  late DateTime _deadlineDate;
  late TimeOfDay _deadlineTime;
  int _remindDaysBefore = 3;
  List<String> _remindTimes = ['09:00', '15:00', '20:00'];
  String? _selectedNotificationToneId;

  // Alarm Tab State
  bool _alarmEnabled = false;
  late DateTime _alarmDate;
  late TimeOfDay _alarmTime;
  String? _selectedAlarmToneId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final dl = widget.task.deadline;
    if (dl != null) {
      _hasDeadline = true;
      _deadlineDate = DateTime(dl.at.year, dl.at.month, dl.at.day);
      _deadlineTime = TimeOfDay(hour: dl.at.hour, minute: dl.at.minute);
      _remindDaysBefore = dl.remindStartDaysBefore;
      _remindTimes = List.from(dl.remindTimes);
      _selectedNotificationToneId = dl.notificationToneId;
    } else {
      final now = DateTime.now();
      _deadlineDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 3));
      _deadlineTime = const TimeOfDay(hour: 20, minute: 0);
    }

    final al = widget.task.alarm;
    if (al != null && al.enabled) {
      _alarmEnabled = true;
      _alarmDate = DateTime(al.at.year, al.at.month, al.at.day);
      _alarmTime = TimeOfDay(hour: al.at.hour, minute: al.at.minute);
      _selectedAlarmToneId = al.toneId;
    } else {
      final now = DateTime.now();
      _alarmDate = DateTime(now.year, now.month, now.day);
      _alarmTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime get _fullDeadlineDateTime => DateTime(
        _deadlineDate.year,
        _deadlineDate.month,
        _deadlineDate.day,
        _deadlineTime.hour,
        _deadlineTime.minute,
      );

  DateTime get _fullAlarmDateTime => DateTime(
        _alarmDate.year,
        _alarmDate.month,
        _alarmDate.day,
        _alarmTime.hour,
        _alarmTime.minute,
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 560,
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pengaturan Tugas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                ],
              ),
            ),
            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppColors.textPrimary,
              tabs: const [
                Tab(text: 'Deadline'),
                Tab(text: 'Nada'),
                Tab(text: 'Alarm'),
              ],
            ),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDeadlineTab(),
                  _buildToneTab(),
                  _buildAlarmTab(),
                ],
              ),
            ),
            // Bottom Save & Cancel Buttons
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineTab() {
    final nextSlots = _hasDeadline
        ? ReminderCalculator.calculateReminderSlots(
            deadline: _fullDeadlineDateTime,
            remindStartDaysBefore: _remindDaysBefore,
            remindTimes: _remindTimes,
            now: DateTime.now(),
          )
        : <DateTime>[];

    String nextReminderText;
    if (!_hasDeadline) {
      nextReminderText = 'Deadline belum diaktifkan.';
    } else if (nextSlots.isEmpty) {
      nextReminderText = 'Tidak ada jadwal pengingat tersisa (semua slot telah lewat).';
    } else {
      nextReminderText =
          'Pengingat berikutnya: ${DateFormat("EEE, d MMM HH:mm", "id_ID").format(nextSlots.first)}';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aktifkan Deadline', style: TextStyle(fontWeight: FontWeight.w600)),
          value: _hasDeadline,
          activeThumbColor: AppColors.textPrimary,
          onChanged: (val) {
            setState(() {
              _hasDeadline = val;
            });
          },
        ),
        if (_hasDeadline) ...[
          const SizedBox(height: 8),
          // Date & Time pickers
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _pickDeadlineDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Tenggat',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      DateFormat('dd MMMM yyyy', 'id_ID').format(_deadlineDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _pickDeadlineTime,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Jam',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: Icon(Icons.access_time, size: 18),
                    ),
                    child: Text(
                      '${_deadlineTime.hour.toString().padLeft(2, '0')}:${_deadlineTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stepper H-N
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mulai pengingat:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _remindDaysBefore > 0
                          ? () => setState(() => _remindDaysBefore--)
                          : null,
                    ),
                    Text(
                      'H-$_remindDaysBefore',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _remindDaysBefore < 30
                          ? () => setState(() => _remindDaysBefore++)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Remind times chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jam pengingat harian:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              TextButton.icon(
                onPressed: _addRemindTime,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah Jam'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _remindTimes.map((timeStr) {
              final canDelete = _remindTimes.length > 1;
              return Chip(
                label: Text(timeStr),
                deleteIcon: canDelete ? const Icon(Icons.close, size: 16) : null,
                onDeleted: canDelete ? () => _removeRemindTime(timeStr) : null,
                backgroundColor: Colors.grey.shade100,
                side: BorderSide(color: Colors.grey.shade300),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Helper text
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextReminderText,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tombol Hapus Deadline
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Hapus deadline'),
            onPressed: () {
              setState(() {
                _hasDeadline = false;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildToneTab() {
    return BlocBuilder<TonesBloc, TonesState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Pilih Nada Notifikasi:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            RadioGroup<String?>(
              groupValue: _selectedNotificationToneId,
              onChanged: (val) {
                setState(() {
                  _selectedNotificationToneId = val;
                });
              },
              child: Column(
                children: [
                  const RadioListTile<String?>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Bawaan sistem'),
                    value: null,
                  ),
                  ...state.tones.map((tone) {
                    final isPlaying = state.isPlaying && state.playingToneId == tone.id;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Radio<String?>(
                        value: tone.id,
                      ),
                      title: Text(tone.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () {
                              context.read<TonesBloc>().add(PlayTonePreviewEvent(tone));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmDeleteTone(context, tone),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedNotificationToneId = tone.id;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Upload button
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Unggah Nada Baru (~10 MB)'),
              onPressed: () => _uploadTone(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlarmTab() {
    return BlocBuilder<TonesBloc, TonesState>(
      builder: (context, tonesState) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktifkan Alarm', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Buat alarm di aplikasi Jam bawaan ponsel'),
              value: _alarmEnabled,
              activeThumbColor: AppColors.textPrimary,
              onChanged: (val) {
                setState(() {
                  _alarmEnabled = val;
                });
              },
            ),
            if (_alarmEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _pickAlarmDate,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Alarm',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(
                          DateFormat('dd MMMM yyyy', 'id_ID').format(_alarmDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _pickAlarmTime,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Jam',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          suffixIcon: Icon(Icons.alarm, size: 18),
                        ),
                        child: Text(
                          '${_alarmTime.hour.toString().padLeft(2, '0')}:${_alarmTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Pilih Nada Alarm:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              RadioGroup<String?>(
                groupValue: _selectedAlarmToneId,
                onChanged: (val) {
                  setState(() {
                    _selectedAlarmToneId = val;
                  });
                },
                child: Column(
                  children: [
                    const RadioListTile<String?>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Bawaan sistem'),
                      value: null,
                    ),
                    ...tonesState.tones.map((tone) {
                      return RadioListTile<String?>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tone.name),
                        value: tone.id,
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Disclaimer card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Catatan: Alarm dibuat di aplikasi Jam bawaan ponsel lewat sistem Android. Aplikasi Jam umumnya tidak mendukung perubahan atau penghapusan alarm dari aplikasi lain. Hapus alarm lama di aplikasi Jam bila perlu.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: _onSave,
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    final originalDl = widget.task.deadline;
    final originalAl = widget.task.alarm;

    DeadlineSettings? newDl;
    if (_hasDeadline) {
      newDl = DeadlineSettings(
        at: _fullDeadlineDateTime,
        remindStartDaysBefore: _remindDaysBefore,
        remindTimes: _remindTimes,
        notificationToneId: _selectedNotificationToneId,
      );
    }

    AlarmSettings? newAl;
    if (_alarmEnabled) {
      newAl = AlarmSettings(
        enabled: true,
        at: _fullAlarmDateTime,
        toneId: _selectedAlarmToneId,
      );
    }

    final dlModified = (originalDl != newDl);
    final alModified = (originalAl != newAl);

    final updatedTask = widget.task.copyWith(
      deadline: newDl,
      clearDeadline: !_hasDeadline,
      alarm: newAl,
      clearAlarm: !_alarmEnabled,
    );

    Navigator.pop(
      context,
      TaskSettingsResult(
        task: updatedTask,
        deadlineModified: dlModified,
        alarmModified: alModified,
      ),
    );
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        _deadlineDate = picked;
      });
    }
  }

  Future<void> _pickDeadlineTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _deadlineTime,
    );
    if (picked != null) {
      setState(() {
        _deadlineTime = picked;
      });
    }
  }

  Future<void> _pickAlarmDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _alarmDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        _alarmDate = picked;
      });
    }
  }

  Future<void> _pickAlarmTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _alarmTime,
    );
    if (picked != null) {
      setState(() {
        _alarmTime = picked;
      });
    }
  }

  Future<void> _addRemindTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      if (!mounted) return;
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!_remindTimes.contains(formatted)) {
        setState(() {
          _remindTimes = List.from(_remindTimes)..add(formatted)..sort();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jam pengingat tersebut sudah ada.')),
        );
      }
    }
  }

  void _removeRemindTime(String timeStr) {
    if (_remindTimes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 jam pengingat.')),
      );
      return;
    }
    setState(() {
      _remindTimes = List.from(_remindTimes)..remove(timeStr);
    });
  }

  Future<void> _uploadTone(BuildContext context) async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'ogg', 'wav'],
      );
      if (pickedFiles.isEmpty) return;
      final firstFile = pickedFiles.first;
      if (firstFile.path == null) return;

      final file = File(firstFile.path!);
      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran file melebihi batas 10 MB.')),
        );
        return;
      }

      if (!context.mounted) return;
      final defaultName = firstFile.name;
      final nameController = TextEditingController(text: defaultName);

      final confirmedName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nama Nada'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Masukkan nama nada'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (confirmedName != null && confirmedName.isNotEmpty && context.mounted) {
        context.read<TonesBloc>().add(AddToneEvent(
              file: file,
              name: confirmedName,
            ));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih file nada: $e')),
      );
    }
  }

  Future<void> _confirmDeleteTone(BuildContext context, ToneRef tone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Nada?'),
        content: Text(
          'Yakin ingin menghapus "${tone.name}"? Task yang memakai nada ini akan kembali ke nada bawaan sistem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      if (_selectedNotificationToneId == tone.id) {
        setState(() {
          _selectedNotificationToneId = null;
        });
      }
      if (_selectedAlarmToneId == tone.id) {
        setState(() {
          _selectedAlarmToneId = null;
        });
      }
      context.read<TonesBloc>().add(DeleteToneEvent(tone.id));
    }
  }
}
