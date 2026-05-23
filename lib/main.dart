import 'package:flutter/material.dart';
import 'core/theme/anvi_theme.dart';
import 'core/widgets/ambient_background.dart';
import 'core/widgets/anvi_logo.dart';
import 'screens/model_picker_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnviApp());
}

class AnviApp extends StatelessWidget {
  final bool lockSplash;

  const AnviApp({super.key, this.lockSplash = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anvi',
      debugShowCheckedModeBanner: false,
      theme: AnviTheme.dark(),
      home: _AnviSplashGate(lockSplash: lockSplash),
    );
  }
}

class _AnviSplashGate extends StatefulWidget {
  final bool lockSplash;

  const _AnviSplashGate({required this.lockSplash});

  @override
  State<_AnviSplashGate> createState() => _AnviSplashGateState();
}

class _AnviSplashGateState extends State<_AnviSplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.lockSplash) return;
    Future<void>.delayed(const Duration(milliseconds: 1450), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 620),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready ? const ModelPickerScreen() : const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnviLogo(size: 92, pulse: true),
              const SizedBox(height: 26),
              Text(
                'Anvi',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Offline intelligence, alive on-device',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
