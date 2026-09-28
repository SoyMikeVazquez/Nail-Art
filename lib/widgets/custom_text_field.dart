import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final List<dynamic>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Increased opacity
            blurRadius: 15, // Increased blur
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onChanged: onChanged,
        maxLines: obscureText ? 1 : maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters?.cast<TextInputFormatter>(),
        style: const TextStyle(height: 1.2), // Adjust content height
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '', // Hide the 0/10 counter
          border: InputBorder.none, // No border
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
