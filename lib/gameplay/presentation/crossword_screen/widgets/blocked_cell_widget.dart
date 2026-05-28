import 'package:flutter/material.dart';

class BlockedCellWidget extends StatelessWidget {
  final double size;

  const BlockedCellWidget({required this.size, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF1A237E),
    );
  }
}
