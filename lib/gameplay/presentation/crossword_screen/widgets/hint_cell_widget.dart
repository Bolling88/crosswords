import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../gameplay/data/entities/cell.dart';
import '../../../../gameplay/data/entities/direction.dart';

class HintCellWidget extends StatelessWidget {
  final HintCell cell;
  final double size;
  final VoidCallback onTap;

  const HintCellWidget({
    required this.cell,
    required this.size,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF1A237E),
          border: Border.fromBorderSide(
            BorderSide(width: 0.5),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(size * 0.08),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    cell.clueText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: cell.arrows
                    .map((arrow) => _buildArrow(arrow))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(Direction direction) {
    final angle = switch (direction) {
      Direction.right => 0.0,
      Direction.down => pi / 2,
      Direction.downRight => pi / 4,
    };
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.arrow_forward,
        color: Colors.white,
        size: size * 0.25,
      ),
    );
  }
}
