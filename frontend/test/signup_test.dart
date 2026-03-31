import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_guide_app/data/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Signup Test', () async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Load env (mock)
    dotenv.testLoad(fileInput: "RAPIDAPI_KEY=test\nMONGO_URI=mongodb+srv://23it088:200621@cluster0.nhh5r.mongodb.net/?appName=Cluster0\nCOLLECTION_NAME=users");

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
  });
}
