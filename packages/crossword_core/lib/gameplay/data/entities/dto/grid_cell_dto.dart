import 'position_dto.dart';

sealed class GridCellDto {
  const GridCellDto();

  factory GridCellDto.fromJson(Map<String, dynamic> json) {
    switch (json['kind'] as String) {
      case 'block':
        return const BlockCellDto();
      case 'answer':
        return AnswerCellDto.fromJson(json);
      case 'clue':
        return ClueCellDto.fromJson(json);
      default:
        throw FormatException('Unknown cell kind: ${json['kind']}');
    }
  }
}

class BlockCellDto extends GridCellDto {
  const BlockCellDto();
}

class AnswerCellDto extends GridCellDto {
  final String value;
  final bool rightRedirect;
  final bool downRedirect;
  final String? rightSeparator;
  final String? downSeparator;

  const AnswerCellDto({
    required this.value,
    this.rightRedirect = false,
    this.downRedirect = false,
    this.rightSeparator,
    this.downSeparator,
  });

  factory AnswerCellDto.fromJson(Map<String, dynamic> json) => AnswerCellDto(
        value: json['value'] as String,
        rightRedirect: json['right_redirect'] as bool? ?? false,
        downRedirect: json['down_redirect'] as bool? ?? false,
        rightSeparator: json['right_separator'] as String?,
        downSeparator: json['down_separator'] as String?,
      );
}

class ClueCellDto extends GridCellDto {
  final String? right;
  final String? rightClueId;
  final String? rightWordId;
  final PositionDto? rightStart;
  final String? down;
  final String? downClueId;
  final String? downWordId;
  final PositionDto? downStart;

  const ClueCellDto({
    this.right,
    this.rightClueId,
    this.rightWordId,
    this.rightStart,
    this.down,
    this.downClueId,
    this.downWordId,
    this.downStart,
  });

  factory ClueCellDto.fromJson(Map<String, dynamic> json) {
    PositionDto? pos(String key) {
      final value = json[key];
      return value == null
          ? null
          : PositionDto.fromJson(value as Map<String, dynamic>);
    }

    return ClueCellDto(
      right: json['right'] as String?,
      rightClueId: json['right_clue_id'] as String?,
      rightWordId: json['right_word_id'] as String?,
      rightStart: pos('right_start'),
      down: json['down'] as String?,
      downClueId: json['down_clue_id'] as String?,
      downWordId: json['down_word_id'] as String?,
      downStart: pos('down_start'),
    );
  }
}
