import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';
import 'services/connectivity_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/no_internet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MechanicCustomerApp(),
    ),
  );
}

class MechanicCustomerApp extends StatelessWidget {
  const MechanicCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Mechanic Help',
      theme: themeProvider.currentTheme,
      home: StreamBuilder<bool>(
        stream: ConnectivityService().isConnectedStream,
        initialData: true, 
        builder: (context, connectivitySnapshot) {
          final isConnected = connectivitySnapshot.data ?? true;
          
          if (!isConnected) {
            return const NoInternetScreen();
          }

          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeInCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: _buildAuthState(snapshot),
              );
            },
          );
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildAuthState(AsyncSnapshot<User?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Scaffold(
        key: const ValueKey('splash'),
        backgroundColor: Colors.redAccent,
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car, size: 80, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      "Mechanic Fast",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
    if (snapshot.hasData && snapshot.data != null) {
      return const MainScreen(key: ValueKey('main'));
    }
    return const LoginScreen(key: ValueKey('login'));
  }
}

