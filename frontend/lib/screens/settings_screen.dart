import 'package:flutter/material.dart';
import '../utils/theme_controller.dart';

// Экран настроек приложения. Сейчас содержит только выбор оформления
// (светлая/тёмная тема), но задуман как точка роста для будущих опций.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildThemeSection(context),
          ],
        ),
      ),
    );
  }

  // Секция выбора оформления: светлая или тёмная.
  // Подписана на ThemeController, чтобы сразу отражать текущий выбор
  // и мгновенно применять его ко всему приложению.
  // Кнопки реализованы через Row + Expanded, а не SegmentedButton,
  // чтобы они гарантированно делили всю доступную ширину пополам.
  Widget _buildThemeSection(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Оформление', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ThemeOptionButton(
                        label: 'Светлая',
                        icon: Icons.light_mode_outlined,
                        selected: !isDark,
                        color: colorScheme.primary,
                        onTap: () => ThemeController.setTheme(ThemeMode.light),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ThemeOptionButton(
                        label: 'Тёмная',
                        icon: Icons.dark_mode_outlined,
                        selected: isDark,
                        color: colorScheme.primary,
                        onTap: () => ThemeController.setTheme(ThemeMode.dark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Одна кнопка выбора темы. Растягивается на всю ширину родителя (Expanded),
// поэтому при использовании в Row с двумя такими кнопками они делят
// доступное пространство ровно пополам.
class _ThemeOptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ThemeOptionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade400,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Icon(Icons.check, size: 16, color: color),
                const SizedBox(width: 4),
              ] else ...[
                Icon(icon, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : Colors.grey.shade700,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
