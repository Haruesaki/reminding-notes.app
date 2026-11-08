import 'package:equatable/equatable.dart';
import 'node_entry.dart';

class SearchResultItem extends Equatable {
  final FileEntry file;
  final String breadcrumb;

  const SearchResultItem({
    required this.file,
    required this.breadcrumb,
  });

  @override
  List<Object?> get props => [file, breadcrumb];
}
