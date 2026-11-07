import 'package:equatable/equatable.dart';

class ToneRef extends Equatable {
  final String id;
  final String name;
  final String relativePath;
  final String? contentUri;

  const ToneRef({
    required this.id,
    required this.name,
    required this.relativePath,
    this.contentUri,
  });

  ToneRef copyWith({
    String? id,
    String? name,
    String? relativePath,
    String? contentUri,
  }) {
    return ToneRef(
      id: id ?? this.id,
      name: name ?? this.name,
      relativePath: relativePath ?? this.relativePath,
      contentUri: contentUri ?? this.contentUri,
    );
  }

  @override
  List<Object?> get props => [id, name, relativePath, contentUri];
}
