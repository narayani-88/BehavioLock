import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/profile/add_card_screen.dart';
import 'screens/profile/my_cards_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/transaction_service.dart';
import 'services/bank_account_service.dart';
import 'services/card_service.dart';
import 'services/settings_service.dart';
import 'services/profile_service.dart';
import 'constants/app_theme.dart';
import 'config/api_config.dart';

void _setupLogging() {
  // Configure logging
  Logger.root.level = Level.ALL; // Default to all levels in debug mode

  // Add a listener that prints all log messages to the console
  Logger.root.onRecord.listen((record) {
    developer.log(
      '${record.level.name}: ${record.time}: ${record.message}',
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  // Log uncaught errors
  FlutterError.onError = (details) {
    // Check if this is a keyboard-related error
    if (details.exception.toString().contains('HardwareKeyboard') ||
        details.exception.toString().contains('KeyUpEvent') ||
        details.exception.toString().contains('_pressedKeys.containsKey')) {
      Logger('KeyboardError').warning(
        'Keyboard event error detected: ${details.exception}',
        details.exception,
        details.stack,
      );

      // Try to recover by syncing keyboard state
      try {
        HardwareKeyboard.instance.syncKeyboardState();
        Logger(
          'KeyboardError',
        ).info('Keyboard state resynchronized after error');
      } catch (e) {
        Logger(
          'KeyboardError',
        ).severe('Failed to resynchronize keyboard state: $e');
      }
      return;
    }

    Logger('FlutterError').severe(
      'Uncaught error: ${details.exception}',
      details.exception,
      details.stack,
    );
  };

  // Log uncaught Dart errors
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger('DartError').severe('Uncaught Dart error', error, stack);
    return true; // Prevent the error from being handled again
  };
}

void main() async {
  // Initialize logging first
  _setupLogging();
  WidgetsFlutterBinding.ensureInitialized();

  // Add keyboard state synchronization to prevent HardwareKeyboard assertion errors
  try {
    await HardwareKeyboard.instance.syncKeyboardState();
    Logger('main').info('Keyboard state synchronized successfully');
  } catch (e) {
    Logger('main').warning('Failed to sync keyboard state: $e');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Log app start
  final logger = Logger('main');
  logger.info('Starting KetStroke Bank App');

  try {
    // Get base URL from configuration
    final String baseUrl = ApiConfig.baseUrl;

    logger.info(
      'Platform: ${ApiConfig.isWeb
          ? "Web"
          : ApiConfig.isAndroid
          ? "Android"
          : "iOS"}',
    );
    logger.info('Base URL: $baseUrl');

    // Create services
    final authService = AuthService(
      apiService: ApiService(baseUrl: baseUrl, authService: null),
    );

    final apiService = ApiService(baseUrl: baseUrl, authService: authService);

    // Update the auth service's apiService reference
    authService.updateApiService(apiService);

    // Initialize auth service first and wait for it to complete
    await authService.initAuthService();

    // Only initialize other services if user is authenticated
    final bankAccountService = BankAccountService(apiService: apiService);
    final transactionService = TransactionService(
      apiService,
      bankAccountService: bankAccountService,
    );

    // If user is authenticated, initialize services
    if (authService.isAuthenticated) {
      logger.info('User is authenticated, initializing services');
      // Don't initialize services here - let them initialize when needed
    } else {
      logger.info(
        'User is not authenticated, services will work in offline mode',
      );
    }

    // Create the app with all providers
    runApp(
      MultiProvider(
        providers: [
          Provider.value(value: apiService),
          ChangeNotifierProvider.value(value: authService),
          ChangeNotifierProvider.value(value: transactionService),
          ChangeNotifierProvider.value(value: bankAccountService),
          ChangeNotifierProvider(
            create: (_) =>
                CardService(apiService: apiService, authService: authService),
          ),
          ChangeNotifierProvider(
            create: (_) => SettingsService()..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                ProfileService(authService: authService, apiService: apiService)
                  ..initialize(),
          ),
        ],
        child: const KetStrokeBankApp(),
      ),
    );
  } catch (e, stackTrace) {
    logger.severe('Failed to initialize services', e, stackTrace);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize app: ${e.toString()}'),
          ),
        ),
      ),
    );
  }
}

class KetStrokeBankApp extends StatelessWidget {
  const KetStrokeBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KetStroke Bank',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      routes: {
        '/add-card': (context) => const AddCardScreen(),
        '/my-cards': (context) => const MyCardsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showLogin = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    if (!mounted) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.initAuthService();

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });
    } catch (e, stackTrace) {
      Logger('AuthWrapper').severe('Error initializing auth', e, stackTrace);
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize authentication')),
        );
      }
    }
  }

  void _toggleAuthScreen() {
    setState(() {
      _showLogin = !_showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Selector<AuthService, bool>(
      selector: (_, authService) => authService.isAuthenticated,
      builder: (context, isAuthenticated, child) {
        if (isAuthenticated) {
          return const DashboardScreen();
        }

        return _showLogin
            ? LoginScreen(
                onSignUpPressed: _toggleAuthScreen,
                onForgotPasswordPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
              )
            : SignUpScreen(onLoginPressed: _toggleAuthScreen);
      },
    );
  }
}
