/// Rol del usuario dentro de AbasteceApp.
///
/// Los dos roles son excluyentes: un mayorista no compra y un tendero no vende
/// al por mayor. La verificación de cada uno es diferida (ver `stores` y la
/// extensión legal de `suppliers`).
enum UserRole {
  supplier(
    'proveedor',
    'Proveedor / Mayorista',
    'Persona jurídica que vende al por mayor desde su bodega.',
  ),
  store(
    'tendero',
    'Tendero / Comerciante',
    'Comerciante minorista que compra para surtir su tienda de barrio.',
  );

  const UserRole(this.dbValue, this.label, this.description);

  final String dbValue;
  final String label;
  final String description;

  bool get isSupplier => this == UserRole.supplier;

  static UserRole? fromDb(String? value) {
    for (final UserRole role in values) {
      if (role.dbValue == value) return role;
    }
    return null;
  }
}

/// Mecanismo con el que el usuario creó o recuperó su cuenta.
enum AuthProviderType {
  phone('telefono', 'Celular'),
  google('google', 'Google'),
  email('correo', 'Correo y contraseña');

  const AuthProviderType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AuthProviderType fromDb(String? value) {
    for (final AuthProviderType provider in values) {
      if (provider.dbValue == value) return provider;
    }
    return AuthProviderType.email;
  }
}

/// Cuenta local del usuario (`users`).
///
/// Guarda solo lo mínimo necesario para autenticar y enrutar; los datos de
/// negocio viven en `stores` o en la extensión legal de `suppliers`.
class AppUser {
  const AppUser({
    this.id,
    this.phone,
    this.email,
    required this.authProvider,
    this.role,
    this.isActive = true,
    this.displayName,
    this.passwordHash,
    this.passwordSalt,
    this.onboardingCompleted = false,
    required this.createdAt,
    this.lastLoginAt,
  });

  final int? id;
  final String? phone;
  final String? email;
  final AuthProviderType authProvider;
  final UserRole? role;
  final bool isActive;
  final String? displayName;
  final String? passwordHash;
  final String? passwordSalt;

  /// `true` cuando el usuario ya eligió rol, aceptó términos y cargó su perfil.
  final bool onboardingCompleted;

  final DateTime createdAt;
  final DateTime? lastLoginAt;

  bool get hasRole => role != null;

  bool get canOperate => isActive && onboardingCompleted && role != null;

  /// Nombre visible: nombre de la persona, correo o celular.
  String get displayLabel {
    final String name = (displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final String mail = (email ?? '').trim();
    if (mail.isNotEmpty) return mail;
    final String tel = (phone ?? '').trim();
    if (tel.isNotEmpty) return tel;
    return 'Usuario';
  }

  String get contactLabel {
    final String mail = (email ?? '').trim();
    if (mail.isNotEmpty) return mail;
    return (phone ?? '').trim();
  }

  AppUser copyWith({
    int? id,
    String? phone,
    String? email,
    AuthProviderType? authProvider,
    UserRole? role,
    bool? isActive,
    String? displayName,
    String? passwordHash,
    String? passwordSalt,
    bool? onboardingCompleted,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      authProvider: authProvider ?? this.authProvider,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      displayName: displayName ?? this.displayName,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// Devuelve la cuenta sin rol ni onboarding (para volver a elegir rol).
  AppUser withoutRole() {
    return AppUser(
      id: id,
      phone: phone,
      email: email,
      authProvider: authProvider,
      isActive: isActive,
      displayName: displayName,
      passwordHash: passwordHash,
      passwordSalt: passwordSalt,
      onboardingCompleted: false,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'phone': phone,
      'email': email,
      'auth_provider': authProvider.dbValue,
      'role': role?.dbValue,
      'is_active': isActive ? 1 : 0,
      'display_name': displayName,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'onboarding_completed': onboardingCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: map['id'] as int?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      authProvider: AuthProviderType.fromDb(map['auth_provider'] as String?),
      role: UserRole.fromDb(map['role'] as String?),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      displayName: map['display_name'] as String?,
      passwordHash: map['password_hash'] as String?,
      passwordSalt: map['password_salt'] as String?,
      onboardingCompleted: (map['onboarding_completed'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      lastLoginAt: DateTime.tryParse(map['last_login_at'] as String? ?? ''),
    );
  }
}
