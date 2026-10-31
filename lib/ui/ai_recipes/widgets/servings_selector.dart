import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/themes/spacing.dart';

class ServingsSelector extends StatelessWidget {
  const ServingsSelector({
    required this.controller,
    required this.servings,
    required this.loading,
    required this.onChange,
    super.key,
  });

  final TextEditingController controller;
  final int servings;
  final bool loading;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: loading ? null : () => onChange(servings - 1),
            icon: const Icon(Icons.remove, size: 20),
            tooltip: 'Diminuir quantidade de pessoas',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !loading,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Quantidade de pessoas',
                prefixIcon: Icon(Icons.people_outline, size: 20),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            onPressed: loading ? null : () => onChange(servings + 1),
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'Aumentar quantidade de pessoas',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    ),
  );
}
