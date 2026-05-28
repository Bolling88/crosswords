import 'package:flutter/material.dart';

class AnswerCellWidget extends StatelessWidget {
  final String? userInput;
  final bool isSelected;
  final bool isHighlighted;
  final double size;
  final VoidCallback onTap;

  const AnswerCellWidget({
    required this.size,
    required this.onTap,
    this.userInput,
    this.isSelected = false,
    this.isHighlighted = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF42A5F5)
              : isHighlighted
                  ? const Color(0xFFBBDEFB)
                  : Colors.white,
          border: Border.all(width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          userInput ?? '',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
