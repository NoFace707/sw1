class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;

  String get fullName => '$firstName $lastName'.trim();

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final firstName = json['first_name'];
    final lastName = json['last_name'];
    final email = json['email'];
    if (id is! int ||
        firstName is! String ||
        lastName is! String ||
        email is! String) {
      throw const FormatException('Usuario inválido.');
    }
    return AuthUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
  };
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
}
