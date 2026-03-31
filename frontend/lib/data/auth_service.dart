import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  // Use 10.0.2.2 for Android emulator to access host localhost
  // Use localhost for iOS simulator
  // Use your machine's IP for real devices
  // Use 10.0.2.2 for Android emulator
  // Use 172.16.103.10 when testing on physical devices on the same Wi-Fi
  static const String _baseUrl = 'http://10.207.162.125:3000/api/auth';

  bool _isLoggedIn = false;
  String? _currentUser; // Email
  String? _currentUserName;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  String? get currentUser => _currentUser;
  String? get currentUserName => _currentUserName;
  String? get errorMessage => _errorMessage;

  // Check if user is already logged in (persisted session)
  Future<void> checkLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('user_email');
      final savedName = prefs.getString('user_name');
      
      if (savedEmail != null && savedName != null) {
        _isLoggedIn = true;
        _currentUser = savedEmail;
        _currentUserName = savedName;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking login state: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _isLoggedIn = true;
        _currentUser = email;
        _currentUserName = data['name'] ?? 'User';
        
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        await prefs.setString('user_name', _currentUserName!);
        
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? 'Login failed.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection Error: $e';
      debugPrint('Login Error: $e');
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _errorMessage = null;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Auto-login after signup
        _isLoggedIn = true;
        _currentUser = email;
        _currentUserName = name;
        
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        await prefs.setString('user_name', name);
        
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? 'Signup failed.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection Error: $e';
      debugPrint('Signup Error: $e');
      return false;
    }
  }



  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    _currentUserName = null;
    
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    notifyListeners();
  }
}
