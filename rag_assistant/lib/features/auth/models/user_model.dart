class UserModel {
  final String email;
  final String name;
  final String accessToken;
  final String refreshToken;

  const UserModel({
    required this.email,
    required this.name,
    required this.accessToken,
    required this.refreshToken,
  });
}
