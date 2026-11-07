import 'package:equatable/equatable.dart';

class DeadlineItem extends Equatable {
  final String taskId;
  final String fileId;
  final String taskText;
  final String fileTitle;
  final String fileRelativePath;
  final String fileType; // 'list' or 'page'
  final DateTime at;
  final bool done;

  const DeadlineItem({
    required this.taskId,
    required this.fileId,
    required this.taskText,
    required this.fileTitle,
    required this.fileRelativePath,
    this.fileType = 'list',
    required this.at,
    required this.done,
  });

  @override
  List<Object?> get props => [
        taskId,
        fileId,
        taskText,
        fileTitle,
        fileRelativePath,
        fileType,
        at,
        done,
      ];
}
