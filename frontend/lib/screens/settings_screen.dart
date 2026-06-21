import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/theme_controller.dart';

// Экран настроек приложения: редактирование имени/email профиля
// и выбор оформления (светлая/тёмная тема).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  AppUser? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getStoredUser();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  // Диалог редактирования имени или email — переиспользуется для обоих полей,
  // так как структура одинаковая, отличается только заголовок, текст поля и валидация.
  Future<void> _showEditFieldDialog({
    required String title,
    required String currentValue,
    required String fieldLabel,
    required TextInputType keyboardType,
    required Future<void> Function(String newValue) onSave,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controller,
                      keyboardType: keyboardType,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: fieldLabel,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Поле не может быть пустым';
                        }
                        if (keyboardType == TextInputType.emailAddress &&
                            !value.contains('@')) {
                          return 'Введите корректный email';
                        }
                        return null;
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      await onSave(controller.text.trim());
                      if (context.mounted) Navigator.of(context).pop();
                      _loadUser();
                    } catch (e) {
                      setDialogState(() {
                        errorMessage = e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileSection(),
                  const SizedBox(height: 16),
                  _buildThemeSection(context),
                ],
              ),
      ),
    );
  }

  // Секция редактирования профиля: имя и email, каждое поле открывает
  // отдельный диалог редактирования при нажатии.
  Widget _buildProfileSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Имя'),
            subtitle: Text(_user?.displayName ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEditFieldDialog(
              title: 'Изменить имя',
              currentValue: _user?.displayName ?? '',
              fieldLabel: 'Имя',
              keyboardType: TextInputType.text,
              onSave: (newValue) async {
                await _authService.updateProfile(displayName: newValue);
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(_user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEditFieldDialog(
              title: 'Изменить email',
              currentValue: _user?.email ?? '',
              fieldLabel: 'Email',
              keyboardType: TextInputType.emailAddress,
              onSave: (newValue) async {
                await _authService.updateProfile(email: newValue);
              },
            ),
          ),
        ],
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
