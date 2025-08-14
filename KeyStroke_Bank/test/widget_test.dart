import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ket_stroke_bank/main.dart';
import 'package:ket_stroke_bank/screens/auth/login_screen.dart';
import 'package:ket_stroke_bank/screens/auth/signup_screen.dart';
import 'package:ket_stroke_bank/services/auth_service.dart';
import 'package:ket_stroke_bank/services/api_service.dart';

// Helper function to create and initialize AuthService with proper circular dependency resolution
(AuthService, ApiService) _createAuthAndApiServices() {
  // Create a late variable for ApiService to break the circular dependency
  late final ApiService apiService;
  
  // Create a temporary ApiService with a dummy AuthService
  final tempApiService = ApiService(
    baseUrl: 'http://localhost:3000/api',
    authService: AuthService(
      apiService: ApiService(baseUrl: 'http://localhost:3000/api', authService: null),
    ),
  );
  
  // Create the real AuthService with the temporary ApiService
  final authService = AuthService(apiService: tempApiService);
  
  // Now create the real ApiService with the authService
  apiService = ApiService(
    baseUrl: 'http://localhost:3000/api',
    authService: authService,
  );
  
  // Update the auth service's apiService reference to the real one
  authService.updateApiService(apiService);
  
  return (authService, apiService);
}

void main() {
  testWidgets('App shows login screen by default', (WidgetTester tester) async {
    // Create services with proper circular dependency resolution
    final (authService, _) = _createAuthAndApiServices();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
        ],
        child: const MaterialApp(
          home: KetStrokeBankApp(),
        ),
      ),
    );

    // Verify that the login screen is shown
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Can navigate to signup screen', (WidgetTester tester) async {
    // Create services with proper circular dependency resolution
    final (authService, _) = _createAuthAndApiServices();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
        ],
        child: const MaterialApp(
          home: KetStrokeBankApp(),
        ),
      ),
    );

    // Tap the 'Sign Up' button
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    // Verify that the signup screen is shown
    expect(find.text('Create Account'), findsOneWidget);
    expect(
      find.text('Fill in your details to create an account'),
      findsOneWidget,
    );
    expect(find.byType(SignUpScreen), findsOneWidget);
  });
}
