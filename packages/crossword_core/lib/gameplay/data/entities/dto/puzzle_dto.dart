import 'grid_dto.dart';
import 'position_dto.dart';

class PuzzleDto {
  final String title;
  final String languageCode;
  final GridDto grid;
  final List<PositionDto> seedPositions;

  const PuzzleDto({
    required this.title,
    required this.languageCode,
    required this.grid,
    required this.seedPositions,
  });

  factory PuzzleDto.fromJson(Map<String, dynamic> json) => PuzzleDto(
        title: json['title'] as String,
        languageCode: json['language_code'] as String,
        grid: GridDto.fromJson(json['grid'] as Map<String, dynamic>),
        seedPositions: (json['seed_positions'] as List)
            .map((p) => PositionDto.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
