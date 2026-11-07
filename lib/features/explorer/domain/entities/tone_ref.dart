import 'package:equatable/equatable.dart';

class ToneRef extends Equatable {
  final String id;
  final String name;
  final String relativePath;

  const ToneRef({
    required this.id,
    required this.name,
    required this.relativePath,
  });

  @override
  List<Object?> get props => [id, name, relativePath];
}
