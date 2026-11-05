import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String userBoxName = 'users';
  static const String sessionBoxName = 'session';

  Box<User> get userBox => Hive.box<User>(userBoxName);
  Box get sessionBox => Hive.box(sessionBoxName);

  // Check if user is logged in
  bool get isLoggedIn {
    return sessionBox.get('currentUserId') != null;
  }

  // Get current user
  User? get currentUser {
    final userId = sessionBox.get('currentUserId');
    if (userId == null) return null;
    return userBox.get(userId);
  }

  // Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        return {'success': false, 'message': 'Format email tidak valid'};
      }

      // Check if email already exists
      final existingUser = userBox.values.firstWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
        orElse: () => User(
          id: '',
          email: '',
          password: '',
          name: '',
          createdAt: DateTime.now(),
        ),
      );

      if (existingUser.id.isNotEmpty) {
        return {'success': false, 'message': 'Email sudah terdaftar'};
      }

      // Validate password
      if (password.length < 6) {
        return {'success': false, 'message': 'Password minimal 6 karakter'};
      }

      // Create new user
      final user = User(
        id: const Uuid().v4(),
        email: email.toLowerCase(),
        password: password, // In production, hash this!
        name: name,
        createdAt: DateTime.now(),
      );

      await userBox.put(user.id, user);

      return {'success': true, 'message': 'Registrasi berhasil!', 'user': user};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      // Find user by email
      final user = userBox.values.firstWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
        orElse: () => User(
          id: '',
          email: '',
          password: '',
          name: '',
          createdAt: DateTime.now(),
        ),
      );

      if (user.id.isEmpty) {
        return {'success': false, 'message': 'Email tidak terdaftar'};
      }

      // Check password
      if (user.password != password) {
        return {'success': false, 'message': 'Password salah'};
      }

      // Update last login
      user.lastLogin = DateTime.now();
      await user.save();

      // Save session
      await sessionBox.put('currentUserId', user.id);

      return {'success': true, 'message': 'Login berhasil!', 'user': user};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    await sessionBox.delete('currentUserId');
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Find user by email
      final user = userBox.values.firstWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
        orElse: () => User(
          id: '',
          email: '',
          password: '',
          name: '',
          createdAt: DateTime.now(),
        ),
      );

      if (user.id.isEmpty) {
        return {'success': false, 'message': 'Email tidak terdaftar'};
      }

      // Validate new password
      if (newPassword.length < 6) {
        return {'success': false, 'message': 'Password minimal 6 karakter'};
      }

      // Update password
      user.password = newPassword;
      await user.save();

      return {'success': true, 'message': 'Password berhasil direset!'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Change password (when logged in)
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User tidak ditemukan'};
      }

      // Check old password
      if (user.password != oldPassword) {
        return {'success': false, 'message': 'Password lama salah'};
      }

      // Validate new password
      if (newPassword.length < 6) {
        return {
          'success': false,
          'message': 'Password baru minimal 6 karakter',
        };
      }

      // Update password
      user.password = newPassword;
      await user.save();

      return {'success': true, 'message': 'Password berhasil diubah!'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }
}
