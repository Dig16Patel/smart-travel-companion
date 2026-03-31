import 'package:smart_travel_app/data/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Mock Flutter binding
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load env
  try {
    await dotenv.load(fileName: ".env");
    print("Loaded .env");
  } catch (e) {
    print("Failed to load .env: $e");
  }

  final authService = AuthService();
  final testEmail = "test_${DateTime.now().millisecondsSinceEpoch}@example.com";
  
  print("Attempting signup with: $testEmail");
  
  try {
    final success = await authService.signup("Test User", testEmail, "password123");
    
    if (success) {
      print("Signup SUCCESS");
    } else {
      print("Signup FAILED. Error: ${authService.errorMessage}");
    }
  } catch (e) {
    print("Signup EXCEPTION: $e");
  } finally {
    authService.dispose();
  }
}
