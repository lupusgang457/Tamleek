import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat, ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (TamleekSupabaseOptions.isConfigured) {
    await Supabase.initialize(
      url: TamleekSupabaseOptions.url,
      publishableKey: TamleekSupabaseOptions.publishableKey,
    );
  }
  runApp(const TamleekApp());
}

class _PasswordRecoveryPage extends StatefulWidget {
  const _PasswordRecoveryPage();

  @override
  State<_PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<_PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Le mot de passe n’a pas pu être modifié. ${error.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nouveau mot de passe')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choisissez un nouveau mot de passe pour votre compte Tamleek.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('recovery-password-input'),
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                validator: (value) => (value == null || value.length < 8)
                    ? 'Utilisez au moins 8 caractères.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('recovery-confirm-password-input'),
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                ),
                validator: (value) => value != _passwordController.text
                    ? 'Les mots de passe ne correspondent pas.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Enregistrer le mot de passe'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const _ink = Colors.black;
const _muted = Colors.black;
const _page = Color(0xFFF5F6FB);
const _investmentAvailableBalance = 8250.0;
const _fractionalInvestmentMinimum = 10.0;
const _wholeInvestmentMinimum = 1000.0;
const _fractionalMonthlyReturn = 0.20;
const _resaleFeeRate = 0.05;
const _registrationCompleteKey = 'tamleek.registration.complete';
const _profileNameKey = 'tamleek.profile.name';
const _profileEmailKey = 'tamleek.profile.email';
const _profilePhoneKey = 'tamleek.profile.phone';
const _profilePhotoKey = 'tamleek.profile.photo';
const _languagePreferenceKey = 'tamleek.language';
const _tamleekSupportEmail = 'tamleek.contact@gmail.com';
const _tamleekWebsiteUrl = 'https://www.tamleek.ae/';
const _tamleekFacebookUrl = 'https://www.facebook.com/share/19zxueAV7K/';
const _tamleekYouTubeUrl =
    'https://youtube.com/@tamleekrealestateco5031?si=coJCsHz5c0GJH_q7';
String get _supabaseAuthRedirectUrl =>
    kIsWeb ? Uri.base.origin : 'tamleek://login-callback/';
const _depositDestinations = <String, (String, String)>{
  'Polygon': (
    '0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863',
    'assets/deposit_polygon_qr.jpg',
  ),
  'Solana': (
    'Yp2iCDR4rmMiYrfHJh7iucvEWkSCUAhbZPUrqF9T1SK',
    'assets/deposit_solana_qr.png',
  ),
  'BNB Smart Chain': (
    '0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863',
    'assets/deposit_bnb_qr.png',
  ),
  'TRON (TRC-20)': (
    'TARxxEKmcTttRA5Gs8MgheH7PXGRsaV3fd',
    'assets/deposit_tron_qr.png',
  ),
  'Ethereum (ERC-20)': (
    '0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863',
    'assets/deposit_ethereum_qr.png',
  ),
};

class TamleekApp extends StatelessWidget {
  const TamleekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tamleek',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF131722),
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const _RegistrationGate(),
    );
  }
}

class _RegistrationGate extends StatefulWidget {
  const _RegistrationGate();

  @override
  State<_RegistrationGate> createState() => _RegistrationGateState();
}

class _RegistrationGateState extends State<_RegistrationGate> {
  late final Future<bool> _registrationStatus;

  @override
  void initState() {
    super.initState();
    _registrationStatus = _loadRegistrationStatus();
  }

  Future<bool> _loadRegistrationStatus() async {
    if (TamleekSupabaseOptions.isConfigured) {
      return Supabase.instance.client.auth.currentSession != null;
    }
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_registrationCompleteKey) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (TamleekSupabaseOptions.isConfigured) {
      return StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Impossible de vérifier la session Supabase.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          final session =
              snapshot.data?.session ??
              Supabase.instance.client.auth.currentSession;
          if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
            return const _PasswordRecoveryPage();
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              session == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return session == null
              ? const _RegistrationPage()
              : const InvestmentPage();
        },
      );
    }
    return FutureBuilder<bool>(
      future: _registrationStatus,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Impossible de vérifier l’état de l’inscription locale.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!
            ? const InvestmentPage()
            : const _RegistrationPage();
      },
    );
  }
}

class _RegistrationPage extends StatefulWidget {
  const _RegistrationPage();

