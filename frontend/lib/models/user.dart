// Модель пользователя приложения Bookly
class AppUser {
  final int id;
  final String email;
  final String displayName;

  AppUser({required this.id, required this.email, required this.displayName});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      email: json['email'],
      displayName: json['displayName'],
    );
  }
}
