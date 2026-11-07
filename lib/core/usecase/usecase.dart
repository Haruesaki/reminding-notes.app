import 'package:equatable/equatable.dart';

abstract class UseCase<TypeResult, Params> {
  Future<TypeResult> call(Params params);
}

class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