  @override
  State<_RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<_RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _acceptedTerms = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _saving = false;
  String? _registrationError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      setState(
        () => _registrationError = 'Acceptez les conditions pour continuer.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _registrationError = null;
    });
    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final phone = _phoneController.text.trim();
      if (TamleekSupabaseOptions.isConfigured) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: _passwordController.text,
          emailRedirectTo: _supabaseAuthRedirectUrl,
          data: {'name': name, 'phone': phone},
        );
        if (response.session == null) {
          if (!mounted) return;
          setState(() => _saving = false);
          await _showNotice(
            'Confirmez votre adresse e-mail',
            'Un lien de confirmation a été envoyé à $email. Ouvrez-le avant '
                'de vous connecter.',
          );
          return;
        }
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const InvestmentPage()),
        );
        return;
      }

      final preferences = await SharedPreferences.getInstance();
      final saved = await Future.wait([
        preferences.setString(_profileNameKey, name),
        preferences.setString(_profileEmailKey, email),
        preferences.setString(_profilePhoneKey, phone),
      ]);
      if (saved.any((result) => !result)) {
        if (mounted) {
          setState(() {
            _saving = false;
            _registrationError =
                'Le profil local n’a pas pu être enregistré. Réessayez.';
          });
        }
        return;
      }
      final registered = await preferences.setBool(
        _registrationCompleteKey,
        true,
      );
      if (!registered) {
        if (mounted) {
          setState(() {
            _saving = false;
            _registrationError =
                'Le statut d’inscription n’a pas pu être enregistré.';
          });
        }
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const InvestmentPage()),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _registrationError = switch (error.code) {
          'email_exists' ||
          'user_already_exists' => 'Cette adresse e-mail est déjà utilisée.',
          'weak_password' => 'Choisissez un mot de passe plus sécurisé.',
          _ => 'La création du compte a échoué. ${error.message}',
        };
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _registrationError =
            'Le profil Supabase n’a pas pu être enregistré. '
            '${error.message}';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _registrationError =
            'Le profil local n’a pas pu être enregistré. '
            '${error.message ?? ''}';
      });
    }
  }

  Future<void> _showNotice(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().length < 2) {
      return 'Saisissez votre nom complet.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Saisissez une adresse e-mail valide.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (!RegExp(r'^\+?[0-9\s()-]{8,18}$').hasMatch(phone)) {
      return 'Saisissez un numéro de téléphone valide.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }
    return null;
  }

  Widget _buildField({
    required Key key,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF202124), size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFE5E6E9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFE5E6E9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                key: const ValueKey('signup-hero'),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: SizedBox(
                  height: 310 + statusBarHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/reit.jpg', fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xDDF4F8FF),
                              Color(0x55FFFFFF),
                              Color(0x11000000),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        top: statusBarHeight + 10,
                        left: 20,
                        right: 16,
                        child: Row(
                          children: [
                            ClipRRect(
                              key: const ValueKey('signup-logo'),
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/tamleek_logo.jpg',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Tamleek',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 18,
                        top: statusBarHeight + 100,
                        child: Container(
                          key: const ValueKey('signup-hero-copy-card'),
                          width: 232,
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Inscription',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Rejoignez Tamleek et accédez à un large '
                                'choix de biens immobiliers.',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Container(
                                width: 56,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC32B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildField(
                        key: const ValueKey('signup-name-input'),
                        controller: _nameController,
                        hint: 'Nom complet',
                        icon: Icons.person_outline_rounded,
                        validator: _validateName,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 9),
                      _buildField(
                        key: const ValueKey('signup-email-input'),
                        controller: _emailController,
                        hint: 'Adresse e-mail',
                        icon: Icons.mail_outline_rounded,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 9),
                      _buildField(
                        key: const ValueKey('signup-phone-input'),
                        controller: _phoneController,
                        hint: 'Numéro de téléphone',
                        icon: Icons.phone_outlined,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 9),
                      _buildField(
                        key: const ValueKey('signup-password-input'),
                        controller: _passwordController,
                        hint: 'Mot de passe',
                        icon: Icons.lock_outline_rounded,
                        validator: _validatePassword,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.next,
                        suffixIcon: IconButton(
                          key: const ValueKey('signup-password-visibility'),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      _buildField(
                        key: const ValueKey('signup-confirm-password-input'),
                        controller: _confirmPasswordController,
                        hint: 'Confirmer le mot de passe',
                        icon: Icons.lock_outline_rounded,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas.';
                          }
                          return null;
                        },
                        obscureText: !_showConfirmPassword,
                        textInputAction: TextInputAction.done,
                        suffixIcon: IconButton(
                          key: const ValueKey(
                            'signup-confirm-password-visibility',
                          ),
                          onPressed: () => setState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          ),
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: Checkbox(
                              key: const ValueKey('signup-terms-checkbox'),
                              value: _acceptedTerms,
                              onChanged: (value) => setState(() {
                                _acceptedTerms = value ?? false;
                                _registrationError = null;
                              }),
                              side: const BorderSide(
                                color: Color(0xFF222222),
                                width: 1.6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                  children: [
                                    TextSpan(text: 'J’accepte les '),
                                    TextSpan(
                                      text: 'Conditions d’utilisation',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(text: ' et la '),
                                    TextSpan(
                                      text: 'Politique de confidentialité.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_registrationError != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _registrationError!,
                            key: const ValueKey('signup-error'),
                            style: const TextStyle(
                              color: Color(0xFFB3261E),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('signup-submit'),
                          onPressed: _saving ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Créer mon compte',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Votre profil sera enregistré sur cet appareil.',
                        style: TextStyle(
                          color: Color(0xFF737780),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 17),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Ou s’inscrire avec',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.72),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton(
                          key: const ValueKey('signup-google-button'),
                          onPressed: () => _showNotice(
                            'Google non configuré',
                            'La connexion Google n’est pas encore connectée à '
                                'un service d’authentification. Utilisez le '
                                'formulaire pour enregistrer un profil local.',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            side: const BorderSide(color: Color(0xFFE5E6E9)),
                            shape: const StadiumBorder(),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'G',
                                style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 15),
                              Text(
                                'Google',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Déjà un compte ? ',
                            style: TextStyle(color: _ink, fontSize: 14),
                          ),
                          TextButton(
                            key: const ValueKey('signup-login-button'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const _LoginPage(),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: _ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage();

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? value) {
    final identifier = (value ?? '').trim();
    final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(identifier);
    final isPhone = RegExp(r'^\+?[0-9\s()-]{8,18}$').hasMatch(identifier);
    if (!isEmail && !isPhone) {
      return 'Saisissez une adresse e-mail ou un numéro valide.';
    }
    return null;
  }

  Future<void> _showNotice(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (TamleekSupabaseOptions.isConfigured) {
      final email = _identifierController.text.trim();
      if (!email.contains('@')) {
        await _showNotice(
          'Connexion indisponible',
          'La connexion par numéro de téléphone n’est pas encore configurée. '
              'Utilisez l’adresse e-mail de votre compte.',
        );
        return;
      }
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: _passwordController.text,
        );
        if (!mounted) return;
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const InvestmentPage()),
          (_) => false,
        );
      } on AuthException catch (error) {
        if (!mounted) return;
        await _showNotice(
          'Connexion impossible',
          'La connexion a échoué. ${error.message}',
        );
      } on PostgrestException catch (error) {
        if (!mounted) return;
        await _showNotice(
          'Connexion impossible',
          'Le service Supabase est indisponible. ${error.message}',
        );
      }
      return;
    }
    _showNotice(
      'Connexion indisponible',
      'La connexion n’est pas encore reliée à un service sécurisé. '
          'Aucun mot de passe n’est enregistré dans cette application.',
    );
  }

  Future<void> _sendPasswordReset() async {
    final email = _identifierController.text.trim();
    if (!email.contains('@')) {
      await _showNotice(
        'Adresse e-mail requise',
        'Saisissez l’adresse e-mail de votre compte pour recevoir le lien.',
      );
      return;
    }
    if (!TamleekSupabaseOptions.isConfigured) {
      await _showNotice(
        'Réinitialisation indisponible',
        'La récupération du mot de passe nécessite un service '
            'd’authentification.',
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _supabaseAuthRedirectUrl,
      );
      if (!mounted) return;
      await _showNotice(
        'E-mail envoyé',
        'Si cette adresse possède un compte, un lien de réinitialisation lui '
            'a été envoyé.',
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      await _showNotice(
        'Réinitialisation impossible',
        'Le lien n’a pas pu être envoyé. ${error.message}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                key: const ValueKey('login-hero'),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: SizedBox(
                  height: 330 + statusBarHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/reit.jpg', fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xDDF4F8FF),
                              Color(0x55FFFFFF),
                              Color(0x11000000),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        top: statusBarHeight + 10,
                        left: 20,
                        child: Row(
                          children: [
                            ClipRRect(
                              key: const ValueKey('login-logo'),
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/tamleek_logo.jpg',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Tamleek',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 18,
                        top: statusBarHeight + 98,
                        child: Container(
                          key: const ValueKey('login-hero-copy-card'),
                          width: 232,
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Connexion',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Bon retour ! Accédez à votre compte pour '
                                'continuer.',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Container(
                                width: 56,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC32B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('login-identifier-input'),
                        controller: _identifierController,
                        validator: _validateIdentifier,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'Adresse e-mail ou numéro de téléphone',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E6E9),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E6E9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        key: const ValueKey('login-password-input'),
                        controller: _passwordController,
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Saisissez votre mot de passe.'
                            : null,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            key: const ValueKey('login-password-visibility'),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E6E9),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E6E9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            key: const ValueKey('login-remember-checkbox'),
                            value: _rememberMe,
                            onChanged: (value) =>
                                setState(() => _rememberMe = value ?? false),
                          ),
                          const Expanded(
                            child: Text(
                              'Se souvenir de moi',
                              style: TextStyle(color: _ink, fontSize: 12),
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('login-forgot-password'),
                            onPressed: _sendPasswordReset,
                            style: TextButton.styleFrom(
                              foregroundColor: _ink,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('login-submit'),
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Ou se connecter avec',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.72),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton(
                          key: const ValueKey('login-google-button'),
                          onPressed: () => _showNotice(
                            'Google non configuré',
                            'La connexion Google n’est pas encore reliée à un '
                                'service d’authentification.',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            side: const BorderSide(color: Color(0xFFE5E6E9)),
                            shape: const StadiumBorder(),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'G',
                                style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 15),
                              Text(
                                'Google',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Vous n’avez pas de compte ? ',
                            style: TextStyle(color: _ink, fontSize: 13),
                          ),
                          TextButton(
                            key: const ValueKey('login-create-account'),
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: _ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Créer un compte',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum InvestmentType { reit, crypto, fpi, action, commodity }

enum _WalletFlow { deposit, withdraw }

class _TransactionReceipt {
  const _TransactionReceipt({
    required this.reference,
    required this.date,
    required this.operation,
    required this.amount,
    required this.details,
    required this.status,
    required this.notice,
    required this.backgroundAsset,
    this.dateLabel,
    this.totalLabel = 'Montant total',
  });

  final String reference;
  final DateTime date;
  final String operation;
  final double amount;
  final List<(String, String)> details;
  final String status;
  final String notice;
  final String backgroundAsset;
  final String? dateLabel;
  final String totalLabel;
}

class _ScallopedReceiptClipper extends CustomClipper<Path> {
  const _ScallopedReceiptClipper();

  static const _toothWidth = 18.0;
  static const _depth = 5.0;

  @override
  Path getClip(Size size) {
    if (size.isEmpty) return Path();

    final path = Path()..moveTo(0, 0);
    var x = 0.0;
    while (x < size.width) {
      final nextX = math.min(x + _toothWidth, size.width).toDouble();
      path.quadraticBezierTo((x + nextX) / 2, _depth * 2, nextX, 0);
      x = nextX;
    }

    var y = 0.0;
    while (y < size.height) {
      final nextY = math.min(y + _toothWidth, size.height).toDouble();
      path.quadraticBezierTo(
        size.width - _depth * 2,
        (y + nextY) / 2,
        size.width,
        nextY,
      );
      y = nextY;
    }

    x = size.width;
    while (x > 0) {
      final nextX = math.max(x - _toothWidth, 0).toDouble();
      path.quadraticBezierTo(
        (x + nextX) / 2,
        size.height - _depth * 2,
        nextX,
        size.height,
      );
      x = nextX;
    }

    y = size.height;
    while (y > 0) {
      final nextY = math.max(y - _toothWidth, 0).toDouble();
      path.quadraticBezierTo(_depth * 2, (y + nextY) / 2, 0, nextY);
      y = nextY;
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _ScallopedReceiptClipper oldClipper) => false;
}

class _ScallopedReceiptBorderPainter extends CustomPainter {
  const _ScallopedReceiptBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _ScallopedReceiptClipper().getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE5AD16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScallopedReceiptBorderPainter oldDelegate) =>
      false;
}

enum _InvestmentMode { fractional, whole }

enum _ProfileField { name, phone }

enum _ProfilePhotoAction { choose, remove }

class _ReitHolding {
  const _ReitHolding({
    required this.name,
    required this.ticker,
    this.allocation,
  });

  final String name;
  final String ticker;
  final String? allocation;
}

class _HoldingPosition {
  const _HoldingPosition({
    required this.id,
    required this.category,
    required this.packId,
    required this.name,
    required this.subtitle,
    required this.value,
    required this.costBasis,
    required this.quantity,
    required this.purchaseDate,
    required this.icon,
    required this.color,
    required this.monthlyHistory,
    required this.annualHistory,
  });

  final String id;
  final String category;
  final String packId;
  final String name;
  final String subtitle;
  final double value;
  final double costBasis;
  final String quantity;
  final String purchaseDate;
  final IconData icon;
  final Color color;
  final List<(String, double)> monthlyHistory;
  final List<(String, double)> annualHistory;

  double get pnl => value - costBasis;
  double get pnlPercent => costBasis == 0 ? 0 : pnl / costBasis * 100;
  double get portfolioShare => value / 4200 * 100;
}

const _demoHoldings = [
  _HoldingPosition(
    id: 'global-reit',
    category: 'REIT',
    packId: 'mondial',
    name: 'Global Real Estate REIT',
    subtitle: 'Fonds immobilier',
    value: 1800,
    costBasis: 1650,
    quantity: '12 parts',
    purchaseDate: '15 janv. 2024',
    icon: Icons.apartment_rounded,
    color: Color(0xFF3769C8),
    monthlyHistory: [
      ('Juil', 8),
      ('Août', 9),
      ('Sept', 11),
      ('Oct', 10),
      ('Nov', 12),
      ('Déc', 14),
    ],
    annualHistory: [('2023', 78), ('2024', 104), ('2025', 126)],
  ),
  _HoldingPosition(
    id: 'bitcoin',
    category: 'Crypto',
    packId: 'majors',
    name: 'Bitcoin (BTC)',
    subtitle: 'Cryptomonnaie',
    value: 1250,
    costBasis: 1400,
    quantity: '0.025 BTC',
    purchaseDate: '03 mars 2024',
    icon: Icons.currency_bitcoin_rounded,
    color: Color(0xFFF49A17),
    monthlyHistory: [
      ('Juil', -30),
      ('Août', 22),
      ('Sept', -14),
      ('Oct', 38),
      ('Nov', 17),
      ('Déc', -9),
    ],
    annualHistory: [('2023', 120), ('2024', -64), ('2025', -150)],
  ),
  _HoldingPosition(
    id: 'fpi-performance',
    category: 'FPI',
    packId: 'europeen',
    name: 'FPI Performance',
    subtitle: 'Fonds immobilier',
    value: 750,
    costBasis: 700,
    quantity: '8 parts',
    purchaseDate: '22 juin 2024',
    icon: Icons.show_chart_rounded,
    color: Color(0xFF188A58),
    monthlyHistory: [
      ('Juil', 3),
      ('Août', 4),
      ('Sept', 5),
      ('Oct', 5),
      ('Nov', 6),
      ('Déc', 7),
    ],
    annualHistory: [('2023', 22), ('2024', 38), ('2025', 54)],
  ),
  _HoldingPosition(
    id: 'gold',
    category: 'Matières premières',
    packId: 'metaux-precieux',
    name: 'Or',
    subtitle: 'Matières premières',
    value: 400,
    costBasis: 350,
    quantity: '2 g',
    purchaseDate: '08 sept. 2024',
    icon: Icons.diamond_rounded,
    color: Color(0xFFBD8117),
    monthlyHistory: [
      ('Juil', 2),
      ('Août', 3),
      ('Sept', 3),
      ('Oct', 4),
      ('Nov', 4),
      ('Déc', 5),
    ],
    annualHistory: [('2023', 11), ('2024', 28), ('2025', 42)],
  ),
];

class _AllocationDonutPainter extends CustomPainter {
  const _AllocationDonutPainter(this.allocations);

  final List<(double, Color)> allocations;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final strokeWidth = math.max(8.0, radius * 0.34);
    var startAngle = -math.pi / 2;

    for (final (share, color) in allocations) {
      canvas.drawArc(
        bounds,
        startAngle,
        math.pi * 2 * share,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      startAngle += math.pi * 2 * share;
    }
  }

  @override
  bool shouldRepaint(_AllocationDonutPainter oldDelegate) =>
      oldDelegate.allocations != allocations;
}

class _MonthlyPnlPainter extends CustomPainter {
  const _MonthlyPnlPainter({required this.values, required this.color});

  final List<(String, double)> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const horizontalInset = 7.0;
    const topInset = 8.0;
    const bottomInset = 8.0;
    final zeroY = size.height * 0.68;
    final positiveMax = values.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.$2),
    );
    final negativeMax = values.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, -item.$2),
    );
    final barWidth = (size.width - horizontalInset * 2) / values.length * 0.48;
    final step = (size.width - horizontalInset * 2) / values.length;
    final baselinePaint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(horizontalInset, zeroY),
      Offset(size.width - horizontalInset, zeroY),
      baselinePaint,
    );

    for (var index = 0; index < values.length; index++) {
      final value = values[index].$2;
      final barHeight = value >= 0
          ? (positiveMax == 0 ? 0 : value / positiveMax * (zeroY - topInset))
          : (negativeMax == 0
                ? 0
                : -value / negativeMax * (size.height - zeroY - bottomInset));
      final centerX = horizontalInset + step * (index + 0.5);
      final rect = value >= 0
          ? Rect.fromLTRB(
              centerX - barWidth / 2,
              zeroY - barHeight,
              centerX + barWidth / 2,
              zeroY,
            )
          : Rect.fromLTRB(
              centerX - barWidth / 2,
              zeroY,
              centerX + barWidth / 2,
              zeroY + barHeight,
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = value >= 0 ? color : const Color(0xFFFFB3B3)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_MonthlyPnlPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _ReitPack {
  const _ReitPack({
    required this.id,
    required this.name,
    required this.summary,
    required this.description,
    required this.holdings,
    required this.icon,
  });

  final String id;
  final String name;
  final String summary;
  final String description;
  final List<_ReitHolding> holdings;
  final IconData icon;
}

class _HeroSlide {
  const _HeroSlide({
    required this.type,
    required this.image,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.icon,
  });

  final InvestmentType type;
  final String image;
  final String tag;
  final String title;
  final String subtitle;
  final String action;
  final IconData icon;
}

const _reitPacks = [
  _ReitPack(
    id: 'commerce',
    name: 'Commerce de proximité',
    summary: 'Commerces essentiels et revenus réguliers',
    description:
        'Ce pack regroupe des REITs spécialisés dans l’immobilier commercial '
        'de nécessité : supermarchés, pharmacies, magasins discount, '
        'stations-service, cliniques de proximité et commerces alimentaires. '
        'Les locataires vendent des produits de première nécessité, ce qui '
        'peut soutenir la demande même en période de ralentissement. Les '
        'baux sont généralement longs, souvent de dix à quinze ans, avec des '
        'clauses d’indexation des loyers. Les taux d’occupation de ces '
        'portefeuilles dépassent souvent 95 %. Realty Income verse son '
        'dividende chaque mois. Le risque principal reste la hausse des taux '
        'd’intérêt, susceptible de peser sur le cours et le financement.',
    icon: Icons.storefront_rounded,
    holdings: [
      _ReitHolding(name: 'Realty Income', ticker: 'O'),
      _ReitHolding(name: 'Agree Realty', ticker: 'ADC'),
      _ReitHolding(name: 'NNN REIT', ticker: 'NNN'),
    ],
  ),
  _ReitPack(
    id: 'residentiel',
    name: 'Résidentiel',
    summary: 'Immeubles locatifs aux États-Unis et en Europe',
    description:
        'Ce pack rassemble des REITs propriétaires et exploitants '
        'd’immeubles d’appartements locatifs, principalement aux États-Unis '
        'et en Europe. Le logement est un besoin fondamental. Les baux '
        'résidentiels plus courts permettent de réajuster les loyers, et la '
        'demande est soutenue par la croissance démographique et '
        'l’urbanisation. Les taux d’occupation dépassent souvent 94 à 96 %. '
        'Le risque principal est une construction excessive dans certaines '
        'régions, qui peut peser localement sur les loyers.',
    icon: Icons.home_work_rounded,
    holdings: [
      _ReitHolding(name: 'AvalonBay', ticker: 'AVB'),
      _ReitHolding(name: 'Equity Residential', ticker: 'EQR'),
      _ReitHolding(name: 'Mid-America Apartment', ticker: 'MAA'),
      _ReitHolding(name: 'Vonovia', ticker: 'VNA'),
    ],
  ),
  _ReitPack(
    id: 'sante',
    name: 'Santé',
    summary: 'Résidences seniors, cliniques et infrastructures médicales',
    description:
        'Ce pack investit dans l’immobilier de santé : maisons de retraite '
        'médicalisées, résidences seniors, cliniques, hôpitaux privés et '
        'laboratoires. Le vieillissement démographique soutient la demande '
        'pour ces infrastructures. Les baux sont souvent longs et les '
        'locataires sont des opérateurs de santé. Le principal risque '
        'concerne leur solidité financière : une difficulté d’exploitation '
        'peut affecter le paiement des loyers. Les REITs à haut rendement '
        'peuvent présenter un risque de crédit plus marqué.',
    icon: Icons.health_and_safety_rounded,
    holdings: [
      _ReitHolding(name: 'Welltower', ticker: 'WELL'),
      _ReitHolding(name: 'Ventas', ticker: 'VTR'),
      _ReitHolding(name: 'Omega Healthcare', ticker: 'OHI'),
    ],
  ),
  _ReitPack(
    id: 'self-storage',
    name: 'Self-storage',
    summary: 'Boxes de stockage pour particuliers et entreprises',
    description:
        'Ce pack regroupe des REITs spécialisés dans les espaces de '
        'stockage en libre-service. Les coûts d’exploitation sont '
        'relativement faibles et les clients louent ces espaces lors de '
        'déménagements, successions ou besoins de stockage professionnels. '
        'La demande peut être résiliente, mais la surconstruction dans '
        'certaines zones métropolitaines peut réduire temporairement les '
        'taux d’occupation et les loyers.',
    icon: Icons.inventory_2_rounded,
    holdings: [
      _ReitHolding(name: 'Public Storage', ticker: 'PSA'),
      _ReitHolding(name: 'Extra Space Storage', ticker: 'EXR'),
      _ReitHolding(name: 'CubeSmart', ticker: 'CUBE'),
    ],
  ),
  _ReitPack(
    id: 'mondial',
    name: 'ETF clé en main mondial',
    summary: 'Exposition diversifiée aux REITs de plusieurs régions',
    description:
        'Ce pack s’appuie sur des fonds indiciels cotés qui répliquent le '
        'marché immobilier coté mondial. Une seule allocation donne accès à '
        'des centaines de REITs dans plusieurs pays et secteurs : '
        'résidentiel, commercial, logistique, santé ou centres de données. '
        'La diversification réduit le risque lié à un seul titre ou pays. '
        'Les frais de gestion indiqués pour ces ETF sont généralement '
        'inférieurs à 0,30 % par an. Le risque principal reste celui du '
        'marché immobilier coté et sa sensibilité aux taux d’intérêt.',
    icon: Icons.public_rounded,
    holdings: [
      _ReitHolding(
        name: 'Vanguard Real Estate ETF',
        ticker: 'VNQ',
        allocation: '40 %',
      ),
      _ReitHolding(
        name: 'IWDP / ETF EPRA Europe',
        ticker: 'IWDP',
        allocation: '30 %',
      ),
      _ReitHolding(
        name: 'ETF REIT Asie-Pacifique',
        ticker: 'Asie-Pacifique',
        allocation: '20 %',
      ),
      _ReitHolding(
        name: 'Schwab U.S. REIT ETF',
        ticker: 'SCHH',
        allocation: '10 %',
      ),
    ],
  ),
];

const _fpiPacks = [
  _ReitPack(
    id: 'commerce',
    name: 'Commerce de proximité',
    summary: 'Commerces essentiels et centres de proximité en Europe',
    description:
        'Ce pack rassemble des FPI spécialisées dans les supermarchés, '
        'pharmacies, commerces alimentaires et retail parks de proximité. '
        'Les locataires vendent des produits essentiels et les baux sont '
        'généralement longs, avec indexation des loyers. Les revenus locatifs '
        'peuvent être réguliers, mais la hausse des taux et la concurrence '
        'du commerce en ligne sur certains formats restent des risques.',
    icon: Icons.storefront_rounded,
    holdings: [
      _ReitHolding(name: 'Carmila', ticker: 'France · retail parks'),
      _ReitHolding(name: 'Mercialys', ticker: 'France · commerces'),
      _ReitHolding(name: 'Klépierre', ticker: 'France · centres commerciaux'),
    ],
  ),
  _ReitPack(
    id: 'residentiel',
    name: 'Résidentiel',
    summary: 'Logements locatifs en France et en Allemagne',
    description:
        'Ce pack rassemble des sociétés et fonds immobiliers investis dans '
        'le logement locatif, principalement en France et en Allemagne. Le '
        'logement est un besoin fondamental et la demande dans les grandes '
        'métropoles est soutenue par la pénurie de logements. L’encadrement '
        'des loyers, les évolutions fiscales et la qualité du parc immobilier '
        'constituent les principaux risques.',
    icon: Icons.home_work_rounded,
    holdings: [
      _ReitHolding(name: 'Vonovia', ticker: 'VNA · Allemagne'),
      _ReitHolding(name: 'Deutsche Wohnen', ticker: 'DWNI · Allemagne'),
      _ReitHolding(
        name: 'SCPI résidentielle française',
        ticker: 'France · non cotée',
      ),
    ],
  ),
  _ReitPack(
    id: 'sante',
    name: 'Santé',
    summary: 'Cliniques, résidences seniors et établissements de santé',
    description:
        'Ce pack investit dans des cliniques, maisons de retraite '
        'médicalisées, résidences seniors et laboratoires. Le vieillissement '
        'démographique en Europe soutient les besoins en infrastructures de '
        'santé. Les baux peuvent être longs et rendre les revenus plus '
        'prévisibles, mais la santé financière des opérateurs locataires '
        'reste un risque important.',
    icon: Icons.health_and_safety_rounded,
    holdings: [
      _ReitHolding(name: 'Pierval Santé', ticker: 'SCPI santé · France'),
      _ReitHolding(name: 'Aedifica', ticker: 'AED · Belgique'),
      _ReitHolding(name: 'Cofinimmo', ticker: 'COFB · Belgique'),
    ],
  ),
  _ReitPack(
    id: 'bureaux',
    name: 'Bureaux',
    summary: 'Immeubles de bureaux en France et en Europe',
    description:
        'Ce pack regroupe des FPI investies dans des immeubles de bureaux. '
        'Les baux commerciaux peuvent apporter une visibilité sur les loyers, '
        'et la qualité, l’emplacement et les normes environnementales des '
        'immeubles sont déterminants. Le télétravail et l’obsolescence de '
        'certains bâtiments peuvent entraîner une vacance durable et une '
        'volatilité plus forte.',
    icon: Icons.business_rounded,
    holdings: [
      _ReitHolding(name: 'Covivio', ticker: 'COV · France'),
      _ReitHolding(name: 'Gecina', ticker: 'GFC · France'),
      _ReitHolding(name: 'Icade', ticker: 'ICAD · France'),
      _ReitHolding(
        name: 'SCPI bureaux française',
        ticker: 'France · non cotée',
      ),
    ],
  ),
  _ReitPack(
    id: 'europeen',
    name: 'Diversifié européen',
    summary: 'ETF immobilier européen diversifié par pays et secteur',
    description:
        'Ce pack s’appuie sur des ETF qui couvrent le marché immobilier coté '
        'européen. Ils répartissent l’exposition entre plusieurs pays et '
        'secteurs, notamment le résidentiel, les bureaux, le commerce, la '
        'santé et la logistique. La diversification réduit la dépendance à '
        'une seule société, mais les taux d’intérêt et la conjoncture '
        'immobilière européenne restent des facteurs de risque.',
    icon: Icons.public_rounded,
    holdings: [
      _ReitHolding(
        name: 'iShares Developed Markets Property Yield',
        ticker: 'IWDP',
        allocation: '40 %',
      ),
      _ReitHolding(
        name: 'ETF EPRA Europe',
        ticker: 'Amundi / Lyxor',
        allocation: '30 %',
      ),
      _ReitHolding(
        name: 'ETF immobilier eurozone',
        ticker: 'BNP Paribas',
        allocation: '20 %',
      ),
      _ReitHolding(
        name: 'ETF REIT Royaume-Uni',
        ticker: 'iShares UK Property',
        allocation: '10 %',
      ),
    ],
  ),
];

const _commodityPacks = [
  _ReitPack(
    id: 'metaux-precieux',
    name: 'Métaux précieux',
    summary: 'Métaux de réserve de valeur et couverture de portefeuille',
    description:
        'Ce pack regroupe les quatre métaux précieux majeurs, traditionnellement '
        'utilisés comme réserve de valeur et couverture contre l’inflation et '
        'les crises. Il est conçu pour diversifier et protéger un portefeuille '
        'plutôt que pour générer un revenu. Les matières premières peuvent '
        'néanmoins connaître des variations de prix importantes.',
    icon: Icons.diamond_rounded,
    holdings: [
      _ReitHolding(name: 'Or', ticker: 'Métal précieux'),
      _ReitHolding(name: 'Argent', ticker: 'Métal précieux · argent'),
      _ReitHolding(name: 'Platine', ticker: 'Métal précieux · platine'),
      _ReitHolding(name: 'Palladium', ticker: 'Métal précieux · palladium'),
    ],
  ),
  _ReitPack(
    id: 'energie',
    name: 'Énergie',
    summary: 'Pétrole brut et gaz naturel',
    description:
        'Ce pack couvre deux grandes références du pétrole brut et le gaz '
        'naturel, au cœur de l’économie mondiale. Leurs prix dépendent de '
        'l’offre, de la demande, des stocks et de la géopolitique. Ces marchés '
        'sont cycliques et peuvent être très volatils, ce qui rend leur '
        'détention complexe.',
    icon: Icons.bolt_rounded,
    holdings: [
      _ReitHolding(name: 'Pétrole brut WTI', ticker: 'WTI'),
      _ReitHolding(name: 'Pétrole Brent', ticker: 'Brent'),
      _ReitHolding(name: 'Gaz naturel', ticker: 'Gaz'),
    ],
  ),
  _ReitPack(
    id: 'agricoles',
    name: 'Agricoles',
    summary: 'Produits agricoles essentiels à l’alimentation mondiale',
    description:
        'Ce pack regroupe les principales matières premières agricoles. '
        'Leurs prix dépendent notamment de la météo, des récoltes, des stocks '
        'et des crises géopolitiques. Cette exposition peut diversifier un '
        'portefeuille, mais les rendements et les prix ne sont pas garantis.',
    icon: Icons.grass_rounded,
    holdings: [
      _ReitHolding(name: 'Blé', ticker: 'Agricole · blé'),
      _ReitHolding(name: 'Maïs', ticker: 'Agricole · maïs'),
      _ReitHolding(name: 'Soja', ticker: 'Agricole · soja'),
      _ReitHolding(name: 'Café', ticker: 'Agricole · café'),
      _ReitHolding(name: 'Sucre', ticker: 'Agricole · sucre'),
      _ReitHolding(name: 'Cacao', ticker: 'Agricole · cacao'),
      _ReitHolding(name: 'Coton', ticker: 'Agricole · coton'),
      _ReitHolding(name: 'Riz', ticker: 'Agricole · riz'),
    ],
  ),
  _ReitPack(
    id: 'industriels',
    name: 'Industriels',
    summary: 'Métaux liés à l’industrie et à la transition énergétique',
    description:
        'Ce pack couvre les métaux industriels, avec le cuivre comme '
        'référence majeure. Leurs prix sont liés à la croissance mondiale, '
        'à l’activité industrielle et à la transition énergétique, notamment '
        'à l’électrification. Cette exposition est sensible aux cycles '
        'économiques, tout en reposant sur des besoins de long terme.',
    icon: Icons.factory_rounded,
    holdings: [
      _ReitHolding(name: 'Cuivre', ticker: 'Industriel · cuivre'),
      _ReitHolding(name: 'Aluminium', ticker: 'Industriel · aluminium'),
      _ReitHolding(name: 'Nickel', ticker: 'Industriel · nickel'),
      _ReitHolding(name: 'Zinc', ticker: 'Industriel · zinc'),
    ],
  ),
  _ReitPack(
    id: 'multi-matieres',
    name: 'Diversifié multi-matières',
    summary: 'Panier réunissant quatre familles de matières premières',
    description:
        'Ce pack réunit des métaux précieux, de l’énergie, des métaux '
        'industriels et des produits agricoles. La diversification évite de '
        'concentrer l’exposition sur un seul marché et peut réduire le risque '
        'par rapport à un pack plus spécialisé. Les marchés des matières '
        'premières restent toutefois volatils.',
    icon: Icons.public_rounded,
    holdings: [
      _ReitHolding(name: 'Or', ticker: 'Or · métal précieux'),
      _ReitHolding(name: 'Argent', ticker: 'Argent · métal précieux'),
      _ReitHolding(name: 'Platine', ticker: 'Platine · métal précieux'),
      _ReitHolding(name: 'Palladium', ticker: 'Palladium · métal précieux'),
      _ReitHolding(name: 'Pétrole brut WTI', ticker: 'Énergie · WTI'),
      _ReitHolding(name: 'Pétrole Brent', ticker: 'Énergie · Brent'),
      _ReitHolding(name: 'Gaz naturel', ticker: 'Énergie'),
      _ReitHolding(name: 'Cuivre', ticker: 'Métal industriel · cuivre'),
      _ReitHolding(name: 'Aluminium', ticker: 'Métal industriel · aluminium'),
      _ReitHolding(name: 'Nickel', ticker: 'Métal industriel · nickel'),
      _ReitHolding(name: 'Zinc', ticker: 'Métal industriel · zinc'),
      _ReitHolding(name: 'Blé', ticker: 'Agricole · blé'),
      _ReitHolding(name: 'Maïs', ticker: 'Agricole · maïs'),
      _ReitHolding(name: 'Soja', ticker: 'Agricole · soja'),
      _ReitHolding(name: 'Café', ticker: 'Agricole · café'),
      _ReitHolding(name: 'Sucre', ticker: 'Agricole · sucre'),
      _ReitHolding(name: 'Cacao', ticker: 'Agricole · cacao'),
      _ReitHolding(name: 'Coton', ticker: 'Agricole · coton'),
      _ReitHolding(name: 'Riz', ticker: 'Agricole · riz'),
    ],
  ),
];

const _cryptoPacks = [
  _ReitPack(
    id: 'majors',
    name: 'Majors',
    summary: 'Bitcoin, Ethereum et actifs crypto majeurs',
    description:
        'Ce pack associe une exposition spot aux principales '
        'cryptomonnaies à une stratégie de trading sur contrats futures. '
        'L’investissement spot vise une exposition de long terme, tandis '
        'que la stratégie de trading cherche à tirer parti des variations '
        'de marché. Le trading futures comporte un risque élevé de perte, '
        'notamment en raison de l’effet de levier, et les résultats ne sont '
        'pas garantis.',
    icon: Icons.currency_bitcoin_rounded,
    holdings: [
      _ReitHolding(name: 'Bitcoin', ticker: 'BTC'),
      _ReitHolding(name: 'Ethereum', ticker: 'ETH'),
      _ReitHolding(name: 'Solana', ticker: 'SOL'),
      _ReitHolding(name: 'OKX', ticker: 'OKB'),
      _ReitHolding(name: 'BNB', ticker: 'BNB'),
      _ReitHolding(name: 'Autres cryptomonnaies', ticker: '…'),
    ],
  ),
  _ReitPack(
    id: 'layer-1',
    name: 'Layer 1 alternatifs',
    summary: 'Blockchains de première couche alternatives',
    description:
        'Ce pack combine une exposition spot à des blockchains de première '
        'couche alternatives à Ethereum et une stratégie de trading futures. '
        'L’exposition spot vise à accompagner le développement de ces '
        'écosystèmes, tandis que le trading cherche à tirer parti de leur '
        'volatilité. Les actifs crypto et les contrats futures présentent '
        'un risque élevé de perte ; les résultats ne sont pas garantis.',
    icon: Icons.hub_rounded,
    holdings: [
      _ReitHolding(name: 'Solana', ticker: 'SOL'),
      _ReitHolding(name: 'BNB', ticker: 'BNB'),
      _ReitHolding(name: 'Cardano', ticker: 'ADA'),
      _ReitHolding(name: 'Avalanche', ticker: 'AVAX'),
      _ReitHolding(name: 'Polkadot', ticker: 'DOT'),
      _ReitHolding(name: 'Autres blockchains', ticker: '…'),
    ],
  ),
  _ReitPack(
    id: 'defi-infrastructure',
    name: 'DeFi et infrastructure',
    summary: 'Protocoles décentralisés et infrastructure blockchain',
    description:
        'Ce pack associe une exposition spot à des protocoles de finance '
        'décentralisée et d’infrastructure blockchain à une stratégie de '
        'trading futures. Le spot vise l’adoption de ces protocoles, tandis '
        'que le trading cherche à exploiter les fluctuations de marché. '
        'Les cryptoactifs et les contrats futures sont très volatils et '
        'peuvent entraîner une perte importante du capital investi.',
    icon: Icons.account_tree_rounded,
    holdings: [
      _ReitHolding(name: 'Uniswap', ticker: 'UNI'),
      _ReitHolding(name: 'Aave', ticker: 'AAVE'),
      _ReitHolding(name: 'Chainlink', ticker: 'LINK'),
      _ReitHolding(name: 'Maker', ticker: 'MKR'),
      _ReitHolding(name: 'Lido', ticker: 'LDO'),
      _ReitHolding(name: 'Autres protocoles', ticker: '…'),
    ],
  ),
  _ReitPack(
    id: 'memecoins',
    name: 'Memecoins et haute volatilité',
    summary: 'Actifs spéculatifs à forte volatilité',
    description:
        'Ce pack rassemble des memecoins spéculatifs et une stratégie de '
        'trading futures sur ces actifs. Les cours peuvent varier fortement '
        'et rapidement ; ce pack est réservé aux investisseurs avertis et '
        'peut entraîner une perte totale du capital investi. Les résultats '
        'du trading ne sont pas garantis.',
    icon: Icons.whatshot_rounded,
    holdings: [
      _ReitHolding(name: 'Dogecoin', ticker: 'DOGE'),
      _ReitHolding(name: 'Shiba Inu', ticker: 'SHIB'),
      _ReitHolding(name: 'Pepe', ticker: 'PEPE'),
      _ReitHolding(name: 'Bonk', ticker: 'BONK'),
      _ReitHolding(name: 'Dogwifhat', ticker: 'WIF'),
      _ReitHolding(name: 'Autres memecoins', ticker: '…'),
    ],
  ),
  _ReitPack(
    id: 'diversifie',
    name: 'Diversifié crypto',
    summary: 'Panier crypto multi-secteurs avec actifs de différentes tailles',
    description:
        'Ce pack réunit des cryptomonnaies majeures, des blockchains '
        'alternatives, des protocoles DeFi et des memecoins. Il combine une '
        'exposition spot au panier et une stratégie de trading futures. '
        'La diversification ne supprime pas les risques : les cryptoactifs '
        'restent très volatils et le trading futures peut entraîner une '
        'perte importante, voire totale, du capital. Aucun rendement n’est '
        'garanti.',
    icon: Icons.public_rounded,
    holdings: [
      _ReitHolding(name: 'Bitcoin', ticker: 'BTC'),
      _ReitHolding(name: 'Ethereum', ticker: 'ETH'),
      _ReitHolding(name: 'Solana', ticker: 'SOL'),
      _ReitHolding(name: 'BNB', ticker: 'BNB'),
      _ReitHolding(name: 'Cardano', ticker: 'ADA'),
      _ReitHolding(name: 'Avalanche', ticker: 'AVAX'),
      _ReitHolding(name: 'Polkadot', ticker: 'DOT'),
      _ReitHolding(name: 'Uniswap', ticker: 'UNI'),
      _ReitHolding(name: 'Aave', ticker: 'AAVE'),
      _ReitHolding(name: 'Chainlink', ticker: 'LINK'),
      _ReitHolding(name: 'Maker', ticker: 'MKR'),
      _ReitHolding(name: 'Lido', ticker: 'LDO'),
      _ReitHolding(name: 'Dogecoin', ticker: 'DOGE'),
      _ReitHolding(name: 'Shiba Inu', ticker: 'SHIB'),
      _ReitHolding(name: 'Pepe', ticker: 'PEPE'),
      _ReitHolding(name: 'Bonk', ticker: 'BONK'),
      _ReitHolding(name: 'Dogwifhat', ticker: 'WIF'),
      _ReitHolding(name: 'Autres cryptomonnaies', ticker: '…'),
    ],
  ),
];

const _stockPacks = [
  _ReitPack(
    id: 'mega-tech',
    name: 'Méga-capitalisations technologiques',
    summary: 'Technologie, services numériques et intelligence artificielle',
    description:
        'Ce pack associe une exposition spot à de grandes entreprises '
        'technologiques et une stratégie de trading sur futures actions et '
        'indices. Le spot vise une exposition de long terme à la croissance '
        'numérique, tandis que le trading cherche à tirer parti des '
        'variations de marché. Les contrats futures, notamment lorsqu’ils '
        'utilisent un effet de levier, comportent un risque élevé de perte. '
        'Aucun rendement n’est garanti.',
    icon: Icons.memory_rounded,
    holdings: [
      _ReitHolding(name: 'Apple', ticker: 'AAPL'),
      _ReitHolding(name: 'Microsoft', ticker: 'MSFT'),
      _ReitHolding(name: 'Nvidia', ticker: 'NVDA'),
      _ReitHolding(name: 'Alphabet', ticker: 'GOOGL'),
      _ReitHolding(name: 'Amazon', ticker: 'AMZN'),
      _ReitHolding(name: 'Meta', ticker: 'META'),
      _ReitHolding(name: 'Tesla', ticker: 'TSLA'),
    ],
  ),
  _ReitPack(
    id: 'sante-defensif',
    name: 'Santé et défensif',
    summary: 'Santé et consommation de produits essentiels',
    description:
        'Ce pack associe une exposition spot à des entreprises de la santé '
        'et de la consommation défensive à une stratégie de trading sur '
        'futures actions. Le portefeuille spot vise des activités à demande '
        'structurelle, tandis que le trading cherche à exploiter les '
        'variations de cours. Les actions comme les contrats futures '
        'présentent un risque de perte en capital ; les résultats du trading '
        'ne sont pas garantis.',
    icon: Icons.health_and_safety_rounded,
    holdings: [
      _ReitHolding(name: 'Johnson & Johnson', ticker: 'JNJ'),
      _ReitHolding(name: 'UnitedHealth', ticker: 'UNH'),
      _ReitHolding(name: 'Pfizer', ticker: 'PFE'),
      _ReitHolding(name: 'Merck', ticker: 'MRK'),
      _ReitHolding(name: 'Procter & Gamble', ticker: 'PG'),
      _ReitHolding(name: 'Coca-Cola', ticker: 'KO'),
      _ReitHolding(name: 'PepsiCo', ticker: 'PEP'),
    ],
  ),
  _ReitPack(
    id: 'finance-energie',
    name: 'Finance et énergie',
    summary: 'Banques, services financiers et grandes entreprises énergétiques',
    description:
        'Ce pack combine une exposition spot aux secteurs financier et '
        'énergétique et une stratégie de trading sur futures actions et '
        'indices sectoriels. Ces secteurs sont sensibles aux cycles '
        'économiques, aux marchés et aux prix de l’énergie. Le trading '
        'futures peut amplifier les pertes ; le capital investi et tout '
        'rendement ne sont pas garantis.',
    icon: Icons.account_balance_rounded,
    holdings: [
      _ReitHolding(name: 'JPMorgan Chase', ticker: 'JPM'),
      _ReitHolding(name: 'Bank of America', ticker: 'BAC'),
      _ReitHolding(name: 'Goldman Sachs', ticker: 'GS'),
      _ReitHolding(name: 'Visa', ticker: 'V'),
      _ReitHolding(name: 'Mastercard', ticker: 'MA'),
      _ReitHolding(name: 'ExxonMobil', ticker: 'XOM'),
      _ReitHolding(name: 'Chevron', ticker: 'CVX'),
    ],
  ),
  _ReitPack(
    id: 'industrie-cyclique',
    name: 'Industrie et consommation cyclique',
    summary: 'Industrie, infrastructures et consommation discrétionnaire',
    description:
        'Ce pack associe des actions industrielles et de consommation '
        'cyclique à une stratégie de trading sur futures. Les activités '
        'représentées sont exposées à la conjoncture, aux investissements '
        'et aux habitudes de consommation. Le trading futures peut '
        'amplifier les mouvements de marché et entraîner des pertes '
        'importantes ; aucun résultat n’est garanti.',
    icon: Icons.factory_rounded,
    holdings: [
      _ReitHolding(name: 'Caterpillar', ticker: 'CAT'),
      _ReitHolding(name: 'Deere', ticker: 'DE'),
      _ReitHolding(name: 'Honeywell', ticker: 'HON'),
      _ReitHolding(name: 'Boeing', ticker: 'BA'),
      _ReitHolding(name: 'Home Depot', ticker: 'HD'),
      _ReitHolding(name: 'Nike', ticker: 'NKE'),
      _ReitHolding(name: 'Starbucks', ticker: 'SBUX'),
    ],
  ),
  _ReitPack(
    id: 'diversifie-mondial',
    name: 'Diversifié actions mondial',
    summary: 'Panier d’actions diversifié par secteur',
    description:
        'Ce pack regroupe des actions des secteurs technologique, de la '
        'santé, financier, énergétique, industriel et de la consommation. '
        'Il associe une exposition spot au panier à une stratégie de trading '
        'sur futures actions et indices. La diversification peut répartir '
        'l’exposition mais n’élimine pas le risque de marché. Les contrats '
        'futures peuvent entraîner une perte importante, voire totale, du '
        'capital engagé ; aucun rendement n’est garanti.',
    icon: Icons.public_rounded,
    holdings: [
      _ReitHolding(name: 'Apple', ticker: 'AAPL'),
      _ReitHolding(name: 'Microsoft', ticker: 'MSFT'),
      _ReitHolding(name: 'Nvidia', ticker: 'NVDA'),
      _ReitHolding(name: 'Alphabet', ticker: 'GOOGL'),
      _ReitHolding(name: 'Amazon', ticker: 'AMZN'),
      _ReitHolding(name: 'Meta', ticker: 'META'),
      _ReitHolding(name: 'Tesla', ticker: 'TSLA'),
      _ReitHolding(name: 'Johnson & Johnson', ticker: 'JNJ'),
      _ReitHolding(name: 'UnitedHealth', ticker: 'UNH'),
      _ReitHolding(name: 'Pfizer', ticker: 'PFE'),
      _ReitHolding(name: 'Merck', ticker: 'MRK'),
      _ReitHolding(name: 'Procter & Gamble', ticker: 'PG'),
      _ReitHolding(name: 'Coca-Cola', ticker: 'KO'),
      _ReitHolding(name: 'PepsiCo', ticker: 'PEP'),
      _ReitHolding(name: 'JPMorgan Chase', ticker: 'JPM'),
      _ReitHolding(name: 'Bank of America', ticker: 'BAC'),
      _ReitHolding(name: 'Goldman Sachs', ticker: 'GS'),
      _ReitHolding(name: 'Visa', ticker: 'V'),
      _ReitHolding(name: 'Mastercard', ticker: 'MA'),
      _ReitHolding(name: 'ExxonMobil', ticker: 'XOM'),
      _ReitHolding(name: 'Chevron', ticker: 'CVX'),
      _ReitHolding(name: 'Caterpillar', ticker: 'CAT'),
      _ReitHolding(name: 'Deere', ticker: 'DE'),
      _ReitHolding(name: 'Honeywell', ticker: 'HON'),
      _ReitHolding(name: 'Boeing', ticker: 'BA'),
      _ReitHolding(name: 'Home Depot', ticker: 'HD'),
      _ReitHolding(name: 'Nike', ticker: 'NKE'),
      _ReitHolding(name: 'Starbucks', ticker: 'SBUX'),
    ],
  ),
];

class InvestmentPage extends StatefulWidget {
  const InvestmentPage({super.key, this.kycVerified = false});

  /// Set this only after a trusted KYC service confirms the user's identity.
  final bool kycVerified;

  @override
  State<InvestmentPage> createState() => _InvestmentPageState();
}

class _InvestmentPageState extends State<InvestmentPage> {
  InvestmentType? _selectedType = InvestmentType.reit;
  bool _filterIsActive = false;
  int _selectedNavigation = 0;
  int _walletCardIndex = 0;
  int _heroCardIndex = 0;
  bool _notificationsRead = false;
  bool _isEnglish = false;
  bool _languageSelectionMade = false;
  bool _showSupportEmail = false;
  bool _showAuthorizationPage = false;
  bool _showHelpInfoPage = false;
  String? _kycDocumentPhotoPath;
  String _kycVerificationStatus = 'not_submitted';
  RealtimeChannel? _kycStatusChannel;
  _TransactionReceipt? _selectedReceipt;
  int _receiptSequence = 0;
  final GlobalKey _receiptImageBoundaryKey = GlobalKey();
  _WalletFlow? _walletFlow;
  _HoldingPosition? _selectedHoldingDetail;
  String _selectedTransferNetwork = 'Polygon';
  String _selectedHoldingCategory = 'Tous les actifs';
  final TextEditingController _transferAmountController =
      TextEditingController();
  final TextEditingController _transactionHashController =
      TextEditingController();
  final TextEditingController _destinationAddressController =
      TextEditingController();
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _profilePhoneController = TextEditingController();
  final TextEditingController _kycFirstNameController = TextEditingController();
  final TextEditingController _kycLastNameController = TextEditingController();
  final TextEditingController _kycBirthYearController = TextEditingController();
  final TextEditingController _kycBirthPlaceController =
      TextEditingController();
  final TextEditingController _kycCityController = TextEditingController();
  final TextEditingController _kycDepartmentController =
      TextEditingController();
  final TextEditingController _kycCountryController = TextEditingController();
  final TextEditingController _kycIdentityNumberController =
      TextEditingController();
  final GlobalKey<FormFieldState<String>> _kycPhotoFieldKey =
      GlobalKey<FormFieldState<String>>();
  final TextEditingController _investmentAmountController =
      TextEditingController();
  final GlobalKey<FormState> _transferFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _transactionHashFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _kycFormKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _destinationAddressFieldKey =
      GlobalKey<FormFieldState<String>>();
  String _search = '';
  bool _showReitPacksPage = false;
  bool _showFpiPacksPage = false;
  bool _showCommodityPacksPage = false;
  bool _showCryptoPacksPage = false;
  bool _showStockPacksPage = false;
  bool _showInvestmentPage = false;
  _ReitPack? _investmentPack;
  InvestmentType? _investmentType;
  _InvestmentMode _investmentMode = _InvestmentMode.fractional;
  _ReitPack? _selectedReitPack;
  _ReitPack? _selectedFpiPack;
  _ReitPack? _selectedCommodityPack;
  _ReitPack? _selectedCryptoPack;
  _ReitPack? _selectedStockPack;
  final PageController _walletPageController = PageController();
  final PageController _heroPageController = PageController();
  final ImagePicker _imagePicker = ImagePicker();
  String _profileName = '';
  String _profileEmail = '';
  String _profilePhone = '';
  String? _profilePhotoPath;
  String? _profileLoadError;
  Timer? _heroTimer;

  static const _heroSlides = [
    _HeroSlide(
      type: InvestmentType.reit,
      image: 'assets/reit.jpg',
      tag: 'REIT',
      title: 'Revenus immobiliers\npassifs',
      subtitle: 'Investissez dans l’immobilier\nsans gérer de biens.',
      action: 'Découvrir le REIT',
      icon: Icons.apartment_rounded,
    ),
    _HeroSlide(
      type: InvestmentType.fpi,
      image: 'assets/fpi.jpg',
      tag: 'FPI',
      title: 'Investissez dans\nles fonds immobiliers',
      subtitle: 'Accédez à des fonds\nimmobiliers sélectionnés.',
      action: 'Découvrir le FPI',
      icon: Icons.bar_chart_rounded,
    ),
    _HeroSlide(
      type: InvestmentType.commodity,
      image: 'assets/commodities.png',
      tag: 'MATIÈRES PREMIÈRES',
      title: 'Diversifiez vos\ninvestissements',
      subtitle: 'Découvrez l’or et les\nmatières premières.',
      action: 'Découvrir les actifs',
      icon: Icons.diamond_outlined,
    ),
    _HeroSlide(
      type: InvestmentType.crypto,
      image: 'assets/cryptocurrencies.png',
      tag: 'CRYPTO',
      title: 'Explorez les\ncryptomonnaies',
      subtitle: 'Retrouvez Bitcoin et\nd’autres actifs numériques.',
      action: 'Découvrir la crypto',
      icon: Icons.currency_bitcoin_rounded,
    ),
    _HeroSlide(
      type: InvestmentType.action,
      image: 'assets/stocks.png',
      tag: 'ACTIONS',
      title: 'Investissez dans\nles grandes entreprises',
      subtitle: 'Découvrez des actions\nd’entreprises mondiales.',
      action: 'Découvrir les actions',
      icon: Icons.show_chart_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
    _listenForKycStatus();
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_selectedNavigation != 0 ||
          _showInvestmentPage ||
          _showReitPacksPage ||
          _showFpiPacksPage ||
          _showCommodityPacksPage ||
          _showCryptoPacksPage ||
          _showStockPacksPage ||
          _selectedReitPack != null ||
          _selectedFpiPack != null ||
          _selectedCommodityPack != null ||
          _selectedCryptoPack != null ||
          _selectedStockPack != null ||
          _search.isNotEmpty ||
          (_filterIsActive && _selectedType != null) ||
          !_heroPageController.hasClients) {
        return;
      }
      final nextPage = (_heroCardIndex + 1) % _heroSlides.length;
      _heroPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    final kycStatusChannel = _kycStatusChannel;
    if (kycStatusChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(kycStatusChannel));
    }
    _heroPageController.dispose();
    _walletPageController.dispose();
    _transferAmountController.dispose();
    _transactionHashController.dispose();
    _destinationAddressController.dispose();
    _profileNameController.dispose();
    _profilePhoneController.dispose();
    _kycFirstNameController.dispose();
    _kycLastNameController.dispose();
    _kycBirthYearController.dispose();
    _kycBirthPlaceController.dispose();
    _kycCityController.dispose();
    _kycDepartmentController.dispose();
    _kycCountryController.dispose();
    _kycIdentityNumberController.dispose();
    _investmentAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final photoPath = preferences.getString(_profilePhotoKey);
      final photoExists = photoPath != null && await File(photoPath).exists();
      var name = preferences.getString(_profileNameKey) ?? '';
      var email = preferences.getString(_profileEmailKey) ?? '';
      var phone = preferences.getString(_profilePhoneKey) ?? '';
      if (TamleekSupabaseOptions.isConfigured) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('name, phone')
              .eq('id', user.id)
              .maybeSingle();
          name =
              profile?['name'] as String? ??
              user.userMetadata?['name'] as String? ??
              name;
          email = user.email ?? email;
          phone = profile?['phone'] as String? ?? phone;
        }
      }
      if (!mounted) return;
      setState(() {
        _profileName = name;
        _profileEmail = email;
        _profilePhone = phone;
        _profilePhotoPath = photoExists ? photoPath : null;
        if (!_languageSelectionMade) {
          _isEnglish = preferences.getString(_languagePreferenceKey) == 'en';
        }
        _profileLoadError = null;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(
        () => _profileLoadError =
            'Le profil local n’a pas pu être chargé. ${error.message ?? ''}',
      );
    } on FileSystemException {
      if (!mounted) return;
      setState(
        () => _profileLoadError =
            'La photo de profil enregistrée est inaccessible.',
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(
        () => _profileLoadError =
            'Le profil Supabase n’a pas pu être chargé. '
            '${error.message}',
      );
    }
  }

  String _tr(String french, String english) => _isEnglish ? english : french;

  Future<void> _showLanguagePicker() async {
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('language-picker-dialog'),
        title: Text(_tr('Choisir la langue', 'Choose a language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: _isEnglish ? 'en' : 'fr',
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    key: ValueKey('language-option-fr'),
                    value: 'fr',
                    title: Text('Français'),
                  ),
                  RadioListTile<String>(
                    key: ValueKey('language-option-en'),
                    value: 'en',
                    title: Text('English'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('language-picker-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_tr('Annuler', 'Cancel')),
          ),
        ],
      ),
    );
    if (selectedLanguage == null || !mounted) return;

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _languagePreferenceKey,
        selectedLanguage,
      );
      if (!saved) {
        await _showMessage(
          _tr(
            'La langue n’a pas pu être enregistrée.',
            'The language preference could not be saved.',
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _isEnglish = selectedLanguage == 'en';
        _languageSelectionMade = true;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      await _showMessage(
        _tr(
          'La langue n’a pas pu être enregistrée. ${error.message ?? ''}',
          'The language preference could not be saved. '
              '${error.message ?? ''}',
        ),
      );
    }
  }

  bool get _kycRequirementMet =>
      widget.kycVerified || _kycVerificationStatus == 'verified';

  void _listenForKycStatus() {
    if (!TamleekSupabaseOptions.isConfigured) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    unawaited(_loadKycStatus(user.id));
    _kycStatusChannel = client
        .channel('kyc-status-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kyc_submissions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() {
              _kycVerificationStatus =
                  payload.newRecord['status'] as String? ?? 'not_submitted';
            });
          },
        )
        .subscribe();
  }

  Future<void> _loadKycStatus(String uid) async {
    try {
      final submission = await Supabase.instance.client
          .from('kyc_submissions')
          .select('status')
          .eq('user_id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _kycVerificationStatus =
            submission?['status'] as String? ?? 'not_submitted';
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _kycVerificationStatus = 'unavailable');
      await _showMessage(
        'Le statut KYC n’a pas pu être chargé. ${error.message}',
      );
    }
  }

  void _clearKycForm() {
    _kycFirstNameController.clear();
    _kycLastNameController.clear();
    _kycBirthYearController.clear();
    _kycBirthPlaceController.clear();
    _kycCityController.clear();
    _kycDepartmentController.clear();
    _kycCountryController.clear();
    _kycIdentityNumberController.clear();
    _kycDocumentPhotoPath = null;
  }

  Future<void> _pickKycIdentityPhoto(FormFieldState<String> photoField) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (!mounted || photo == null) return;
      setState(() => _kycDocumentPhotoPath = photo.path);
      photoField.didChange(photo.path);
    } on PlatformException catch (error) {
      if (!mounted) return;
      await _showMessage(
        _tr(
          'La photo n’a pas pu être sélectionnée. ${error.message ?? ''}',
          'The photo could not be selected. ${error.message ?? ''}',
        ),
      );
    }
  }

  Future<void> _showKycInformation() async {
    if (_kycRequirementMet || _kycVerificationStatus == 'pending') {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('kyc-information-dialog'),
          title: Text(_tr('Vérification KYC', 'KYC verification')),
          content: Text(
            _tr(
              _kycRequirementMet
                  ? 'Votre identité a été vérifiée par un service de confiance.'
                  : 'Votre dossier a été transmis et attend une vérification.',
              _kycRequirementMet
                  ? 'Your identity has been verified by a trusted service.'
                  : 'Your file was submitted and is awaiting review.',
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('kyc-information-close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tr('Compris', 'Got it')),
            ),
          ],
        ),
      );
      return;
    }
    await _showKycForm();
  }

  Future<bool> _showKycForm() async {
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.sizeOf(sheetContext).height;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            key: const ValueKey('kyc-form-sheet'),
            constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Form(
              key: _kycFormKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8DDE5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _tr('Vérification KYC', 'KYC verification'),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr(
                      'Renseignez tous les champs et ajoutez une photo de votre '
                          'pièce d’identité. ${TamleekSupabaseOptions.isConfigured ? 'Le document sera envoyé dans un stockage privé et le dossier sera transmis pour examen.' : 'Aucun service Supabase n’est configuré : le dossier ne pourra pas être transmis.'} Les champs saisis sont effacés à la fermeture du formulaire. Les opérations soumises au KYC restent bloquées jusqu’à une validation fiable.',
                      'Complete every field and add a photo of your identity '
                          'document. ${TamleekSupabaseOptions.isConfigured ? 'It will be uploaded to private storage and submitted for review.' : 'Supabase is not configured, so the file cannot be submitted.'} Entered fields are cleared when the form closes. KYC-required operations remain blocked until trusted verification.',
                    ),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _kycFormField(
                    key: const ValueKey('kyc-first-name-input'),
                    controller: _kycFirstNameController,
                    label: _tr('Prénom', 'First name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  _kycFormField(
                    key: const ValueKey('kyc-last-name-input'),
                    controller: _kycLastNameController,
                    label: _tr('Nom', 'Last name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  _kycFormField(
                    key: const ValueKey('kyc-birth-year-input'),
                    controller: _kycBirthYearController,
                    label: _tr('Année de naissance', 'Year of birth'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final year = int.tryParse((value ?? '').trim());
                      if (year == null ||
                          year < 1900 ||
                          year > DateTime.now().year) {
                        return _tr(
                          'Saisissez une année valide.',
                          'Enter a valid year.',
                        );
                      }
                      return null;
                    },
                  ),
                  _kycFormField(
                    key: const ValueKey('kyc-birth-place-input'),
                    controller: _kycBirthPlaceController,
                    label: _tr('Lieu de naissance', 'Place of birth'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  _kycFormField(
                    key: const ValueKey('kyc-city-input'),
                    controller: _kycCityController,
                    label: _tr('Ville', 'City'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  _kycFormField(
                    key: const ValueKey('kyc-department-input'),
                    controller: _kycDepartmentController,
                    label: _tr('Département', 'Department'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  _kycFormField(
                    key: const ValueKey('kyc-country-input'),
                    controller: _kycCountryController,
                    label: _tr('Pays', 'Country'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  _kycFormField(
                    key: const ValueKey('kyc-identity-number-input'),
                    controller: _kycIdentityNumberController,
                    label: _tr(
                      'Numéro de la pièce d’identité',
                      'Identity document number',
                    ),
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  FormField<String>(
                    key: _kycPhotoFieldKey,
                    validator: (value) => (value == null || value.isEmpty)
                        ? _tr(
                            'Ajoutez une photo de votre pièce d’identité.',
                            'Add a photo of your identity document.',
                          )
                        : null,
                    builder: (photoField) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('kyc-photo-picker'),
                          onPressed: () => _pickKycIdentityPhoto(photoField),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            _tr(
                              'Ajouter une photo de la pièce',
                              'Add identity document photo',
                            ),
                          ),
                        ),
                        if (_kycDocumentPhotoPath != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_kycDocumentPhotoPath!),
                              key: const ValueKey('kyc-photo-preview'),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        if (photoField.errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 12),
                            child: Text(
                              photoField.errorText!,
                              style: TextStyle(
                                color: Theme.of(sheetContext).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const ValueKey('kyc-submit-button'),
                    onPressed: () {
                      if (!(_kycFormKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      Navigator.of(sheetContext).pop(true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF18A765),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _tr('Soumettre le dossier', 'Submit KYC file'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('kyc-cancel-button'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop(false);
                    },
                    child: Text(_tr('Annuler', 'Cancel')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return false;
    if (completed != true) {
      _clearKycForm();
      return false;
    }

    final information = <String, Object>{
      'firstName': _kycFirstNameController.text.trim(),
      'lastName': _kycLastNameController.text.trim(),
      'birthYear': int.parse(_kycBirthYearController.text.trim()),
      'birthPlace': _kycBirthPlaceController.text.trim(),
      'city': _kycCityController.text.trim(),
      'department': _kycDepartmentController.text.trim(),
      'country': _kycCountryController.text.trim(),
      'identityNumber': _kycIdentityNumberController.text.trim(),
    };
    final photoPath = _kycDocumentPhotoPath;
    var submitted = false;
    if (TamleekSupabaseOptions.isConfigured) {
      if (photoPath == null) {
        await _showMessage('Ajoutez une photo de votre pièce d’identité.');
      } else {
        submitted = await _submitKycToSupabase(information, photoPath);
      }
    } else {
      await _showAppFeedback(
        title: _tr('Dossier non transmis', 'KYC file not submitted'),
        message: _tr(
          'Aucun service Supabase n’est configuré. Aucune donnée ni photo n’a '
              'été enregistrée ou envoyée; votre identité n’est pas vérifiée.',
          'Supabase is not configured. No data or photo was saved or sent; '
              'your identity is not verified.',
        ),
        isSuccess: false,
      );
    }
    if (mounted) _clearKycForm();
    return submitted;
  }

  Future<bool> _submitKycToSupabase(
    Map<String, Object> information,
    String photoPath,
  ) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      await _showMessage(
        'Connectez-vous avant de soumettre votre dossier KYC.',
      );
      return false;
    }
    final file = File(photoPath);
    late final int length;
    try {
      if (!await file.exists()) {
        await _showMessage(
          'La photo sélectionnée est introuvable. Choisissez-la à nouveau.',
        );
        return false;
      }
      length = await file.length();
    } on FileSystemException catch (error) {
      await _showMessage(
        'La photo sélectionnée ne peut pas être lue. ${error.message}',
      );
      return false;
    }
    if (length == 0 || length > 5 * 1024 * 1024) {
      await _showMessage('La photo doit peser moins de 5 Mo.');
      return false;
    }
    final extension = photoPath.toLowerCase().split('.').last;
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final submissionId =
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${math.Random.secure().nextInt(1 << 32)}';
    final documentPath = '${user.id}/$submissionId';
    try {
      await client.storage
          .from('kyc-documents')
          .upload(
            documentPath,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      await client.functions.invoke(
        'submit-kyc',
        body: {...information, 'documentPath': documentPath},
      );
      if (mounted) {
        setState(() => _kycVerificationStatus = 'pending');
      }
      if (!mounted) return true;
      await _showAppFeedback(
        title: 'Dossier transmis',
        message:
            'Votre dossier KYC a été transmis de manière sécurisée. Il reste '
            'en attente de vérification; les opérations soumises au KYC sont '
            'bloquées jusqu’à son approbation.',
      );
      return true;
    } on FunctionException catch (error) {
      if (!mounted) return false;
      await _showMessage(
        'Le dossier KYC n’a pas pu être transmis. '
        '${error.details ?? error.status}',
      );
    } on StorageException catch (error) {
      if (!mounted) return false;
      await _showMessage(
        'Le service KYC a refusé le document. ${error.message}',
      );
    }
    return false;
  }

  Widget _kycFormField({
    required Key key,
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool autocorrect = true,
    bool enableSuggestions = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: key,
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        validator:
            validator ??
            (value) => (value == null || value.trim().isEmpty)
                ? _tr('Ce champ est obligatoire.', 'This field is required.')
                : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E4EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E4EA)),
          ),
        ),
      ),
    );
  }

  Future<void> _showMessage(String message) => _showAppFeedback(
    title: 'Information',
    message: message,
    isSuccess: false,
  );

  void _openReceipt({
    required String operation,
    required double amount,
    required List<(String, String)> details,
    required String status,
    required String notice,
    String backgroundAsset = 'assets/reit.jpg',
    String? dateLabel,
    String totalLabel = 'Montant total',
  }) {
    final now = DateTime.now();
    final dateCode =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final reference =
        'TRX-$dateCode-${(++_receiptSequence).toString().padLeft(4, '0')}';
    setState(() {
      _selectedReceipt = _TransactionReceipt(
        reference: reference,
        date: now,
        operation: operation,
        amount: amount,
        details: details,
        status: status,
        notice: notice,
        backgroundAsset: backgroundAsset,
        dateLabel: dateLabel,
        totalLabel: totalLabel,
      );
    });
  }

  void _openDemoReceipt({
    required String operation,
    required double amount,
    required List<(String, String)> details,
    required String dateLabel,
    String backgroundAsset = 'assets/reit.jpg',
    String totalLabel = 'Montant total',
  }) {
    _openReceipt(
      operation: operation,
      amount: amount,
      details: details,
      backgroundAsset: backgroundAsset,
      status: 'Exemple non vérifié',
      notice:
          'Cette ligne est un exemple visuel de l’historique. Elle ne '
          'correspond pas à une transaction réelle ou vérifiée.',
      dateLabel: dateLabel,
      totalLabel: totalLabel,
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('profile-logout-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final preferences = await SharedPreferences.getInstance();
      final loggedOut = await preferences.setBool(
        _registrationCompleteKey,
        false,
      );
      if (!loggedOut) {
        await _showMessage('La déconnexion n’a pas pu être enregistrée.');
        return;
      }
      if (TamleekSupabaseOptions.isConfigured) {
        await Supabase.instance.client.auth.signOut();
      }
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const _RegistrationPage()),
        (_) => false,
      );
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage('La déconnexion a échoué. ${error.message ?? ''}');
      }
    } on AuthException catch (error) {
      if (mounted) {
        await _showMessage(
          'La déconnexion Supabase a échoué. ${error.message}',
        );
      }
    }
  }

  Future<void> _showSuccessConfirmation({
    required String title,
    required String message,
  }) => _showAppFeedback(title: title, message: message);

  Future<void> _showReceiptConfirmation(String operation) =>
      _showSuccessConfirmation(
        title: 'Demande préparée',
        message:
            'Votre demande (« $operation ») est prête. Elle n’a pas encore '
            'été exécutée. Consultez le reçu pour en voir les détails.',
      );

  void _playNotificationSound() {
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  Future<void> _showAppFeedback({
    required String title,
    required String message,
    bool isSuccess = true,
  }) {
    _playNotificationSound();
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        key: ValueKey(
          isSuccess ? 'success-confirmation-dialog' : 'app-information-dialog',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF17233A).withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/tamleek_logo.jpg',
                            key: ValueKey(
                              isSuccess
                                  ? 'success-confirmation-logo'
                                  : 'app-feedback-logo',
                            ),
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: -5,
                          bottom: -5,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isSuccess
                                  ? const Color(0xFF18A765)
                                  : const Color(0xFF3769C8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                            child: Icon(
                              isSuccess
                                  ? Icons.check_rounded
                                  : Icons.info_outline_rounded,
                              key: ValueKey(
                                isSuccess
                                    ? 'success-confirmation-icon'
                                    : 'app-feedback-icon',
                              ),
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF3F4857),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: ValueKey(
                        isSuccess
                            ? 'success-confirmation-continue'
                            : 'app-feedback-continue',
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        foregroundColor: _ink,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Terminé',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _matches(String text) =>
      _search.isEmpty || text.toLowerCase().contains(_search.toLowerCase());

  @override
  Widget build(BuildContext context) => _buildAppScaffold();

  Widget _buildAppScaffold() {
    final visibleReitPacks = _reitPacks
        .where(
          (pack) =>
              _matches(pack.name) ||
              _matches(pack.summary) ||
              _matches(pack.description) ||
              pack.holdings.any(
                (holding) => _matches(holding.name) || _matches(holding.ticker),
              ),
        )
        .toList();
    final visibleFpiPacks = _fpiPacks
        .where(
          (pack) =>
              _matches(pack.name) ||
              _matches(pack.summary) ||
              _matches(pack.description) ||
              pack.holdings.any(
                (holding) => _matches(holding.name) || _matches(holding.ticker),
              ),
        )
        .toList();
    final visibleCommodityPacks = _commodityPacks
        .where(
          (pack) =>
              _matches(pack.name) ||
              _matches(pack.summary) ||
              _matches(pack.description) ||
              pack.holdings.any(
                (holding) => _matches(holding.name) || _matches(holding.ticker),
              ),
        )
        .toList();
    final visibleCryptoPacks = _cryptoPacks
        .where(
          (pack) =>
              _matches(pack.name) ||
              _matches(pack.summary) ||
              _matches(pack.description) ||
              pack.holdings.any(
                (holding) => _matches(holding.name) || _matches(holding.ticker),
              ),
        )
        .toList();
    final visibleStockPacks = _stockPacks
        .where(
          (pack) =>
              _matches(pack.name) ||
              _matches(pack.summary) ||
              _matches(pack.description) ||
              pack.holdings.any(
                (holding) => _matches(holding.name) || _matches(holding.ticker),
              ),
        )
        .toList();
    final showReit =
        (!_filterIsActive ||
            _selectedType == null ||
            _selectedType == InvestmentType.reit) &&
        visibleReitPacks.isNotEmpty;
    final showCrypto =
        (!_filterIsActive ||
            _selectedType == null ||
            _selectedType == InvestmentType.crypto) &&
        visibleCryptoPacks.isNotEmpty;
    final showFpi =
        (!_filterIsActive ||
            _selectedType == null ||
            _selectedType == InvestmentType.fpi) &&
        visibleFpiPacks.isNotEmpty;
    final showAction =
        (!_filterIsActive ||
            _selectedType == null ||
            _selectedType == InvestmentType.action) &&
        visibleStockPacks.isNotEmpty;
    final showCommodity =
        (!_filterIsActive ||
            _selectedType == null ||
            _selectedType == InvestmentType.commodity) &&
        visibleCommodityPacks.isNotEmpty;
    final showBanner =
        _search.isEmpty && (!_filterIsActive || _selectedType == null);

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Stack(
          children: [
            _selectedReceipt != null
                ? _buildReceiptPage(_selectedReceipt!)
                : _walletFlow != null
                ? _buildTransferPage()
                : _selectedNavigation == 1
                ? _buildWalletPage()
                : _selectedNavigation == 2
                ? _selectedHoldingDetail == null
                      ? _buildHoldingsPage()
                      : _buildHoldingDetail(_selectedHoldingDetail!)
                : _selectedNavigation == 3
                ? _showSupportEmail
                      ? _buildSupportEmailPage()
                      : _showAuthorizationPage
                      ? _buildAuthorizationPage()
                      : _showHelpInfoPage
                      ? _buildHelpInfoPage()
                      : _buildProfilePage()
                : _selectedNavigation == 4
                ? _buildNotificationsPage()
                : _showInvestmentPage &&
                      _investmentPack != null &&
                      _investmentType != null
                ? _buildInvestmentPage(_investmentPack!, _investmentType!)
                : _selectedReitPack != null
                ? _buildReitPackDetail(_selectedReitPack!, isFpi: false)
                : _selectedFpiPack != null
                ? _buildReitPackDetail(_selectedFpiPack!, isFpi: true)
                : _selectedCommodityPack != null
                ? _buildReitPackDetail(
                    _selectedCommodityPack!,
                    isCommodity: true,
                  )
                : _selectedCryptoPack != null
                ? _buildReitPackDetail(_selectedCryptoPack!, isCrypto: true)
                : _selectedStockPack != null
                ? _buildReitPackDetail(_selectedStockPack!, isAction: true)
                : _showReitPacksPage
                ? _buildReitPacksPage(visibleReitPacks)
                : _showFpiPacksPage
                ? _buildFpiPacksPage(visibleFpiPacks)
                : _showCommodityPacksPage
                ? _buildCommodityPacksPage(visibleCommodityPacks)
                : _showCryptoPacksPage
                ? _buildCryptoPacksPage(visibleCryptoPacks)
                : _showStockPacksPage
                ? _buildStockPacksPage(visibleStockPacks)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 7, 20, 112),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 17),
                      _buildSearch(),
                      const SizedBox(height: 10),
                      _buildTypeSelector(),
                      if (showBanner) ...[
                        const SizedBox(height: 15),
                        _buildHeroBanner(),
                      ],
                      if (showReit) ...[
                        const SizedBox(height: 17),
                        _buildSectionTitle(
                          _tr('Fonds REIT', 'REIT funds'),
                          Icons.apartment_rounded,
                          key: const ValueKey('home-category-Fonds REIT'),
                        ),
                        const SizedBox(height: 8),
                        _buildReitCategoryCard(),
                      ],
                      if (showFpi) ...[
                        const SizedBox(height: 17),
                        _buildSectionTitle(
                          'FPI',
                          Icons.bar_chart_rounded,
                          key: const ValueKey('home-category-FPI'),
                        ),
                        const SizedBox(height: 8),
                        _buildFpiCategoryCard(),
                      ],
                      if (showCommodity) ...[
                        const SizedBox(height: 17),
                        _buildSectionTitle(
                          _tr('Matières premières', 'Commodities'),
                          Icons.diamond_outlined,
                          key: const ValueKey(
                            'home-category-Matières premières',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCommodityCategoryCard(),
                      ],
                      if (showCrypto) ...[
                        const SizedBox(height: 17),
                        _buildSectionTitle(
                          _tr('Cryptomonnaies', 'Cryptocurrencies'),
                          Icons.currency_bitcoin_rounded,
                          iconColor: const Color(0xFFF49A17),
                          key: const ValueKey('home-category-Cryptomonnaies'),
                        ),
                        const SizedBox(height: 8),
                        _buildCryptoCategoryCard(),
                      ],
                      if (showAction) ...[
                        const SizedBox(height: 17),
                        _buildSectionTitle(
                          _tr('Action', 'Stocks'),
                          Icons.show_chart_rounded,
                          key: const ValueKey('home-category-Action'),
                        ),
                        const SizedBox(height: 8),
                        _buildStockCategoryCard(),
                      ],
                      if (!showReit &&
                          !showCrypto &&
                          !showFpi &&
                          !showAction &&
                          !showCommodity &&
                          !showCrypto)
                        _buildEmptyState(),
                    ],
                  ),
            Positioned(
              left:
                  _walletFlow == null &&
                      _selectedHoldingDetail == null &&
                      _selectedReitPack == null &&
                      _selectedFpiPack == null &&
                      _selectedCommodityPack == null &&
                      _selectedCryptoPack == null &&
                      _selectedStockPack == null
                  ? 14
                  : 20,
              right:
                  _walletFlow == null &&
                      _selectedHoldingDetail == null &&
                      _selectedReitPack == null &&
                      _selectedFpiPack == null &&
                      _selectedCommodityPack == null &&
                      _selectedCryptoPack == null &&
                      _selectedStockPack == null
                  ? 14
                  : 20,
              bottom: 10,
              child:
                  _selectedReceipt != null ||
                      _walletFlow != null ||
                      _selectedHoldingDetail != null ||
                      (_selectedNavigation == 3 &&
                          (_showSupportEmail ||
                              _showAuthorizationPage ||
                              _showHelpInfoPage))
                  ? const SizedBox.shrink()
                  : _showInvestmentPage
                  ? _buildInvestmentConfirmationButton()
                  : _selectedReitPack == null &&
                        _selectedFpiPack == null &&
                        _selectedCommodityPack == null &&
                        _selectedCryptoPack == null &&
                        _selectedStockPack == null
                  ? _buildBottomNavigation()
                  : _buildInvestInPackButton(
                      _selectedReitPack ??
                          _selectedFpiPack ??
                          _selectedCommodityPack ??
                          _selectedCryptoPack ??
                          _selectedStockPack!,
                      isFpi: _selectedFpiPack != null,
                      isCommodity: _selectedCommodityPack != null,
                      isCrypto: _selectedCryptoPack != null,
                      isAction: _selectedStockPack != null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              key: const ValueKey('home-logo-static'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/tamleek_logo.jpg',
                      key: const ValueKey('app-logo'),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Flexible(
                    child: Text(
                      'Tamleek',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 23,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _roundIconButton(
          icon: Icons.notifications_none_rounded,
          onPressed: () => setState(() {
            _selectedNavigation = 4;
            _notificationsRead = true;
          }),
          badge: true,
        ),
        const SizedBox(width: 11),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('home-profile-button'),
            customBorder: const CircleBorder(),
            onTap: () => setState(() {
              _selectedHoldingDetail = null;
              _selectedNavigation = 3;
            }),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFDFC1A3), Color(0xFF76513F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                key: const ValueKey('home-profile-avatar'),
                radius: 24,
                backgroundColor: Colors.transparent,
                backgroundImage: _profilePhotoPath == null
                    ? null
                    : FileImage(File(_profilePhotoPath!)),
                child: _profilePhotoPath == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 31,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool badge = false,
  }) {
    return SizedBox(
      width: 47,
      height: 47,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.white.withValues(alpha: 0.72),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: onPressed,
                icon: Icon(icon, color: _ink, size: 23),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          if (badge)
            Positioned(
              top: 8,
              right: 10,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFEE4A4A),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 47,
      padding: const EdgeInsets.only(left: 14, right: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF343E5A).withValues(alpha: 0.06),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 24, color: _ink),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _search = value.trim()),
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: InputDecoration(
                hintText: _tr('Rechercher un actif...', 'Search assets...'),
                hintStyle: const TextStyle(color: _muted, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: _tr('Filtres', 'Filters'),
            onPressed: _showFilters,
            icon: const Icon(Icons.tune_rounded, size: 21, color: _ink),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _typeChip(InvestmentType.reit, 'REIT', Icons.bar_chart_rounded),
          const SizedBox(width: 9),
          _typeChip(InvestmentType.fpi, 'FPI', Icons.trending_up_rounded),
          const SizedBox(width: 9),
          _typeChip(
            InvestmentType.commodity,
            _tr('Matières premières', 'Commodities'),
            Icons.diamond_outlined,
          ),
          const SizedBox(width: 9),
          _typeChip(
            InvestmentType.crypto,
            'Crypto',
            Icons.currency_bitcoin_rounded,
          ),
          const SizedBox(width: 9),
          _typeChip(
            InvestmentType.action,
            _tr('Action', 'Stocks'),
            Icons.show_chart_rounded,
          ),
        ],
      ),
    );
  }

  Widget _typeChip(InvestmentType type, String label, IconData icon) {
    final selected = _selectedType == type;
    return SizedBox(
      key: type == InvestmentType.commodity
          ? const ValueKey('commodity-category-chip')
          : null,
      width: type == InvestmentType.commodity ? 160 : 94,
      height: 43,
      child: Material(
        color: selected ? _ink : Colors.white.withValues(alpha: 0.28),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? _ink
                : const Color(0xFFE7E9F0).withValues(alpha: 0.8),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _selectType(selected ? null : type),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.white : _ink),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return SizedBox(
      height: 194,
      child: PageView.builder(
        key: const ValueKey('home-featured-carousel'),
        controller: _heroPageController,
        itemCount: _heroSlides.length,
        onPageChanged: (index) {
          setState(() => _heroCardIndex = index);
        },
        itemBuilder: (context, index) => _buildHeroSlide(_heroSlides[index]),
      ),
    );
  }

  Widget _buildHeroSlide(_HeroSlide slide) {
    final (tag, title, subtitle, action) = _isEnglish
        ? switch (slide.type) {
            InvestmentType.reit => (
              'REIT',
              'Passive real estate\nincome',
              'Invest in real estate\nwithout managing properties.',
              'Explore REIT',
            ),
            InvestmentType.fpi => (
              'FPI',
              'Invest in real estate\nfunds',
              'Access selected real estate\nfunds.',
              'Explore FPI',
            ),
            InvestmentType.commodity => (
              'COMMODITIES',
              'Diversify your\ninvestments',
              'Discover gold and\ncommodities.',
              'Explore assets',
            ),
            InvestmentType.crypto => (
              'CRYPTO',
              'Explore\ncryptocurrencies',
              'Find Bitcoin and other\ndigital assets.',
              'Explore crypto',
            ),
            InvestmentType.action => (
              'STOCKS',
              'Invest in leading\ncompanies',
              'Discover stocks from\nglobal companies.',
              'Explore stocks',
            ),
          }
        : (slide.tag, slide.title, slide.subtitle, slide.action);
    return ClipRRect(
      key: ValueKey('home-featured-${slide.type.name}'),
      borderRadius: BorderRadius.circular(23),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            slide.image,
            key: ValueKey('home-featured-image-${slide.type.name}'),
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, 0.32, 0.58, 1],
                colors: [
                  Color(0x99FFFFFF),
                  Color(0x66FFFFFF),
                  Color(0x1AFFFFFF),
                  Color(0x00FFFFFF),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 13,
            child: _smallTag(tag, slide.icon, const Color(0xFFEDF4FF)),
          ),
          Positioned(
            right: 14,
            top: 15,
            child: Row(
              children: List.generate(_heroSlides.length, (indicatorIndex) {
                final selected = _heroCardIndex == indicatorIndex;
                return AnimatedContainer(
                  key: ValueKey('hero-indicator-$indicatorIndex'),
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(left: 4),
                  width: selected ? 13 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            left: 15,
            top: 54,
            width: 205,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    height: 1.13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 11),
                SizedBox(
                  height: 37,
                  child: FilledButton(
                    onPressed: () => _showMessage(
                      _tr(
                        'Découvrez ${slide.tag} sur Tamleek.',
                        'Discover $tag on Tamleek.',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      '$action  ›',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallTag(String label, IconData icon, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _ink),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon, {
    Color iconColor = _ink,
    Key? key,
  }) {
    return Row(
      key: key,
      children: [
        Icon(icon, color: iconColor, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReitPackCard(
    _ReitPack pack, {
    bool isFpi = false,
    bool isCommodity = false,
    bool isCrypto = false,
    bool isAction = false,
  }) {
    final categoryPrefix = isAction
        ? 'action'
        : isCrypto
        ? 'crypto'
        : isCommodity
        ? 'commodity'
        : isFpi
        ? 'fpi'
        : 'reit';
    final imageAsset = isAction
        ? 'assets/stocks.png'
        : isCrypto
        ? 'assets/cryptocurrencies.png'
        : isCommodity
        ? 'assets/commodities.png'
        : isFpi
        ? 'assets/fpi.jpg'
        : 'assets/reit.jpg';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: ValueKey('$categoryPrefix-pack-${pack.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() {
            if (isAction) {
              _selectedStockPack = pack;
            } else if (isCrypto) {
              _selectedCryptoPack = pack;
            } else if (isCommodity) {
              _selectedCommodityPack = pack;
            } else if (isFpi) {
              _selectedFpiPack = pack;
            } else {
              _selectedReitPack = pack;
            }
          }),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF343E5A).withValues(alpha: 0.055),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    imageAsset,
                    key: ValueKey(
                      'investment-image-$categoryPrefix-${pack.id}',
                    ),
                    width: 88,
                    height: 82,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        pack.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pack.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  height: 34,
                  child: FilledButton(
                    key: ValueKey('$categoryPrefix-pack-invest-${pack.id}'),
                    onPressed: () => setState(() {
                      if (isAction) {
                        _selectedStockPack = pack;
                      } else if (isCrypto) {
                        _selectedCryptoPack = pack;
                      } else if (isCommodity) {
                        _selectedCommodityPack = pack;
                      } else if (isFpi) {
                        _selectedFpiPack = pack;
                      } else {
                        _selectedReitPack = pack;
                      }
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Investir',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReitCategoryCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('reit-category-card'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _showReitPacksPage = true),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF343E5A).withValues(alpha: 0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/reit.jpg',
                  key: const ValueKey('investment-image-reit'),
                  width: 100,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Fonds REIT',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '5 packs immobiliers à découvrir',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                height: 34,
                child: FilledButton(
                  key: const ValueKey('reit-category-invest-button'),
                  onPressed: () => setState(() => _showReitPacksPage = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Investir',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFpiCategoryCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('fpi-category-card'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _showFpiPacksPage = true),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF343E5A).withValues(alpha: 0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/fpi.jpg',
                  key: const ValueKey('investment-image-fpi'),
                  width: 100,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'FPI',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '5 packs immobiliers européens',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                height: 34,
                child: FilledButton(
                  key: const ValueKey('fpi-category-invest-button'),
                  onPressed: () => setState(() => _showFpiPacksPage = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Investir',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommodityCategoryCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('commodity-category-card'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _showCommodityPacksPage = true),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF343E5A).withValues(alpha: 0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/commodities.png',
                  key: const ValueKey('investment-image-commodity'),
                  width: 100,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Matières premières',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '5 packs de matières premières',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                height: 34,
                child: FilledButton(
                  key: const ValueKey('commodity-category-invest-button'),
                  onPressed: () =>
                      setState(() => _showCommodityPacksPage = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Investir',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoCategoryCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('crypto-category-card'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _showCryptoPacksPage = true),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF343E5A).withValues(alpha: 0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/cryptocurrencies.png',
                  key: const ValueKey('investment-image-crypto'),
                  width: 100,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Cryptomonnaies',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '5 packs crypto',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                height: 34,
                child: FilledButton(
                  key: const ValueKey('crypto-category-invest-button'),
                  onPressed: () => setState(() => _showCryptoPacksPage = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Investir',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoPacksPage(List<_ReitPack> packs) {
    return ListView(
      key: const ValueKey('crypto-packs-page'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('crypto-packs-back'),
              onPressed: () => setState(() {
                _showCryptoPacksPage = false;
                _search = '';
              }),
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
              tooltip: 'Retour aux catégories',
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Cryptomonnaies',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'Choisissez un pack pour découvrir sa composition et ses risques.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: 17),
        ...packs.map((pack) => _buildReitPackCard(pack, isCrypto: true)),
        if (packs.isEmpty) _buildEmptyState(),
      ],
    );
  }

  Widget _buildStockCategoryCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('action-category-card'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _showStockPacksPage = true),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF343E5A).withValues(alpha: 0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/stocks.png',
                  key: const ValueKey('investment-image-action'),
                  width: 100,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Actions',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '5 packs d’actions',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                height: 34,
                child: FilledButton(
                  key: const ValueKey('action-category-invest-button'),
                  onPressed: () => setState(() => _showStockPacksPage = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Investir',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockPacksPage(List<_ReitPack> packs) {
    return ListView(
      key: const ValueKey('action-packs-page'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('action-packs-back'),
              onPressed: () => setState(() {
                _showStockPacksPage = false;
                _search = '';
              }),
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
              tooltip: 'Retour aux catégories',
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Actions',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'Choisissez un pack pour découvrir sa composition et ses risques.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: 17),
        ...packs.map((pack) => _buildReitPackCard(pack, isAction: true)),
        if (packs.isEmpty) _buildEmptyState(),
      ],
    );
  }

  Widget _buildCommodityPacksPage(List<_ReitPack> packs) {
    return ListView(
      key: const ValueKey('commodity-packs-page'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('commodity-packs-back'),
              onPressed: () => setState(() {
                _showCommodityPacksPage = false;
                _search = '';
              }),
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
              tooltip: 'Retour aux catégories',
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Matières premières',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'Choisissez un pack pour découvrir les matières qui le composent.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: 17),
        ...packs.map((pack) => _buildReitPackCard(pack, isCommodity: true)),
        if (packs.isEmpty) _buildEmptyState(),
      ],
    );
  }

  Widget _buildFpiPacksPage(List<_ReitPack> packs) {
    return ListView(
      key: const ValueKey('fpi-packs-page'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('fpi-packs-back'),
              onPressed: () => setState(() {
                _showFpiPacksPage = false;
                _search = '';
              }),
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
              tooltip: 'Retour aux catégories',
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'FPI',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'Choisissez un pack immobilier européen à découvrir.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: 17),
        ...packs.map((pack) => _buildReitPackCard(pack, isFpi: true)),
        if (packs.isEmpty) _buildEmptyState(),
      ],
    );
  }

  Widget _buildReitPacksPage(List<_ReitPack> packs) {
    return ListView(
      key: const ValueKey('reit-packs-page'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('reit-packs-back'),
              onPressed: () => setState(() {
                _showReitPacksPage = false;
                _search = '';
              }),
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
              tooltip: 'Retour aux catégories',
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Fonds REIT',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'Choisissez un pack pour découvrir sa composition et ses revenus.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: 17),
        ...packs.map(_buildReitPackCard),
        if (packs.isEmpty) _buildEmptyState(),
      ],
    );
  }

  Widget _buildReitPackDetail(
    _ReitPack pack, {
    bool isFpi = false,
    bool isCommodity = false,
    bool isCrypto = false,
    bool isAction = false,
  }) {
    final categoryPrefix = isAction
        ? 'action'
        : isCrypto
        ? 'crypto'
        : isCommodity
        ? 'commodity'
        : isFpi
        ? 'fpi'
        : 'reit';
    final imageAsset = isAction
        ? 'assets/stocks.png'
        : isCrypto
        ? 'assets/cryptocurrencies.png'
        : isCommodity
        ? 'assets/commodities.png'
        : isFpi
        ? 'assets/fpi.jpg'
        : 'assets/reit.jpg';
    return ListView(
      key: ValueKey('$categoryPrefix-pack-detail-${pack.id}'),
      padding: const EdgeInsets.only(bottom: 112),
      children: [
        SizedBox(
          height: 300,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 248,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      imageAsset,
                      key: const ValueKey('reit-pack-detail-image'),
                      fit: BoxFit.cover,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.24),
                            Colors.black.withValues(alpha: 0.02),
                            Colors.black.withValues(alpha: 0.48),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 14,
                      child: _packImageButton(
                        key: const ValueKey('reit-pack-back'),
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Retour aux packs',
                        onPressed: () => setState(() {
                          if (isAction) {
                            _selectedStockPack = null;
                          } else if (isCrypto) {
                            _selectedCryptoPack = null;
                          } else if (isCommodity) {
                            _selectedCommodityPack = null;
                          } else if (isFpi) {
                            _selectedFpiPack = null;
                          } else {
                            _selectedReitPack = null;
                          }
                        }),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      right: 17,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAction
                              ? 'ACTIONS'
                              : isCrypto
                              ? 'CRYPTO'
                              : isCommodity
                              ? 'MATIÈRES PREMIÈRES'
                              : isFpi
                              ? 'FPI'
                              : 'FONDS REIT',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 32,
                      child: Row(
                        children: [
                          Icon(pack.icon, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            isAction
                                ? 'Investissement en actions'
                                : isCrypto
                                ? 'Diversification crypto'
                                : isCommodity
                                ? 'Diversification matières premières'
                                : 'Investissement immobilier',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 0,
                child: _buildPackOverviewCard(pack),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              _buildPackSectionTitle('À propos de ce pack'),
              const SizedBox(height: 8),
              Text(
                pack.description,
                style: const TextStyle(color: _ink, fontSize: 13, height: 1.55),
              ),
              const SizedBox(height: 22),
              _buildPackSectionTitle('Composition du pack'),
              const SizedBox(height: 9),
              ...pack.holdings.map(_buildReitHoldingCard),
            ],
          ),
        ),
      ],
    );
  }

  Widget _packImageButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      child: IconButton(
        key: key,
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: _ink, size: 20),
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPackOverviewCard(_ReitPack pack) {
    return Container(
      key: const ValueKey('reit-pack-overview-card'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF202943).withValues(alpha: 0.13),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pack.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Min. 10 \$',
                  style: const TextStyle(
                    color: Color(0xFF8A5B00),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            pack.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  void _openInvestmentPage(_ReitPack pack, InvestmentType type) {
    _investmentAmountController.clear();
    setState(() {
      _investmentPack = pack;
      _investmentType = type;
      _investmentMode = _InvestmentMode.fractional;
      _showInvestmentPage = true;
    });
  }

  bool _isValidInvestmentAmount(double amount) {
    final minimumAmount = _investmentMode == _InvestmentMode.fractional
        ? _fractionalInvestmentMinimum
        : _wholeInvestmentMinimum;
    return amount >= minimumAmount &&
        amount <= _investmentAvailableBalance &&
        (_investmentMode == _InvestmentMode.fractional ||
            amount % _wholeInvestmentMinimum == 0);
  }

  List<_HoldingPosition> _heldPositionsForPack(
    _ReitPack pack,
    InvestmentType type,
  ) {
    final category = switch (type) {
      InvestmentType.reit => 'REIT',
      InvestmentType.fpi => 'FPI',
      InvestmentType.commodity => 'Matières premières',
      InvestmentType.crypto => 'Crypto',
      InvestmentType.action => 'Action',
    };
    return _demoHoldings
        .where(
          (holding) =>
              holding.category == category && holding.packId == pack.id,
        )
        .toList(growable: false);
  }

  String _investmentCategoryLabel(InvestmentType type) => switch (type) {
    InvestmentType.reit => 'Fonds REIT',
    InvestmentType.fpi => 'FPI',
    InvestmentType.commodity => 'Matières premières',
    InvestmentType.crypto => 'Cryptomonnaies',
    InvestmentType.action => 'Actions',
  };

  String _investmentImageAsset(InvestmentType type) => switch (type) {
    InvestmentType.reit => 'assets/reit.jpg',
    InvestmentType.fpi => 'assets/fpi.jpg',
    InvestmentType.commodity => 'assets/commodities.png',
    InvestmentType.crypto => 'assets/cryptocurrencies.png',
    InvestmentType.action => 'assets/stocks.png',
  };

  Widget _buildInvestmentPage(_ReitPack pack, InvestmentType type) {
    final category = _investmentCategoryLabel(type);
    final imageAsset = _investmentImageAsset(type);
    final amount =
        double.tryParse(
          _investmentAmountController.text.replaceAll(',', '.'),
        ) ??
        0;
    final heldPositions = _heldPositionsForPack(pack, type);
    final minimumAmount = _investmentMode == _InvestmentMode.fractional
        ? _fractionalInvestmentMinimum
        : _wholeInvestmentMinimum;
    final minimumAmountLabel = _investmentMode == _InvestmentMode.fractional
        ? '\$10.00'
        : '\$1,000.00';
    final canContinue = _isValidInvestmentAmount(amount);
    final annualMultiplier = math
        .pow(1 + _fractionalMonthlyReturn, 12)
        .toDouble();
    final annualReturnPercent = (annualMultiplier - 1) * 100;
    final amountPresets = _investmentMode == _InvestmentMode.fractional
        ? [10, 50, 100, 500]
        : [1000, 2000, 5000, 8000];

    return ListView(
      key: const ValueKey('investment-page'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('investment-page-back'),
              onPressed: () => setState(() => _showInvestmentPage = false),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Retour au détail du pack',
            ),
            const SizedBox(width: 4),
            const Text(
              'Investir',
              style: TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('investment-selected-pack'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  imageAsset,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      pack.name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pack.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (heldPositions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('investment-owned-assets'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD8DFEA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Position déjà détenue',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final (index, position) in heldPositions.indexed) ...[
                  if (index > 0) const Divider(height: 18),
                  _investmentSummaryRow('Pack détenu', pack.name),
                  const SizedBox(height: 7),
                  _investmentSummaryRow('Actif du pack', position.name),
                  const SizedBox(height: 7),
                  _investmentSummaryRow(
                    'Valeur estimée',
                    _formatInvestmentCurrency(position.value),
                  ),
                  const SizedBox(height: 7),
                  _investmentSummaryRow(
                    'Frais de revente (5 %)',
                    _formatInvestmentCurrency(position.value * _resaleFeeRate),
                  ),
                  _investmentSummaryRow(
                    'Montant net estimé',
                    _formatInvestmentCurrency(
                      position.value * (1 - _resaleFeeRate),
                    ),
                    emphasize: true,
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _investmentMode == _InvestmentMode.fractional
                        ? 'Investissement fractionné'
                        : 'Parts entières',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _investmentMode == _InvestmentMode.fractional
                        ? 'À partir de 10 \$'
                        : '1 part = 1 000 \$',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              key: const ValueKey('investment-mode-switch'),
              value: _investmentMode == _InvestmentMode.whole,
              onChanged: (isWhole) {
                _investmentAmountController.clear();
                setState(
                  () => _investmentMode = isWhole
                      ? _InvestmentMode.whole
                      : _InvestmentMode.fractional,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 17),
        const Text(
          'Montant à investir',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          key: const ValueKey('investment-amount-input'),
          controller: _investmentAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixText: '\$ ',
            hintText: minimumAmount.toStringAsFixed(2),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD8DFEA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD8DFEA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF314A70),
                width: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amountPresets.map((preset) {
            return ActionChip(
              key: ValueKey('investment-amount-preset-$preset'),
              label: Text('\$$preset'),
              onPressed: () {
                _investmentAmountController.text = preset.toString();
                setState(() {});
              },
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD8DFEA)),
              labelStyle: const TextStyle(
                color: Color(0xFF314A70),
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('investment-amount-summary'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _investmentSummaryRow(
                'Solde disponible',
                '\$${_investmentAvailableBalance.toStringAsFixed(2)}',
              ),
              const Divider(height: 22),
              _investmentSummaryRow(
                _investmentMode == _InvestmentMode.fractional
                    ? 'Minimum fractionné'
                    : 'Prix par part entière',
                minimumAmountLabel,
              ),
              if (amount > 0) ...[
                const Divider(height: 22),
                _investmentSummaryRow(
                  'Montant sélectionné',
                  _formatInvestmentCurrency(amount),
                  emphasize: true,
                ),
                if (_investmentMode == _InvestmentMode.whole) ...[
                  const Divider(height: 22),
                  _investmentSummaryRow(
                    'Nombre de parts entières',
                    '${(amount / _wholeInvestmentMinimum).round()}',
                  ),
                ],
              ],
            ],
          ),
        ),
        if (_investmentMode == _InvestmentMode.whole) ...[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('investment-whole-minimum-note'),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Chaque part entière vaut 1 000 \$. Le montant doit être un '
              'multiple de 1 000 \$.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('investment-yield-projection'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC8E8D5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Projection indicative — ${_investmentMode == _InvestmentMode.fractional ? 'fractionné' : 'parts entières'}',
                style: const TextStyle(
                  color: Color(0xFF176B43),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _investmentSummaryRow(
                'Hypothèse mensuelle',
                '${(_fractionalMonthlyReturn * 100).toStringAsFixed(0)} %',
              ),
              const SizedBox(height: 9),
              _investmentSummaryRow(
                'Hypothèse annuelle composée',
                '${annualReturnPercent.toStringAsFixed(2)} %',
              ),
              if (amount > 0) ...[
                const Divider(height: 22),
                _investmentSummaryRow(
                  'Gain estimé après 1 mois',
                  _formatInvestmentCurrency(amount * _fractionalMonthlyReturn),
                ),
                const SizedBox(height: 9),
                _investmentSummaryRow(
                  'Valeur estimée après 12 mois',
                  _formatInvestmentCurrency(amount * annualMultiplier),
                  emphasize: true,
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Calcul avec réinvestissement mensuel des gains.',
                style: TextStyle(
                  color: Color(0xFF426957),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF2D99A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF946200),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La projection de 20 % par mois est illustrative, non '
                  'garantie, et n’est pas une promesse de gain. Aucun achat '
                  'réel n’est effectué.',
                  style: const TextStyle(
                    color: Color(0xFF6B520F),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_investmentAmountController.text.isNotEmpty && !canContinue) ...[
          const SizedBox(height: 8),
          Text(
            _investmentMode == _InvestmentMode.fractional
                ? 'Saisissez un montant entre 10 \$ et 8 250 \$.'
                : 'Saisissez un nombre entier de parts (1 000 \$ par part), '
                      'jusqu’à 8 000 \$.',
            style: TextStyle(color: Color(0xFFB3261E), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _investmentSummaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? const Color(0xFF314A70) : _ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatInvestmentCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '\$$whole.${parts.last}';
  }

  Widget _buildInvestmentConfirmationButton() {
    final amount =
        double.tryParse(
          _investmentAmountController.text.replaceAll(',', '.'),
        ) ??
        0;
    final canContinue = _isValidInvestmentAmount(amount);
    final kycRequired = amount > 5000 && !_kycRequirementMet;
    final heldPositions = _investmentType == null || _investmentPack == null
        ? const <_HoldingPosition>[]
        : _heldPositionsForPack(_investmentPack!, _investmentType!);
    final continueButton = SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        key: const ValueKey('investment-continue-button'),
        onPressed: canContinue
            ? () async {
                if (amount > 5000 && !_kycRequirementMet) {
                  await _showKycForm();
                  return;
                }
                final pack = _investmentPack!;
                final type = _investmentType!;
                final isWhole = _investmentMode == _InvestmentMode.whole;
                await _showReceiptConfirmation('investissement');
                if (!mounted) return;
                _openReceipt(
                  operation: 'Demande d’investissement',
                  amount: amount,
                  details: [
                    ('Type d’opération', 'Investissement'),
                    ('Catégorie', _investmentCategoryLabel(type)),
                    ('Pack sélectionné', pack.name),
                    (
                      'Mode',
                      isWhole ? 'Parts entières' : 'Investissement fractionné',
                    ),
                    if (isWhole)
                      (
                        'Nombre de parts',
                        '${(amount / _wholeInvestmentMinimum).round()}',
                      ),
                  ],
                  status: 'Non exécuté',
                  notice:
                      'La demande est affichée à titre informatif. Le service '
                      'd’investissement n’est pas connecté et aucun achat '
                      'n’a été effectué.',
                  backgroundAsset: _investmentImageAsset(type),
                  totalLabel: 'Montant demandé',
                );
              }
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF08A957),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB8C0CC),
          shape: const StadiumBorder(),
        ),
        child: Text(
          kycRequired ? 'Compléter le KYC requis' : 'Continuer',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
    if (heldPositions.isEmpty) return continueButton;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              key: const ValueKey('investment-resale-button'),
              onPressed: () => _showResaleConfirmation(
                _investmentPack!,
                heldPositions.first,
              ),
              icon: const Icon(Icons.sell_outlined, size: 18),
              label: const Text('Revendre le pack'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: continueButton),
      ],
    );
  }

  Future<void> _showResaleConfirmation(
    _ReitPack pack,
    _HoldingPosition position,
  ) async {
    final resaleFee = position.value * _resaleFeeRate;
    final netAmount = position.value - resaleFee;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('investment-resale-dialog'),
        title: Text('Revendre ${pack.name} ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _investmentSummaryRow(
              'Valeur estimée',
              _formatInvestmentCurrency(position.value),
            ),
            const SizedBox(height: 10),
            _investmentSummaryRow(
              'Frais de revente (5 %)',
              _formatInvestmentCurrency(resaleFee),
            ),
            const Divider(height: 22),
            _investmentSummaryRow(
              'Montant net estimé',
              _formatInvestmentCurrency(netAmount),
              emphasize: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'Estimation basée sur la valeur indicative actuelle. '
              'Aucune vente ne sera exécutée dans cette version.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('investment-resale-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _showReceiptConfirmation('revente');
      if (!mounted) return;
      _openReceipt(
        operation: 'Demande de revente du pack',
        amount: netAmount,
        details: [
          ('Type d’opération', 'Revente'),
          ('Pack détenu', pack.name),
          ('Actif du pack', position.name),
          (
            'Valeur estimée avant frais',
            _formatInvestmentCurrency(position.value),
          ),
          ('Frais de revente (5 %)', _formatInvestmentCurrency(resaleFee)),
          ('Montant net estimé', _formatInvestmentCurrency(netAmount)),
        ],
        status: 'Non exécuté',
        notice:
            'La demande de revente est affichée à titre informatif. Aucun '
            'service de transaction n’est connecté et aucun actif n’a été vendu.',
        backgroundAsset: _investmentImageAsset(_investmentType!),
        totalLabel: 'Montant net estimé',
      );
    }
  }

  Widget _buildInvestInPackButton(
    _ReitPack pack, {
    required bool isFpi,
    required bool isCommodity,
    required bool isCrypto,
    required bool isAction,
  }) {
    final investmentType = isAction
        ? InvestmentType.action
        : isCrypto
        ? InvestmentType.crypto
        : isCommodity
        ? InvestmentType.commodity
        : isFpi
        ? InvestmentType.fpi
        : InvestmentType.reit;
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        key: const ValueKey('reit-pack-invest-button'),
        onPressed: () => _openInvestmentPage(pack, investmentType),
        icon: const Icon(Icons.trending_up_rounded, size: 20),
        label: const Text(
          'Investir',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF08A957),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          elevation: 5,
          shadowColor: const Color(0xFF08A957).withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildPackSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: _ink,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _buildReitHoldingCard(_ReitHolding holding) {
    return Container(
      key: ValueKey('reit-holding-${holding.ticker}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.apartment_rounded,
              key: ValueKey('pack-holding-icon-${holding.ticker}'),
              color: const Color(0xFF314A70),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding.name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  holding.allocation == null
                      ? holding.ticker
                      : '${holding.ticker} · ${holding.allocation}',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: _muted.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            _tr('Aucun actif trouvé', 'No assets found'),
            style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _tr('Essayez une autre recherche.', 'Try another search.'),
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 112),
      children: [
        const Text(
          'Portefeuille',
          style: TextStyle(
            color: _ink,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Votre solde et vos opérations',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 184,
          child: PageView(
            key: const ValueKey('wallet-balance-carousel'),
            controller: _walletPageController,
            onPageChanged: (index) => setState(() => _walletCardIndex = index),
            children: [
              _walletBalanceCard(
                key: const ValueKey('wallet-total-card'),
                title: 'SOLDE TOTAL',
                amount: '\$12,450.00',
                currencySelector: true,
                background: const Color(0xFF11141E),
                foreground: Colors.white,
              ),
              _walletBalanceCard(
                key: const ValueKey('wallet-available-card'),
                title: 'DISPONIBLE',
                amount: '\$8,250.00',
                icon: Icons.account_balance_wallet_outlined,
                background: const Color(0xFF11141E),
                foreground: Colors.white,
              ),
              _walletBalanceCard(
                key: const ValueKey('wallet-invested-card'),
                title: 'INVESTI',
                amount: '\$4,200.00',
                icon: Icons.show_chart_rounded,
                background: const Color(0xFF11141E),
                foreground: Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final selected = _walletCardIndex == index;
            return AnimatedContainer(
              key: ValueKey('wallet-page-indicator-$index'),
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: selected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? _ink : const Color(0xFFCFD2DA),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _walletAction(
                icon: Icons.add_rounded,
                label: 'Déposer',
                color: const Color(0xFF28334A),
                onTap: () => setState(() {
                  _walletFlow = _WalletFlow.deposit;
                  _transferAmountController.clear();
                  _transactionHashController.clear();
                  _destinationAddressController.clear();
                  _selectedTransferNetwork = 'Polygon';
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _walletAction(
                icon: Icons.arrow_upward_rounded,
                label: 'Retirer',
                color: const Color(0xFF28334A),
                onTap: () => setState(() {
                  _walletFlow = _WalletFlow.withdraw;
                  _transferAmountController.clear();
                  _transactionHashController.clear();
                  _destinationAddressController.clear();
                  _selectedTransferNetwork = 'Polygon';
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Activité récente',
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showMessage(
                'Toutes les opérations seront bientôt disponibles.',
              ),
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _walletActivity(
          key: 'wallet-activity-deposit',
          icon: Icons.add_rounded,
          iconColor: const Color(0xFF188A58),
          title: 'Dépôt de fonds',
          subtitle: 'Aujourd’hui · 10:42',
          amount: '+\$2,500.00',
          positive: true,
          onTap: () => _openDemoReceipt(
            operation: 'Dépôt USDT',
            amount: 2500,
            details: [
              ('Type d’opération', 'Dépôt'),
              ('Montant', '\$2,500.00'),
              ('Mode de paiement', 'USDT · Polygon'),
            ],
            dateLabel: 'Aujourd’hui · 10:42',
            backgroundAsset: 'assets/cryptocurrencies.png',
          ),
        ),
        _walletActivity(
          key: 'wallet-activity-withdraw',
          icon: Icons.arrow_upward_rounded,
          iconColor: const Color(0xFFB36B20),
          title: 'Retrait USDT',
          subtitle: 'Aujourd’hui · 09:20',
          amount: '-\$800.00',
          positive: false,
          onTap: () => _openDemoReceipt(
            operation: 'Retrait USDT',
            amount: 800,
            details: [
              ('Type d’opération', 'Retrait'),
              ('Montant', '\$800.00'),
              ('Mode de paiement', 'USDT · Solana'),
              ('Adresse de destination', 'Exemple uniquement'),
            ],
            dateLabel: 'Aujourd’hui · 09:20',
            backgroundAsset: 'assets/cryptocurrencies.png',
          ),
        ),
        _walletActivity(
          key: 'wallet-activity-reit-investment',
          icon: Icons.apartment_rounded,
          iconColor: const Color(0xFF3769C8),
          title: 'Investissement REIT',
          subtitle: 'Hier · 15:18',
          amount: '-\$1,200.00',
          positive: false,
          onTap: () => _openDemoReceipt(
            operation: 'Investissement REIT',
            amount: 1200,
            details: [
              ('Type d’opération', 'Investissement'),
              ('Pack sélectionné', 'ETF clé en main mondial'),
              ('Montant', '\$1,200.00'),
            ],
            dateLabel: 'Hier · 15:18',
            backgroundAsset: 'assets/reit.jpg',
          ),
        ),
        _walletActivity(
          key: 'wallet-activity-crypto-investment',
          icon: Icons.currency_bitcoin_rounded,
          iconColor: const Color(0xFFF49A17),
          title: 'Achat Bitcoin',
          subtitle: '12 nov. 2026 · 09:30',
          amount: '-\$550.00',
          positive: false,
          onTap: () => _openDemoReceipt(
            operation: 'Investissement Bitcoin',
            amount: 550,
            details: [
              ('Type d’opération', 'Investissement crypto'),
              ('Pack sélectionné', 'Majors'),
              ('Actif', 'Bitcoin (BTC)'),
              ('Montant', '\$550.00'),
            ],
            dateLabel: '12 nov. 2026 · 09:30',
            backgroundAsset: 'assets/cryptocurrencies.png',
          ),
        ),
        _walletActivity(
          key: 'wallet-activity-resale',
          icon: Icons.sell_outlined,
          iconColor: const Color(0xFF8A5B00),
          title: 'Revente d’or',
          subtitle: '10 nov. 2026 · 11:05',
          amount: '+\$380.00',
          positive: true,
          onTap: () => _openDemoReceipt(
            operation: 'Revente d’or',
            amount: 380,
            details: [
              ('Type d’opération', 'Revente'),
              ('Pack détenu', 'Métaux précieux'),
              ('Valeur de l’actif', '\$400.00'),
              ('Frais de revente (5 %)', '\$20.00'),
              ('Montant net', '\$380.00'),
            ],
            dateLabel: '10 nov. 2026 · 11:05',
            backgroundAsset: 'assets/commodities.png',
            totalLabel: 'Montant net',
          ),
        ),
      ],
    );
  }

  Widget _buildTransferPage() {
    final isDeposit = _walletFlow == _WalletFlow.deposit;
    final title = isDeposit ? 'Déposer des fonds' : 'Retirer des fonds';
    const networks = [
      ('Polygon', 'polygon', 'assets/polygon_logo.png'),
      ('BNB Smart Chain', 'bnb-smart-chain', 'assets/bnb_logo.png'),
      ('TRON (TRC-20)', 'tron (trc-20)', 'assets/tron_logo.png'),
      ('Solana', 'solana', 'assets/solana_logo.png'),
      ('Ethereum (ERC-20)', 'ethereum (erc-20)', 'assets/ethereum_logo.png'),
    ];

    return ListView(
      key: ValueKey(isDeposit ? 'deposit-page' : 'withdraw-page'),
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('transfer-back'),
              onPressed: () => setState(() => _walletFlow = null),
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
              tooltip: 'Retour au portefeuille',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isDeposit
              ? 'Choisissez un réseau et le montant à déposer.'
              : 'Choisissez un réseau et le montant à retirer.',
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        _buildPackSectionTitle('Réseau de transfert'),
        const SizedBox(height: 11),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: const ValueKey('transfer-network-dropdown'),
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              final network = await _showTransferNetworkPicker(networks);
              if (network != null && mounted) {
                setState(() => _selectedTransferNetwork = network);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE1E4EA)),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      networks
                          .firstWhere(
                            (network) => network.$1 == _selectedTransferNetwork,
                          )
                          .$3,
                      key: const ValueKey('transfer-network-selected-logo'),
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      _selectedTransferNetwork,
                      key: const ValueKey('transfer-network-selected'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: _ink),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _buildPackSectionTitle('Actif'),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('transfer-asset-usdt'),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE1E4EA)),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/usdt_logo.png',
                  key: const ValueKey('transfer-asset-logo-usdt'),
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tether USD',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'USDT · Stablecoin',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF18A765),
                size: 20,
              ),
            ],
          ),
        ),
        if (isDeposit) ...[
          const SizedBox(height: 18),
          _buildDepositAddressCard(),
        ],
        if (!isDeposit && !_kycRequirementMet) ...[
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('withdrawal-kyc-required'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _tr(
                'La vérification KYC est requise pour tout retrait. Vous '
                    'devrez compléter vos informations avant de préparer la '
                    'demande.',
                'KYC information is required for every withdrawal. Complete '
                    'your information before preparing the request.',
              ),
              style: const TextStyle(
                color: Color(0xFF70521A),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        _buildPackSectionTitle('Montant en dollars'),
        const SizedBox(height: 10),
        Form(
          key: _transferFormKey,
          child: TextFormField(
            key: const ValueKey('transfer-amount-input'),
            controller: _transferAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              prefixText: '\$ ',
              hintText: '0.00',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE1E4EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE1E4EA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF18A765),
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              final amount = double.tryParse(
                (value ?? '').trim().replaceAll(',', '.'),
              );
              if (amount == null || !amount.isFinite || amount <= 0) {
                return 'Saisissez un montant valide.';
              }
              if (isDeposit && amount < 10) {
                return 'Le dépôt minimum est de 10 \$.';
              }
              if (!isDeposit && amount > 8250) {
                return 'Le montant dépasse votre solde disponible de 8 250 \$.';
              }
              return null;
            },
          ),
        ),
        if (isDeposit) ...[
          const SizedBox(height: 18),
          _buildTransactionHashField(),
        ],
        if (!isDeposit) ...[
          const SizedBox(height: 20),
          _buildPackSectionTitle('Adresse de destination'),
          const SizedBox(height: 10),
          TextFormField(
            key: _destinationAddressFieldKey,
            restorationId: 'transfer-destination-input',
            controller: _destinationAddressController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'Saisissez votre adresse crypto',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE1E4EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE1E4EA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF18A765),
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (!isDeposit && (value == null || value.trim().isEmpty)) {
                return 'Saisissez une adresse de destination.';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 10),
        Text(
          isDeposit
              ? 'Dépôt minimum : 10 \$. Actif accepté : USDT sur le réseau choisi.'
              : 'Solde disponible : 8 250 \$. Retrait en USDT sur le réseau choisi.',
          style: const TextStyle(color: _muted, fontSize: 11, height: 1.45),
        ),
        const SizedBox(height: 18),
        Container(
          key: const ValueKey('transfer-network-notice'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF996300),
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isDeposit
                      ? 'Envoyez uniquement de l’USDT sur le réseau choisi. Après l’envoi, collez le hash de transaction. La vérification automatique et le crédit du solde nécessitent encore la connexion du serveur Tamleek.'
                      : 'Vérifiez le réseau et l’adresse de destination. Les retraits ne sont pas encore connectés au portefeuille Tamleek.',
                  style: const TextStyle(
                    color: Color(0xFF70521A),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const ValueKey('transfer-submit'),
            onPressed: _submitTransferRequest,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF18A765),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: Text(
              isDeposit
                  ? 'Continuer le dépôt'
                  : _kycRequirementMet
                  ? 'Continuer le retrait'
                  : 'Compléter le KYC pour continuer',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareReceiptImage() async {
    final receipt = _selectedReceipt;
    if (receipt == null) return;

    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _receiptImageBoundaryKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      await _showMessage('L’image du reçu n’est pas encore prête. Réessayez.');
      return;
    }

    try {
      final image = await renderObject.toImage(pixelRatio: 3);
      late final List<int> pngBytes;
      try {
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        if (byteData == null) {
          await _showMessage('L’image du reçu n’a pas pu être créée.');
          return;
        }
        pngBytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      } finally {
        image.dispose();
      }

      final temporaryDirectory = await getTemporaryDirectory();
      final imageFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        'tamleek-${receipt.reference}.png',
      );
      await imageFile.writeAsBytes(pngBytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(imageFile.path)],
          previewThumbnail: XFile(imageFile.path),
          subject: 'Reçu Tamleek ${receipt.reference}',
          text: 'Reçu Tamleek · ${receipt.operation} · ${receipt.status}',
        ),
      );
    } on FileSystemException {
      if (mounted) {
        await _showMessage(
          'Le fichier image du reçu n’a pas pu être enregistré.',
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage(
          'Le partage du reçu a échoué. ${error.message ?? ''}',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        await _showMessage(
          'Le partage d’image n’est pas disponible sur cet appareil.',
        );
      }
    }
  }

  Widget _buildReceiptPage(_TransactionReceipt receipt) {
    final date = receipt.date;
    final dateLabel =
        receipt.dateLabel ??
        '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year} · '
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}';
    final isSuccessful = receipt.status == 'Réussi';
    final statusColor = isSuccessful
        ? const Color(0xFF188A58)
        : const Color(0xFF8A5B00);
    final statusBackground = isSuccessful
        ? const Color(0xFFE7F7EC)
        : const Color(0xFFFFF3D9);

    return ListView(
      key: const ValueKey('receipt-page'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('receipt-back'),
              onPressed: () => setState(() => _selectedReceipt = null),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Retour',
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Reçu de transaction',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('receipt-share-button'),
              onPressed: _shareReceiptImage,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF17233A),
                foregroundColor: Colors.white,
                fixedSize: const Size(46, 46),
                shape: const CircleBorder(),
              ),
              tooltip: 'Partager le reçu en image',
              icon: const Icon(Icons.share_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RepaintBoundary(
          key: _receiptImageBoundaryKey,
          child: CustomPaint(
            foregroundPainter: const _ScallopedReceiptBorderPainter(),
            child: ClipPath(
              key: const ValueKey('receipt-scalloped-clip'),
              clipper: const _ScallopedReceiptClipper(),
              child: Container(
                key: const ValueKey('receipt-ticket'),
                padding: const EdgeInsets.all(18),
                color: Colors.white,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.035,
                        child: Image.asset(
                          receipt.backgroundAsset,
                          key: const ValueKey('receipt-watermark-image'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildReceiptBanner(receipt.backgroundAsset),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17233A),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFFFFC32B),
                                size: 28,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  receipt.operation,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _receiptDetailRow(
                          'N° de transaction',
                          receipt.reference,
                        ),
                        const SizedBox(height: 6),
                        _receiptDetailRow('Date', dateLabel),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F2F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 19,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profileName.isEmpty
                                          ? 'Membre Tamleek'
                                          : _profileName,
                                      style: const TextStyle(
                                        color: _ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _profileEmail.isEmpty
                                          ? 'Compte local'
                                          : _profileEmail,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'DÉTAILS DE LA TRANSACTION',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 11),
                        for (final (label, value) in receipt.details) ...[
                          _receiptDetailRow(label, value),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0BE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _receiptDetailRow(
                            receipt.totalLabel,
                            _formatInvestmentCurrency(receipt.amount),
                            emphasize: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: statusBackground,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSuccessful
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                color: statusColor,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'Statut : ${receipt.status}',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          receipt.notice,
                          key: const ValueKey('receipt-notice'),
                          style: const TextStyle(
                            color: Color(0xFF5C6470),
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 6),
                        const Text(
                          'Tamleek — Votre partenaire de confiance',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton(
            key: const ValueKey('receipt-done'),
            onPressed: () => setState(() => _selectedReceipt = null),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF17233A),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Terminé'),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptBanner(String imageAsset) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: 94,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imageAsset,
              key: const ValueKey('receipt-banner-image'),
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xEFFFFFFF), Color(0x99FFFFFF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      'assets/tamleek_logo.jpg',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tamleek',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Investir. Construire. Grandir.',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFFE5AD16),
                    size: 28,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptDetailRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _ink : _muted,
              fontSize: emphasize ? 14 : 11,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: _ink,
              fontSize: emphasize ? 16 : 11,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepositAddressCard() {
    final (address, qrAsset) = _depositDestinations[_selectedTransferNetwork]!;
    return Container(
      key: const ValueKey('transfer-deposit-address-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E4EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adresse de dépôt USDT',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedTransferNetwork,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                qrAsset,
                key: const ValueKey('transfer-deposit-qr'),
                width: 156,
                height: 156,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  address,
                  key: const ValueKey('transfer-deposit-address'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('transfer-copy-deposit-address'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (mounted) {
                    await _showSuccessConfirmation(
                      title: 'Adresse copiée',
                      message:
                          'L’adresse de dépôt $_selectedTransferNetwork a été copiée.',
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 19),
                color: const Color(0xFF18A765),
                tooltip: 'Copier l’adresse',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Envoyez uniquement de l’USDT sur ce réseau. Vérifiez l’adresse avant chaque envoi.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHashField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPackSectionTitle('Hash de transaction'),
        const SizedBox(height: 10),
        Form(
          key: _transactionHashFormKey,
          child: TextFormField(
            key: const ValueKey('transfer-transaction-hash-input'),
            controller: _transactionHashController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'Collez le hash depuis votre wallet',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE1E4EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE1E4EA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF18A765),
                  width: 1.5,
                ),
              ),
            ),
            validator: _validateTransactionHash,
          ),
        ),
      ],
    );
  }

  String? _validateTransactionHash(String? value) {
    final hash = (value ?? '').trim();
    if (hash.isEmpty) return 'Saisissez le hash de votre transaction.';

    final valid = switch (_selectedTransferNetwork) {
      'Polygon' ||
      'BNB Smart Chain' ||
      'Ethereum (ERC-20)' => RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(hash),
      'TRON (TRC-20)' => RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash),
      'Solana' =>
        hash.length >= 80 &&
            hash.length <= 100 &&
            RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$').hasMatch(hash),
      _ => false,
    };
    if (!valid) {
      return 'Le format du hash ne correspond pas au réseau $_selectedTransferNetwork.';
    }
    return null;
  }

  Future<String?> _showTransferNetworkPicker(
    List<(String, String, String)> networks,
  ) async {
    final searchController = TextEditingController();
    var searchQuery = '';
    var pendingNetwork = _selectedTransferNetwork;

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredNetworks = networks
                .where(
                  (network) => network.$1.toLowerCase().contains(
                    searchQuery.trim().toLowerCase(),
                  ),
                )
                .toList();

            return Dialog(
              key: const ValueKey('transfer-network-picker-dialog'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 28,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFE).withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17233A).withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F7EE)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.currency_exchange_rounded,
                              color: Color(0xFF18A765),
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choisir un réseau',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sélectionnez le réseau du transfert.',
                                  style: TextStyle(color: _muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const ValueKey(
                              'transfer-network-picker-close',
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: _muted,
                            tooltip: 'Fermer',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        key: const ValueKey('transfer-network-search'),
                        controller: searchController,
                        onChanged: (value) =>
                            setDialogState(() => searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _muted,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F2FA),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E7F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: const BorderSide(
                              color: Color(0xFF18A765),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView.separated(
                          key: const ValueKey('transfer-network-options'),
                          padding: EdgeInsets.zero,
                          itemCount: filteredNetworks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final (network, networkKey, networkLogo) =
                                filteredNetworks[index];
                            final selected = network == pendingNetwork;
                            return Material(
                              color: selected
                                  ? const Color(0xFFE6F0FF)
                                  : const Color(0xFFF0F2FA),
                              borderRadius: BorderRadius.circular(17),
                              child: InkWell(
                                key: ValueKey(
                                  'transfer-network-option-$networkKey',
                                ),
                                borderRadius: BorderRadius.circular(17),
                                onTap: () => setDialogState(
                                  () => pendingNetwork = network,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF18A765)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipOval(
                                        child: Image.asset(
                                          networkLogo,
                                          key: ValueKey(
                                            'transfer-network-logo-$networkKey',
                                          ),
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          network,
                                          style: TextStyle(
                                            color: selected
                                                ? const Color(0xFF137C4B)
                                                : _ink,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF18A765),
                                          size: 21,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          key: const ValueKey(
                            'transfer-network-picker-confirm',
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(pendingNetwork),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Confirmer la sélection'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF18A765),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _submitTransferRequest() async {
    if (!(_transferFormKey.currentState?.validate() ?? false)) return;
    final isDeposit = _walletFlow == _WalletFlow.deposit;
    if (isDeposit &&
        !(_transactionHashFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!isDeposit &&
        !(_destinationAddressFieldKey.currentState?.validate() ?? false)) {
      return;
    }
    final amount = double.parse(
      _transferAmountController.text.trim().replaceAll(',', '.'),
    );
    if (!isDeposit && !_kycRequirementMet) {
      await _showKycForm();
      return;
    }
    await _showReceiptConfirmation(isDeposit ? 'dépôt' : 'retrait');
    if (!mounted) return;
    if (isDeposit) {
      _openReceipt(
        operation: 'Demande de dépôt',
        amount: amount,
        details: [
          ('Type d’opération', 'Dépôt USDT'),
          ('Mode de paiement', 'USDT · $_selectedTransferNetwork'),
          ('Hash fourni', _transactionHashController.text.trim()),
        ],
        status: 'Non exécuté',
        notice:
            'Le hash a été saisi, mais Tamleek ne peut pas encore interroger '
            'la blockchain. Aucun dépôt n’a été transmis, confirmé ou crédité.',
        backgroundAsset: 'assets/cryptocurrencies.png',
        totalLabel: 'Montant demandé',
      );
      return;
    }
    _openReceipt(
      operation: 'Demande de retrait',
      amount: amount,
      details: [
        ('Type d’opération', 'Retrait USDT'),
        ('Mode de paiement', 'USDT · $_selectedTransferNetwork'),
        ('Adresse de destination', _destinationAddressController.text.trim()),
      ],
      status: 'Non exécuté',
      notice:
          'Le retrait n’a pas été transmis. Les transferts seront disponibles '
          'après la connexion du portefeuille Tamleek.',
      backgroundAsset: 'assets/cryptocurrencies.png',
      totalLabel: 'Montant demandé',
    );
  }

  Widget _buildHoldingsPage() {
    const categories = [
      'Tous les actifs',
      'REIT',
      'Crypto',
      'FPI',
      'Matières premières',
    ];
    final visibleHoldings = _demoHoldings.where(
      (holding) =>
          _selectedHoldingCategory == 'Tous les actifs' ||
          holding.category == _selectedHoldingCategory,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 112),
      children: [
        const Text(
          'Mes actifs',
          style: TextStyle(
            color: _ink,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Vos investissements détenus',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          key: const ValueKey('holdings-total-card'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF17233A), Color(0xFF314A70)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VALEUR DE MES ACTIFS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '\$4,200.00',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _holdingsAllocationCard(),
        const SizedBox(height: 24),
        const Text(
          'Positions détenues',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: const ValueKey('holdings-category-dropdown'),
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              final category = await _showHoldingCategoryPicker(categories);
              if (category != null && mounted) {
                setState(() => _selectedHoldingCategory = category);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE1E4EA)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedHoldingCategory,
                      key: const ValueKey('holdings-category-selected'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: _ink),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final holding in visibleHoldings) _holdingCard(holding),
      ],
    );
  }

  Future<String?> _showHoldingCategoryPicker(List<String> categories) async {
    final searchController = TextEditingController();
    var searchQuery = '';
    var pendingSelection = _selectedHoldingCategory;

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCategories = categories
                .where(
                  (category) => category.toLowerCase().contains(
                    searchQuery.trim().toLowerCase(),
                  ),
                )
                .toList();

            return Dialog(
              key: const ValueKey('holdings-category-picker-dialog'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 28,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  height: MediaQuery.sizeOf(context).height * 0.78,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFE).withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17233A).withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F7EE)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.pie_chart_outline_rounded,
                              color: Color(0xFF18A765),
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choisir une catégorie',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Filtrez vos positions détenues.',
                                  style: TextStyle(color: _muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const ValueKey(
                              'holdings-category-picker-close',
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: _muted,
                            tooltip: 'Fermer',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        key: const ValueKey('holdings-category-search'),
                        controller: searchController,
                        onChanged: (value) =>
                            setDialogState(() => searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _muted,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F2FA),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E7F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: const BorderSide(
                              color: Color(0xFF18A765),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView.separated(
                          key: const ValueKey('holdings-category-options'),
                          padding: EdgeInsets.zero,
                          itemCount: filteredCategories.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final category = filteredCategories[index];
                            final selected = category == pendingSelection;
                            final optionKey = category.toLowerCase().replaceAll(
                              ' ',
                              '-',
                            );
                            return Material(
                              color: selected
                                  ? const Color(0xFFE6F0FF)
                                  : const Color(0xFFF0F2FA),
                              borderRadius: BorderRadius.circular(17),
                              child: InkWell(
                                key: ValueKey(
                                  'holdings-category-option-$optionKey',
                                ),
                                borderRadius: BorderRadius.circular(17),
                                onTap: () => setDialogState(
                                  () => pendingSelection = category,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF18A765)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _holdingCategoryIcon(category),
                                        color: selected
                                            ? const Color(0xFF18A765)
                                            : const Color(0xFF63718A),
                                        size: 21,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            color: selected
                                                ? const Color(0xFF137C4B)
                                                : _ink,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF18A765),
                                          size: 21,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          key: const ValueKey(
                            'holdings-category-picker-confirm',
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(pendingSelection),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Confirmer la sélection'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF18A765),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  IconData _holdingCategoryIcon(String category) => switch (category) {
    'REIT' => Icons.apartment_rounded,
    'Crypto' => Icons.currency_bitcoin_rounded,
    'FPI' => Icons.show_chart_rounded,
    'Matières premières' => Icons.diamond_rounded,
    _ => Icons.pie_chart_outline_rounded,
  };

  Widget _holdingCard(_HoldingPosition holding) {
    final pnlColor = holding.pnl >= 0
        ? const Color(0xFF168653)
        : const Color(0xFFD34848);
    final pnlSign = holding.pnl >= 0 ? '+' : '-';
    final title = holding.category == 'Matières premières'
        ? holding.category
        : holding.name;
    final subtitle = holding.category == 'Matières premières'
        ? holding.quantity
        : '${holding.category} · ${holding.quantity}';
    return Container(
      key: ValueKey('holding-position-${holding.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _selectedHoldingDetail = holding),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7EAF0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: holding.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(holding.icon, color: holding.color, size: 22),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${holding.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: holding.color,
                          size: 19,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Acheté le ${holding.purchaseDate}',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ),
                    Text(
                      '$pnlSign\$${holding.pnl.abs().toStringAsFixed(2)}  '
                      '($pnlSign${holding.pnlPercent.abs().toStringAsFixed(1)}%)',
                      key: ValueKey('holding-pnl-${holding.id}'),
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoldingDetail(_HoldingPosition holding) {
    final pnlSign = holding.pnl >= 0 ? '+' : '-';
    final pnlColor = holding.pnl >= 0
        ? const Color(0xFFB8F5D1)
        : const Color(0xFFFFB3B3);
    final metrics = [
      (
        'Valeur en dollars',
        '\$${holding.value.toStringAsFixed(2)}',
        Colors.white,
      ),
      (
        'Part du portefeuille',
        '${holding.portfolioShare.toStringAsFixed(1)}%',
        Colors.white,
      ),
      ('Date d’achat', holding.purchaseDate, Colors.white),
      ('Parts / quantité', holding.quantity, Colors.white),
      ('PNL', '$pnlSign\$${holding.pnl.abs().toStringAsFixed(2)}', pnlColor),
      (
        'Performance',
        '$pnlSign${holding.pnlPercent.abs().toStringAsFixed(1)}%',
        pnlColor,
      ),
    ];

    return ListView(
      key: ValueKey('holding-detail-page-${holding.id}'),
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('holding-detail-back'),
              onPressed: () => setState(() => _selectedHoldingDetail = null),
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
              tooltip: 'Retour à mes actifs',
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Détail de position',
                style: TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('holding-detail-summary'),
          padding: const EdgeInsets.all(18),
          decoration: _holdingDetailDecoration(),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(holding.icon, color: Colors.white, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      holding.category,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('holding-detail-metrics'),
          padding: const EdgeInsets.all(14),
          decoration: _holdingDetailDecoration(),
          child: Column(
            children: [
              for (var index = 0; index < metrics.length; index += 2) ...[
                if (index > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _holdingMetric(
                        metrics[index].$1,
                        metrics[index].$2,
                        metrics[index].$3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _holdingMetric(
                        metrics[index + 1].$1,
                        metrics[index + 1].$2,
                        metrics[index + 1].$3,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('holding-detail-monthly-history'),
          padding: const EdgeInsets.all(16),
          decoration: _holdingDetailDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historique mensuel des gains',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Variation mensuelle indicative en dollars',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 112,
                width: double.infinity,
                child: CustomPaint(
                  key: const ValueKey('holding-monthly-history-chart'),
                  painter: _MonthlyPnlPainter(
                    values: holding.monthlyHistory,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final point in holding.monthlyHistory)
                    Expanded(
                      child: Text(
                        point.$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('holding-detail-annual-history'),
          padding: const EdgeInsets.all(16),
          decoration: _holdingDetailDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historique annuel des gains',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final (year, gain) in holding.annualHistory)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          year,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${gain >= 0 ? '+' : '-'}\$${gain.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: gain >= 0
                              ? const Color(0xFFB8F5D1)
                              : const Color(0xFFFFB3B3),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: 12, color: Colors.white.withValues(alpha: 0.3)),
              const Text(
                'Valeurs de démonstration, non actualisées et non contractuelles.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _holdingDetailDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF17233A), Color(0xFF314A70)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
    );
  }

  Widget _holdingMetric(String label, String value, Color valueColor) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _holdingsAllocationCard() {
    const allocations = [
      (label: 'REIT', share: 0.43, color: Color(0xFF3769C8)),
      (label: 'Crypto', share: 0.30, color: Color(0xFFF49A17)),
      (label: 'FPI', share: 0.18, color: Color(0xFF188A58)),
      (label: 'Matières premières', share: 0.09, color: Color(0xFFBD8117)),
    ];

    return Container(
      key: const ValueKey('holdings-allocation-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF202943).withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition des actifs',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      key: const ValueKey('holdings-allocation-donut'),
                      size: const Size.square(76),
                      painter: const _AllocationDonutPainter([
                        (0.43, Color(0xFF3769C8)),
                        (0.30, Color(0xFFF49A17)),
                        (0.18, Color(0xFF188A58)),
                        (0.09, Color(0xFFBD8117)),
                      ]),
                    ),
                    const Text(
                      '\$4.2k',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Votre portefeuille est réparti sur 4 catégories.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              key: const ValueKey('holdings-allocation-bar'),
              height: 14,
              child: Row(
                children: [
                  for (final allocation in allocations)
                    Expanded(
                      flex: (allocation.share * 100).round(),
                      child: ColoredBox(color: allocation.color),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              for (final allocation in allocations)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: allocation.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${allocation.label} ${(allocation.share * 100).round()}%',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletBalanceCard({
    required Key key,
    required String title,
    required String amount,
    required Color background,
    required Color foreground,
    IconData? icon,
    Color iconColor = Colors.white,
    bool currencySelector = false,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (currencySelector)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.attach_money_rounded,
                        color: foreground,
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'USD',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: foreground,
                        size: 16,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            amount,
            style: TextStyle(
              color: foreground,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      key: ValueKey(
        'wallet-${label == 'Déposer' ? 'deposit' : 'withdraw'}-action',
      ),
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _walletActivity({
    required String key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String amount,
    required bool positive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          key: ValueKey(key),
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: TextStyle(
                    color: positive ? const Color(0xFF188A58) : _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 112),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _tr('Notifications', 'Notifications'),
                style: TextStyle(
                  color: _ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('notifications-mark-all-read'),
              onPressed: () {
                setState(() => _notificationsRead = true);
                _showSuccessConfirmation(
                  title: _tr('C’est fait !', 'Done!'),
                  message: _tr(
                    'Toutes vos notifications sont marquées comme lues.',
                    'All your notifications are marked as read.',
                  ),
                );
              },
              child: Text(
                _tr('Tout marquer comme lu', 'Mark all as read'),
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          _tr(
            'Restez informé de vos investissements',
            'Stay informed about your investments',
          ),
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Text(
          _tr('AUJOURD’HUI', 'TODAY'),
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        _notificationCard(
          title: _tr(
            'Votre portefeuille est à jour',
            'Your portfolio is up to date',
          ),
          message: _tr(
            'Consultez le solde de vos investissements.',
            'Check your investment balance.',
          ),
          time: _tr('Il y a 10 min', '10 min ago'),
          unread: !_notificationsRead,
        ),
        _notificationCard(
          title: _tr('Suivez le marché crypto', 'Follow the crypto market'),
          message: _tr(
            'Les dernières tendances Bitcoin sont disponibles.',
            'The latest Bitcoin trends are available.',
          ),
          time: _tr('Il y a 2 h', '2 hours ago'),
          unread: !_notificationsRead,
        ),
        const SizedBox(height: 18),
        Text(
          _tr('PLUS TÔT', 'EARLIER'),
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        _notificationCard(
          title: _tr('Bienvenue sur Tamleek', 'Welcome to Tamleek'),
          message: _tr(
            'Explorez REIT, FPI et autres opportunités.',
            'Explore REIT, FPI, and other opportunities.',
          ),
          time: _tr('12 nov. 2026', 'Nov 12, 2026'),
          unread: false,
        ),
      ],
    );
  }

  Future<void> _showProfileEditor(_ProfileField field) async {
    final controller = switch (field) {
      _ProfileField.name => _profileNameController,
      _ProfileField.phone => _profilePhoneController,
    };
    controller.text = switch (field) {
      _ProfileField.name => _profileName,
      _ProfileField.phone => _profilePhone,
    };
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: _page,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _profileFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5D9E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      switch (field) {
                        _ProfileField.name => 'Modifier le nom complet',
                        _ProfileField.phone => 'Modifier le téléphone',
                      },
                      style: TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      TamleekSupabaseOptions.isConfigured
                          ? 'Cette information est synchronisée avec votre '
                                'profil Supabase et enregistrée sur cet appareil.'
                          : 'Cette information est enregistrée sur cet appareil.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    switch (field) {
                      _ProfileField.name => _profileEditField(
                        key: const ValueKey('profile-name-input'),
                        controller: controller,
                        label: 'Nom complet',
                        icon: Icons.badge_outlined,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if ((value ?? '').trim().length < 2) {
                            return 'Saisissez au moins deux caractères.';
                          }
                          return null;
                        },
                      ),
                      _ProfileField.phone => _profileEditField(
                        key: const ValueKey('profile-phone-input'),
                        controller: controller,
                        label: 'Téléphone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          final phone = (value ?? '').trim();
                          if (phone.isNotEmpty &&
                              !RegExp(r'^\+?[0-9\s()-]{8,18}$')
                                  .hasMatch(phone)) {
                            return 'Saisissez un numéro valide.';
                          }
                          return null;
                        },
                      ),
                    },
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('profile-save-button'),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!(_profileFormKey.currentState
                                        ?.validate() ??
                                    false)) {
                                  return;
                                }
                                setModalState(() => saving = true);
                                late final bool saved;
                                final preferenceKey = switch (field) {
                                  _ProfileField.name => _profileNameKey,
                                  _ProfileField.phone => _profilePhoneKey,
                                };
                                final value = controller.text.trim();
                                try {
                                  final user =
                                      TamleekSupabaseOptions.isConfigured
                                      ? Supabase
                                            .instance
                                            .client
                                            .auth
                                            .currentUser
                                      : null;
                                  if (user != null) {
                                    await Supabase.instance.client
                                        .from('profiles')
                                        .update({
                                          field == _ProfileField.name
                                                  ? 'name'
                                                  : 'phone':
                                              value,
                                          'updated_at': DateTime.now()
                                              .toUtc()
                                              .toIso8601String(),
                                        })
                                        .eq('id', user.id)
                                        .select('id')
                                        .single();
                                  }
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  saved = await preferences.setString(
                                    preferenceKey,
                                    value,
                                  );
                                } on PlatformException catch (error) {
                                  if (sheetContext.mounted) {
                                    setModalState(() => saving = false);
                                  }
                                  if (mounted) {
                                    await _showMessage(
                                      'Les informations n’ont pas pu être '
                                      'enregistrées. ${error.message ?? ''}',
                                    );
                                  }
                                  return;
                                } on PostgrestException catch (error) {
                                  if (sheetContext.mounted) {
                                    setModalState(() => saving = false);
                                  }
                                  if (mounted) {
                                    await _showMessage(
                                      'Le profil Supabase n’a pas pu être '
                                      'enregistré. ${error.message}',
                                    );
                                  }
                                  return;
                                }
                                if (!saved) {
                                  setModalState(() => saving = false);
                                  await _showMessage(
                                    'Les informations n’ont pas pu être '
                                    'enregistrées. Réessayez.',
                                  );
                                  return;
                                }
                                if (!mounted) return;
                                setState(() {
                                  switch (field) {
                                    case _ProfileField.name:
                                      _profileName = value;
                                      break;
                                    case _ProfileField.phone:
                                      _profilePhone = value;
                                      break;
                                  }
                                });
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                await _showSuccessConfirmation(
                                  title: 'Profil mis à jour',
                                  message: TamleekSupabaseOptions.isConfigured
                                      ? 'Vos informations ont été synchronisées '
                                            'avec Supabase et enregistrées sur '
                                            'cet appareil.'
                                      : 'Vos informations ont été enregistrées '
                                            'sur cet appareil.',
                                );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF314A70),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Enregistrer',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileEditField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF314A70)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE1E5ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE1E5ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF314A70), width: 1.4),
        ),
      ),
    );
  }

  Future<void> _showProfilePhotoOptions() async {
    final action = await showModalBottomSheet<_ProfilePhotoAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('profile-photo-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir une photo'),
              onTap: () =>
                  Navigator.of(context).pop(_ProfilePhotoAction.choose),
            ),
            if (_profilePhotoPath != null)
              ListTile(
                key: const ValueKey('profile-photo-remove'),
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Supprimer la photo'),
                onTap: () =>
                    Navigator.of(context).pop(_ProfilePhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == _ProfilePhotoAction.remove) {
      await _removeProfilePhoto();
    } else {
      await _pickProfilePhoto();
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final selectedPhoto = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (selectedPhoto == null) return;

      final appDirectory = await getApplicationDocumentsDirectory();
      final profileDirectory = Directory(
        '${appDirectory.path}${Platform.pathSeparator}profile',
      );
      await profileDirectory.create(recursive: true);
      final photoFile = File(
        '${profileDirectory.path}${Platform.pathSeparator}avatar.jpg',
      );
      await photoFile.writeAsBytes(
        await File(selectedPhoto.path).readAsBytes(),
        flush: true,
      );
      await FileImage(photoFile).evict();

      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _profilePhotoKey,
        photoFile.path,
      );
      if (!saved) {
        await _showMessage('La photo n’a pas pu être enregistrée.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _profilePhotoPath = photoFile.path;
        _profileLoadError = null;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage(
          'La galerie photo est indisponible. '
          '${error.message ?? 'Vérifiez les autorisations de l’appareil.'}',
        );
      }
    } on FileSystemException {
      if (mounted) {
        await _showMessage(
          'La photo n’a pas pu être copiée dans le stockage de l’application.',
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final photoPath = _profilePhotoPath;
      final removed = await preferences.remove(_profilePhotoKey);
      if (!removed) {
        await _showMessage('La photo de profil n’a pas pu être supprimée.');
        return;
      }
      if (!mounted) return;
      setState(() => _profilePhotoPath = null);
      if (photoPath != null) {
        final photoFile = File(photoPath);
        if (await photoFile.exists()) await photoFile.delete();
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage(
          'La photo de profil n’a pas pu être supprimée. '
          '${error.message ?? ''}',
        );
      }
    } on FileSystemException {
      if (mounted) {
        await _showMessage(
          'La photo a été retirée du profil, mais son fichier local n’a pas pu '
          'être supprimé.',
        );
      }
    }
  }

  Future<void> _composeSupportEmail() async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: _tamleekSupportEmail,
      queryParameters: {
        'subject': _tr('Assistance Tamleek', 'Tamleek support'),
        'body': [
          _tr('Bonjour,', 'Hello,'),
          '',
          '${_tr('Nom', 'Name')} : '
              '${_profileName.isEmpty ? _tr('Non renseigné', 'Not provided') : _profileName}',
          '${_tr('Adresse e-mail', 'Email address')} : '
              '${_profileEmail.isEmpty ? _tr('Non renseignée', 'Not provided') : _profileEmail}',
          '',
          _tr('Votre message :', 'Your message:'),
        ].join('\n'),
      },
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await _showMessage(
          'Aucune application de messagerie n’est disponible sur cet appareil.',
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage(
          'L’application de messagerie n’a pas pu être ouverte. '
          '${error.message ?? ''}',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        await _showMessage(
          'L’ouverture des e-mails n’est pas disponible sur cet appareil.',
        );
      }
    }
  }

  Future<void> _openExternalLink(String url) async {
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await _showMessage('Le lien n’a pas pu être ouvert.');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage(
          'Le lien n’a pas pu être ouvert. ${error.message ?? ''}',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        await _showMessage('L’ouverture des liens n’est pas disponible.');
      }
    }
  }

  Widget _buildSupportEmailPage() {
    return ListView(
      key: const ValueKey('support-email-page'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('support-email-back'),
              onPressed: () => setState(() => _showSupportEmail = false),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: _tr('Retour au profil', 'Back to profile'),
            ),
            Expanded(
              child: Text(
                _tr('Support par e-mail', 'Email support'),
                style: TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFE9EFF8),
                child: Icon(
                  Icons.email_outlined,
                  color: Color(0xFF314A70),
                  size: 31,
                ),
              ),
              SizedBox(height: 14),
              Text(
                _tr(
                  'Contactez l’assistance Tamleek',
                  'Contact Tamleek support',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _tr(
                  'Un brouillon sera préparé dans votre application de '
                      'messagerie, avec l’adresse et les informations de votre '
                      'profil.',
                  'A draft will be prepared in your email app with your '
                      'address and profile information.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('support-email-address-card'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                color: Color(0xFF314A70),
                size: 19,
              ),
              SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  _tamleekSupportEmail,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            key: const ValueKey('support-email-compose'),
            onPressed: _composeSupportEmail,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(
              _tr('Ouvrir mon application e-mail', 'Open my email app'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF17233A),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorizationPage() {
    return ListView(
      key: const ValueKey('authorization-page'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('authorization-back'),
              onPressed: () => setState(() => _showAuthorizationPage = false),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: _tr('Retour au profil', 'Back to profile'),
            ),
            Expanded(
              child: Text(
                _tr('Autorisation', 'Authorization'),
                style: TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            _tr('Licence commerciale de Tamleek', 'Tamleek business license'),
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          key: const ValueKey('authorization-license-frame'),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8A824), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF17233A).withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.asset(
                'assets/tamleek_trade_license.png',
                key: const ValueKey('authorization-license-image'),
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _profileInfoCard(
          icon: Icons.business_rounded,
          label: _tr('Entreprise', 'Company'),
          value: 'Tamleek Real Estate Registration Trustee LLC DWC-Branch',
        ),
        _profileInfoCard(
          icon: Icons.confirmation_number_outlined,
          label: _tr('Numéro de licence', 'License number'),
          value: _tr('7770 · Commerciale', '7770 · Commercial'),
        ),
        _profileInfoCard(
          icon: Icons.verified_outlined,
          label: _tr('Statut', 'Status'),
          value: 'Active',
        ),
        _profileInfoCard(
          icon: Icons.event_available_outlined,
          label: _tr('Date d’expiration', 'Expiration date'),
          value: _tr('31 décembre 2035', 'December 31, 2035'),
        ),
        const SizedBox(height: 6),
        Text(
          _tr(
            'Licence affichée à partir du document fourni.',
            'License displayed from the document provided.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildHelpInfoPage() {
    return ListView(
      key: const ValueKey('help-info-page'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('help-info-back'),
              onPressed: () => setState(() => _showHelpInfoPage = false),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: _tr('Retour au profil', 'Back to profile'),
            ),
            Expanded(
              child: Text(
                _tr('Aide et informations', 'Help and information'),
                style: TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('help-founder-photo-card'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8A824), width: 2),
          ),
          child: Column(
            children: [
              Container(
                width: 106,
                height: 106,
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFFD8A824), width: 2),
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/tamleek_founder.png',
                    key: ValueKey('help-founder-photo'),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 10),
              Text(
                _tr('Fondateur de Tamleek', 'Founder of Tamleek'),
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _tr('L’HISTOIRE DE TAMLEEK', 'THE STORY OF TAMLEEK'),
          style: TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _helpStoryCard(
          _tr(
            'Fondée à la mi-2018, Tamleek REIT & Global Investments est issue '
                'de Tamleek Real Estate Co., une société reconnue pour son '
                'parcours et son portefeuille immobilier mondial.',
            'Founded in mid-2018, Tamleek REIT & Global Investments grew out '
                'of Tamleek Real Estate Co., a company recognized for its '
                'track record and global real estate portfolio.',
          ),
        ),
        _helpStoryCard(
          _tr(
            'Fondée en 2015, Tamleek Real Estate Co. s’est spécialisée dans le '
                'courtage immobilier et le conseil en investissement. En moins '
                'd’un an sur le marché immobilier des Émirats arabes unis, '
                'l’entreprise a vendu pour plus de 2 milliards AED de biens '
                'immobiliers et a remporté deux prix Forbes consécutifs de '
                'meilleure société de conseil en investissement et de courtage '
                'du monde arabe.',
            'Founded in 2015, Tamleek Real Estate Co. specialized in real '
                'estate brokerage and investment consulting. In less than a '
                'year in the UAE real estate market, it sold over AED 2 '
                'billion in property and won two consecutive Forbes awards '
                'for the best investment consultancy and brokerage firm in '
                'the Arab world.',
          ),
        ),
        _helpStoryCard(
          _tr(
            'Tamleek est devenue une entité de vente exclusive pour de nombreux '
                'clients prestigieux. Le groupe propose des services internes '
                'et un portefeuille d’activités couvrant l’investissement, le '
                'développement, la distribution et le commerce électronique.',
            'Tamleek became an exclusive sales partner for many prestigious '
                'clients. The group offers in-house services and a portfolio '
                'covering investment, development, distribution, and '
                'e-commerce.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tr('NOS CINQ PILIERS', 'OUR FIVE PILLARS'),
          style: TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        for (final (icon, frenchTitle, englishTitle) in [
          (Icons.apartment_rounded, 'REIT', 'REIT'),
          (
            Icons.domain_add_rounded,
            'Développement de luxe',
            'Luxury development',
          ),
          (
            Icons.currency_bitcoin_rounded,
            'Cryptomonnaies',
            'Cryptocurrencies',
          ),
          (
            Icons.trending_up_rounded,
            'Investissements généraux',
            'General investments',
          ),
          (
            Icons.handshake_outlined,
            'Conseil en investissement et courtage',
            'Investment consulting and brokerage',
          ),
        ])
          Container(
            key: ValueKey('help-pillar-$frenchTitle'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF314A70), size: 20),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    _tr(frenchTitle, englishTitle),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _helpStoryCard(
          _tr(
            'Tamleek sélectionne avec soin les actifs et projets dans lesquels '
                'elle investit. L’entreprise poursuit son développement et son '
                'expansion sur la scène mondiale.',
            'Tamleek carefully selects the assets and projects it invests in '
                'and continues to grow and expand on the global stage.',
          ),
        ),
      ],
    );
  }

  Widget _helpStoryCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _ink, fontSize: 13, height: 1.55),
      ),
    );
  }

  Widget _buildProfilePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        Text(
          _tr('Mon profil', 'My profile'),
          style: TextStyle(
            color: _ink,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _tr('Découvrez votre espace Tamleek', 'Discover your Tamleek space'),
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Container(
          key: const ValueKey('profile-summary-card'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF17233A), Color(0xFF314A70)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              InkWell(
                key: const ValueKey('profile-avatar-button'),
                onTap: _showProfilePhotoOptions,
                customBorder: const CircleBorder(),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 31,
                      backgroundColor: const Color(0xFF76513F),
                      backgroundImage: _profilePhotoPath == null
                          ? null
                          : FileImage(File(_profilePhotoPath!)),
                      child: _profilePhotoPath == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 35,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF08B9EA),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ),
                    if (_kycRequirementMet)
                      Positioned(
                        key: const ValueKey('kyc-verified-badge'),
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 21,
                          height: 21,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E9B50),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileName.isEmpty
                          ? _tr('Membre Tamleek', 'Tamleek member')
                          : _profileName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profileEmail.isEmpty
                          ? _tr(
                              'Complétez vos informations',
                              'Complete your information',
                            )
                          : _profileEmail,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_profileLoadError != null) ...[
          const SizedBox(height: 10),
          Text(
            _profileLoadError!,
            key: const ValueKey('profile-load-error'),
            style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          _tr('MES INFORMATIONS', 'MY INFORMATION'),
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _profileInfoCard(
          icon: Icons.badge_outlined,
          label: _tr('Nom complet', 'Full name'),
          value: _profileName.isEmpty
              ? _tr('À renseigner', 'Not provided')
              : _profileName,
          onTap: () => _showProfileEditor(_ProfileField.name),
          showEditIcon: true,
        ),
        _profileInfoCard(
          icon: Icons.email_outlined,
          label: _tr('Adresse e-mail', 'Email address'),
          value: _profileEmail.isEmpty
              ? _tr('À renseigner', 'Not provided')
              : _profileEmail,
        ),
        _profileInfoCard(
          icon: Icons.phone_outlined,
          label: _tr('Téléphone', 'Phone'),
          value: _profilePhone.isEmpty
              ? _tr('À renseigner', 'Not provided')
              : _profilePhone,
          onTap: () => _showProfileEditor(_ProfileField.phone),
          showEditIcon: true,
        ),
        _profileInfoCard(
          key: const ValueKey('profile-kyc-status'),
          icon: Icons.verified_user_outlined,
          label: _tr('Vérification KYC', 'KYC verification'),
          value: _kycRequirementMet
              ? _tr('Vérifié', 'Verified')
              : _kycVerificationStatus == 'pending'
              ? _tr('En attente de validation', 'Pending review')
              : _tr('Non vérifié', 'Not verified'),
          onTap: _showKycInformation,
        ),
        const SizedBox(height: 18),
        const SizedBox(height: 22),
        Text(
          _tr('CANAUX OFFICIELS', 'OFFICIAL CHANNELS'),
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _profileInfoCard(
          icon: Icons.language_rounded,
          label: _tr('Site internet', 'Official website'),
          value: 'www.tamleek.ae',
          onTap: () => _openExternalLink(_tamleekWebsiteUrl),
        ),
        _profileInfoCard(
          icon: Icons.ondemand_video_rounded,
          label: 'YouTube',
          value: '@tamleekrealestateco5031',
          onTap: () => _openExternalLink(_tamleekYouTubeUrl),
        ),
        _profileInfoCard(
          icon: Icons.facebook_rounded,
          label: 'Facebook',
          value: _tr('Page officielle de Tamleek', 'Official Tamleek page'),
          onTap: () => _openExternalLink(_tamleekFacebookUrl),
        ),
        const SizedBox(height: 22),
        Text(
          _tr('CENTRE', 'CENTRE'),
          key: ValueKey('profile-center'),
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _profileInfoCard(
          key: const ValueKey('profile-language'),
          icon: Icons.language_rounded,
          label: _tr('Langue', 'Language'),
          value: _isEnglish ? 'English' : 'Français',
          onTap: _showLanguagePicker,
        ),
        _profileInfoCard(
          icon: Icons.notifications_active_outlined,
          label: _tr('Mes notifications', 'My notifications'),
          value: _tr(
            'Consultez les informations de votre application.',
            'View updates about your app.',
          ),
          onTap: () => setState(() {
            _selectedNavigation = 4;
            _showSupportEmail = false;
            _showAuthorizationPage = false;
            _showHelpInfoPage = false;
          }),
        ),
        _profileInfoCard(
          icon: Icons.email_outlined,
          label: _tr('Support par e-mail', 'Email support'),
          value: _tr(
            'Contactez l’assistance Tamleek par e-mail.',
            'Contact Tamleek support by email.',
          ),
          onTap: () => setState(() {
            _showSupportEmail = true;
            _showAuthorizationPage = false;
            _showHelpInfoPage = false;
          }),
        ),
        _profileInfoCard(
          icon: Icons.help_outline_rounded,
          label: _tr('Aide et informations', 'Help and information'),
          value: _tr(
            'Découvrez l’histoire et les activités de Tamleek.',
            'Discover Tamleek’s history and activities.',
          ),
          onTap: () => setState(() {
            _showHelpInfoPage = true;
            _showSupportEmail = false;
            _showAuthorizationPage = false;
          }),
        ),
        _profileInfoCard(
          icon: Icons.verified_user_outlined,
          label: _tr('Autorisation', 'Authorization'),
          value: _tr(
            'Consultez la licence commerciale de Tamleek.',
            'View Tamleek’s commercial license.',
          ),
          onTap: () => setState(() {
            _showAuthorizationPage = true;
            _showSupportEmail = false;
            _showHelpInfoPage = false;
          }),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            key: const ValueKey('profile-logout-button'),
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: Text(_tr('Se déconnecter', 'Log out')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
              side: const BorderSide(color: Color(0xFFB3261E)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileInfoCard({
    Key? key,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool showEditIcon = false,
  }) {
    final card = Container(
      key: key ?? ValueKey('profile-info-$label'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF314A70), size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (showEditIcon) ...[
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, color: Color(0xFF314A70), size: 17),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }

  Widget _notificationCard({
    required String title,
    required String message,
    required String time,
    required bool unread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: unread ? const Color(0xFFEBF0FA) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('notification-$title'),
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (unread) setState(() => _notificationsRead = true);
            _showAppFeedback(title: title, message: message, isSuccess: false);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/tamleek_notification_logo.jpg',
                    key: ValueKey('notification-logo-$title'),
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3769C8),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        time,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final items = [
      (Icons.home_outlined, _tr('Accueil', 'Home')),
      (Icons.account_balance_wallet_outlined, _tr('Portefeuille', 'Wallet')),
      (Icons.pie_chart_outline_rounded, _tr('Mes actifs', 'My assets')),
      (Icons.person_outline_rounded, _tr('Profil', 'Profile')),
    ];

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF202943).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final selected = _selectedNavigation == index;
          final (icon, label) = items[index];
          return Expanded(
            child: Center(
              child: Semantics(
                button: true,
                label: label,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    setState(() {
                      _selectedNavigation = index;
                      if (index != 3) {
                        _showSupportEmail = false;
                        _showAuthorizationPage = false;
                        _showHelpInfoPage = false;
                      }
                      if (index != 2) _selectedHoldingDetail = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: selected ? _ink : const Color(0xFFF7F8FC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: selected ? Colors.white : _ink,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _showFilters() async {
    final selected = await showModalBottomSheet<_FilterResult>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrer les actifs',
                style: TextStyle(
                  fontSize: 19,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _filterOption(context, 'Tous les actifs', null),
              _filterOption(context, 'REIT', InvestmentType.reit),
              _filterOption(context, 'Cryptomonnaies', InvestmentType.crypto),
              _filterOption(context, 'FPI', InvestmentType.fpi),
              _filterOption(context, 'Action', InvestmentType.action),
              _filterOption(
                context,
                'Matières premières',
                InvestmentType.commodity,
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedType = selected.type;
        _filterIsActive = true;
      });
    }
  }

  Widget _filterOption(
    BuildContext context,
    String label,
    InvestmentType? type,
  ) {
    final selected = _filterIsActive ? _selectedType == type : type == null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: _ink)),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? _ink : _muted,
      ),
      onTap: () => Navigator.pop(context, _FilterResult(type)),
    );
  }

  void _selectType(InvestmentType? type) {
    setState(() {
      _selectedType = _filterIsActive && _selectedType == type ? null : type;
      _filterIsActive = true;
    });
  }
}

class _FilterResult {
  const _FilterResult(this.type);

  final InvestmentType? type;
}

class SkylinePainter extends CustomPainter {
  const SkylinePainter({this.compact = false, this.variant = 0});

  final bool compact;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final baseColors = variant == 2
        ? const [Color(0xFFE2F6F2), Color(0xFFA8D6D1)]
        : const [Color(0xFFDCEBFF), Color(0xFF9CCBFF)];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: baseColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.16),
      size.height * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    final ground = size.height * 0.86;
    final buildings = compact
        ? <Rect>[
            Rect.fromLTWH(
              size.width * .03,
              ground - size.height * .44,
              size.width * .25,
              size.height * .44,
            ),
            Rect.fromLTWH(
              size.width * .28,
              ground - size.height * .67,
              size.width * .3,
              size.height * .67,
            ),
            Rect.fromLTWH(
              size.width * .59,
              ground - size.height * .48,
              size.width * .36,
              size.height * .48,
            ),
          ]
        : <Rect>[
            Rect.fromLTWH(
              size.width * .48,
              ground - size.height * .61,
              size.width * .17,
              size.height * .61,
            ),
            Rect.fromLTWH(
              size.width * .64,
              ground - size.height * .93,
              size.width * .2,
              size.height * .93,
            ),
            Rect.fromLTWH(
              size.width * .83,
              ground - size.height * .55,
              size.width * .15,
              size.height * .55,
            ),
            Rect.fromLTWH(
              size.width * .40,
              ground - size.height * .39,
              size.width * .11,
              size.height * .39,
            ),
          ];

    for (var index = 0; index < buildings.length; index++) {
      final building = buildings[index];
      final colors = index.isEven
          ? const [Color(0xFF0F527D), Color(0xFF50A5D2)]
          : const [Color(0xFF1D6A9B), Color(0xFF90D3EF)];
      final path = Path()
        ..moveTo(building.left, building.bottom)
        ..lineTo(building.left, building.top + building.width * .2)
        ..lineTo(building.left + building.width * .55, building.top)
        ..lineTo(building.right, building.top + building.width * .16)
        ..lineTo(building.right, building.bottom)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(building),
      );
      final windowPaint = Paint()..color = const Color(0xFFD5F2FF);
      final columns = compact ? 3 : 3;
      final rows = compact ? 5 : 8;
      for (var row = 0; row < rows; row++) {
        for (var column = 0; column < columns; column++) {
          final x = building.left + building.width * (0.17 + column * 0.23);
          final y = building.top + building.height * (0.15 + row * 0.095);
          if (y + building.height * .035 < building.bottom) {
            canvas.drawRect(
              Rect.fromLTWH(
                x,
                y,
                building.width * .075,
                building.height * .035,
              ),
              windowPaint,
            );
          }
        }
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(0, ground, size.width, size.height - ground),
      Paint()..color = const Color(0xFF6DAB66),
    );
    final treePaint = Paint()..color = const Color(0xFF368856);
    for (var index = 0; index < 7; index++) {
      final x = size.width * (0.05 + index * 0.14);
      canvas.drawCircle(Offset(x, ground), size.height * .055, treePaint);
      canvas.drawRect(
        Rect.fromLTWH(x - 1, ground, 2, size.height * .1),
        Paint()..color = const Color(0xFF735A42),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .96, size.width, size.height * .04),
      Paint()..color = const Color(0xFFCDD7DD),
    );
  }

  @override
  bool shouldRepaint(covariant SkylinePainter oldDelegate) =>
      compact != oldDelegate.compact || variant != oldDelegate.variant;
}

class BitcoinPainter extends CustomPainter {
  const BitcoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF432808), Color(0xFFE7A829), Color(0xFF6E3A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    for (var i = 0; i < 7; i++) {
      final x = size.width * (i / 6);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height * .55, size.height),
        Paint()..color = const Color(0xFFFFD56D).withValues(alpha: 0.17),
      );
    }
    final center = Offset(size.width * .51, size.height * .5);
    final radius = size.height * .39;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFE99B), Color(0xFFFFBD35), Color(0xFF9E5708)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * .81,
      Paint()
        ..color = const Color(0xFFFFD46A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final text = TextPainter(
      text: const TextSpan(
        text: '₿',
        style: TextStyle(
          color: Color(0xFF9B5B0A),
          fontSize: 38,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(center.dx - text.width / 2, center.dy - text.height / 2),
    );
    canvas.drawCircle(
      Offset(size.width * .8, size.height * .2),
      size.height * .045,
      Paint()..color = Colors.white.withValues(alpha: .75),
    );
  }

  @override
  bool shouldRepaint(covariant BitcoinPainter oldDelegate) => false;
}
