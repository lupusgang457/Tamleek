import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat, ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/gestures.dart';
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

bool _isConnectionFailure(Object error) {
  final message = error.toString().toLowerCase();
  return error is SocketException ||
      error is TimeoutException ||
      const [
        'failed host lookup',
        'network is unreachable',
        'network request failed',
        'connection refused',
        'connection reset',
        'connection closed',
        'connection timed out',
        'timed out',
        'xmlhttprequest error',
        'failed to fetch',
        'err_internet_disconnected',
        'no address associated with hostname',
      ].any(message.contains);
}

String _readableBackendError(
  Object error, {
  required String fallback,
  bool english = false,
}) {
  if (!_isConnectionFailure(error)) {
    return english
        ? 'This operation could not be completed. Please try again shortly.'
        : fallback;
  }
  return english
      ? 'No internet connection. Check your connection and try again.'
      : 'Connexion Internet indisponible. Vérifiez votre connexion puis réessayez.';
}

String? _walletFinancialErrorMessage(Object error, {required bool english}) {
  if (_isConnectionFailure(error)) return null;
  return _readableBackendError(
    error,
    fallback: english
        ? 'Transactions are temporarily unavailable.'
        : 'Les opérations sont temporairement indisponibles.',
    english: english,
  );
}

Uri _legalDocumentUri(String fileName) {
  final path = 'legal/$fileName';
  return kIsWeb
      ? Uri.base.resolve(path)
      : Uri.parse('https://lupusgang457.github.io/Tamleek/$path');
}

String _readableAuthError(
  AuthException error, {
  required String fallback,
  bool english = false,
}) {
  if (_isConnectionFailure(error)) {
    return english
        ? 'No internet connection. Check your connection and try again.'
        : 'Connexion Internet indisponible. Vérifiez votre connexion puis réessayez.';
  }
  final code = error.code?.toLowerCase();
  final message = error.message.toLowerCase();
  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
    return english
        ? 'The email or password is incorrect.'
        : 'Adresse e-mail ou mot de passe incorrect.';
  }
  if (code == 'email_not_confirmed') {
    return english
        ? 'Confirm your email address before signing in.'
        : 'Confirmez votre adresse e-mail avant de vous connecter.';
  }
  if (code == 'email_exists' || code == 'user_already_exists') {
    return english
        ? 'This email address is already in use.'
        : 'Cette adresse e-mail est déjà utilisée.';
  }
  if (code == 'weak_password') {
    return english
        ? 'Choose a stronger password.'
        : 'Choisissez un mot de passe plus sécurisé.';
  }
  return english
      ? 'This operation could not be completed. Please try again shortly.'
      : fallback;
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
        _error = _readableAuthError(
          error,
          fallback: 'Le mot de passe n’a pas pu être modifié. Vérifiez le lien puis réessayez.',
        );
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
const _registrationCompleteKey = 'tamleek.registration.complete';
const _profileNameKey = 'tamleek.profile.name';
const _profileEmailKey = 'tamleek.profile.email';
const _profilePhoneKey = 'tamleek.profile.phone';
const _profilePhotoKey = 'tamleek.profile.photo';
const _languagePreferenceKey = 'tamleek.language';
const _tamleekSupportEmail = 'tamleek.contact@gmail.com';
const _tamleekWebsiteUrl = 'https://www.tamleek.ae/';
const _tamleekShareUrl = 'https://lupusgang457.github.io/Tamleek/';
const _tamleekFacebookUrl = 'https://www.facebook.com/share/19zxueAV7K/';
const _tamleekYouTubeUrl =
    'https://youtube.com/@tamleekrealestateco5031?si=coJCsHz5c0GJH_q7';
String get _supabaseAuthRedirectUrl {
  if (!kIsWeb) return 'tamleek://login-callback/';
  final uri = Uri.base;
  final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
  return '${uri.origin}$path';
}

class TamleekApp extends StatelessWidget {
  const TamleekApp({super.key});

  @visibleForTesting
  const TamleekApp.forTesting({super.key});

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

class _DepositQrUnavailable extends StatelessWidget {
  const _DepositQrUnavailable();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('transfer-deposit-qr'),
    width: 156,
    height: 156,
    color: const Color(0xFFF5F6F8),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_2_rounded, color: Color(0xFF98A2B3), size: 42),
        SizedBox(height: 8),
        Text(
          'QR indisponible',
          style: TextStyle(color: Color(0xFF667085), fontSize: 11),
        ),
      ],
    ),
  );
}

class _RegistrationGate extends StatefulWidget {
  const _RegistrationGate();

  @override
  State<_RegistrationGate> createState() => _RegistrationGateState();
}

class _RegistrationGateState extends State<_RegistrationGate> {
  late final Future<bool> _registrationStatus;
  bool _continueToRegistrationAfterAuthError = false;

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
          if (snapshot.hasError && !_continueToRegistrationAfterAuthError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'La session n’a pas pu être vérifiée. Vérifiez votre '
                        'connexion Internet puis réessayez. Si le problème '
                        'persiste après avoir ouvert un lien de confirmation, '
                        'demandez un nouveau lien et utilisez le plus récent.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        key: ValueKey('auth-session-error-continue'),
                        onPressed: () => setState(
                          () => _continueToRegistrationAfterAuthError = true,
                        ),
                        child: const Text('Retour à la connexion'),
                      ),
                    ],
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
  late final TapGestureRecognizer _termsLinkRecognizer = TapGestureRecognizer()
    ..onTap = _openTermsOfUse;
  late final TapGestureRecognizer _privacyLinkRecognizer =
      TapGestureRecognizer()..onTap = _openPrivacyPolicy;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsLinkRecognizer.dispose();
    _privacyLinkRecognizer.dispose();
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
        _registrationError = _readableAuthError(
          error,
          fallback: 'La création du compte a échoué. Vérifiez les informations puis réessayez.',
        );
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _registrationError = _readableBackendError(
          error,
          fallback: 'Le profil n’a pas pu être enregistré. Réessayez dans quelques instants.',
        );
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

  Future<void> _openLegalDocument({
    required String fileName,
    required String title,
  }) async {
    try {
      final launched = await launchUrl(
        _legalDocumentUri(fileName),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await _showNotice(
          'Document indisponible',
          '$title n’a pas pu être ouvert.',
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _showNotice(
          'Document indisponible',
          '$title n’a pas pu être ouvert. ${error.message ?? ''}',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        await _showNotice(
          'Document indisponible',
          'L’ouverture des documents n’est pas disponible sur cet appareil.',
        );
      }
    }
  }

  Future<void> _openTermsOfUse() => _openLegalDocument(
    fileName: 'conditions-utilisation.pdf',
    title: 'Les Conditions d’utilisation',
  );

  Future<void> _openPrivacyPolicy() => _openLegalDocument(
    fileName: 'politique-confidentialite.pdf',
    title: 'La Politique de confidentialité',
  );

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
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text.rich(
                                key: const ValueKey('signup-terms-consent'),
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
                                      recognizer: _termsLinkRecognizer,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF314A70),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    TextSpan(text: ' et la '),
                                    TextSpan(
                                      text: 'Politique de confidentialité.',
                                      recognizer: _privacyLinkRecognizer,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF314A70),
                                        decoration: TextDecoration.underline,
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
                      Text(
                        TamleekSupabaseOptions.isConfigured
                            ? 'Votre compte sera enregistré dans Supabase.'
                            : 'Votre profil sera enregistré sur cet appareil.',
                        style: TextStyle(
                          color: Color(0xFF737780),
                          fontSize: 11,
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
          _readableAuthError(
            error,
            fallback: 'La connexion a échoué. Vérifiez vos identifiants puis réessayez.',
          ),
        );
      } on PostgrestException catch (error) {
        if (!mounted) return;
        await _showNotice(
          'Connexion impossible',
          _readableBackendError(
            error,
            fallback: 'Le service de connexion est momentanément indisponible. Réessayez plus tard.',
          ),
        );
      }
      return;
    }
    _showNotice(
      'Connexion indisponible',
      'Cette version n’a pas reçu la configuration Supabase. Dans VS Code, '
          'lancez « Tamleek (Supabase) » ou utilisez '
          '`flutter run --dart-define-from-file=supabase_config.json`. '
          'Aucun mot de passe n’est enregistré tant que la connexion sécurisée '
          'n’est pas disponible.',
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
        _readableAuthError(
          error,
          fallback: 'Le lien n’a pas pu être envoyé. Vérifiez l’adresse e-mail puis réessayez.',
        ),
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

typedef _WalletActivityEntry = ({
  String title,
  String amount,
  String status,
  String? date,
  String reference,
  VoidCallback onTap,
});

const _restoredDepositAddresses = <String, String>{
  'Polygon': '0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863',
  'BNB Smart Chain': '0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863',
  'Ethereum (ERC-20)': '0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863',
  'Solana': 'Yp2iCDR4rmMiYrfHJh7iucvEWkSCUAhbZPUrqF9T1SK',
  'TRON (TRC-20)': 'TARxxEKmcTttRA5Gs8MgheH7PXGRsaV3fd',
};

const _restoredDepositQrAssets = <String, String>{
  'Polygon': 'assets/deposit_polygon_qr.jpg',
  'BNB Smart Chain': 'assets/deposit_bnb_qr.png',
  'Ethereum (ERC-20)': 'assets/deposit_ethereum_qr.png',
  'Solana': 'assets/deposit_solana_qr.png',
  'TRON (TRC-20)': 'assets/deposit_tron_qr.png',
};

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
    this.amountLabel,
    this.cancelableOrderId,
  });

  final String reference;
  final DateTime date;
  final String operation;
  final double amount;
  final List<(String, String)> details;
  final String status;
  final String notice;
  final String backgroundAsset;
  final String? amountLabel;
  final String? cancelableOrderId;
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

const _monthlyInvestmentYieldPercent = 20;
const _wholeInvestmentPartPriceUsdt = 1000;

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
    required this.portfolioTotal,
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
  final double portfolioTotal;
  final IconData icon;
  final Color color;
  final List<(String, double)> monthlyHistory;
  final List<(String, double)> annualHistory;

  double get pnl => value - costBasis;
  double get pnlPercent => costBasis == 0 ? 0 : pnl / costBasis * 100;
  double get portfolioShare =>
      portfolioTotal == 0 ? 0 : value / portfolioTotal * 100;
}

class _FinancialPosition {
  const _FinancialPosition({
    required this.productId,
    required this.name,
    required this.category,
    required this.unitsRaw,
    required this.unitPriceRaw,
    required this.valueRaw,
    required this.costBasisRaw,
    required this.firstPurchaseAt,
  });

  final String productId;
  final String name;
  final String category;
  final String unitsRaw;
  final String unitPriceRaw;
  final String valueRaw;
  final String costBasisRaw;
  final String firstPurchaseAt;
}

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
  const InvestmentPage({
    super.key,
    this.kycVerified = false,
    @visibleForTesting this.initialDepositRequestsForTesting = const [],
    @visibleForTesting this.initialInvestmentOrdersForTesting = const [],
    @visibleForTesting this.initialFinancialPositionsForTesting = const [],
    @visibleForTesting this.initialInvestmentTermsForTesting,
    @visibleForTesting this.investmentOrderRequestForTesting,
    @visibleForTesting this.redemptionOrderRequestForTesting,
    @visibleForTesting this.manualDepositRequestForTesting,
    @visibleForTesting this.investmentOrderCancellationForTesting,
    @visibleForTesting this.financialDataErrorForTesting,
  });

  /// Set this only after a trusted KYC service confirms the user's identity.
  final bool kycVerified;
  @visibleForTesting
  final List<Map<String, dynamic>> initialDepositRequestsForTesting;
  @visibleForTesting
  final List<Map<String, dynamic>> initialInvestmentOrdersForTesting;
  @visibleForTesting
  final List<Map<String, dynamic>> initialFinancialPositionsForTesting;
  @visibleForTesting
  final ({String balanceRaw, String unitPriceRaw})?
  initialInvestmentTermsForTesting;
  @visibleForTesting
  final Future<void> Function({
    required String productId,
    required String amountRaw,
    required String requestId,
  })?
  investmentOrderRequestForTesting;
  @visibleForTesting
  final Future<Map<String, dynamic>> Function({
    required String productId,
    required String unitsRaw,
    required String requestId,
  })?
  redemptionOrderRequestForTesting;
  @visibleForTesting
  final Future<Map<String, dynamic>> Function({
    required String requestId,
    required String amountRaw,
    required String network,
    required String transactionHash,
  })?
  manualDepositRequestForTesting;
  @visibleForTesting
  final Future<void> Function({required String orderId})?
  investmentOrderCancellationForTesting;
  @visibleForTesting
  final Object? financialDataErrorForTesting;

  @override
  State<InvestmentPage> createState() => _InvestmentPageState();
}

class _InvestmentPageState extends State<InvestmentPage> {
  InvestmentType? _selectedType = InvestmentType.reit;
  bool _filterIsActive = false;
  int _selectedNavigation = 0;
  int _heroCardIndex = 0;
  String _selectedHoldingCategory = 'Tous les actifs';
  bool _isEnglish = false;
  bool _languageSelectionMade = false;
  bool _showAllWalletActivity = false;
  int _notificationReturnNavigation = 0;
  bool _showSupportEmail = false;
  bool _showAuthorizationPage = false;
  bool _showHelpInfoPage = false;
  List<Map<String, dynamic>> _userNotifications = [];
  int _walletCardIndex = 0;
  final PageController _walletPageController = PageController();
  bool _isSubmittingInvestment = false;
  String? _kycDocumentPhotoPath;
  Uint8List? _kycDocumentPhotoBytes;
  String _kycVerificationStatus = 'not_submitted';
  _TransactionReceipt? _selectedReceipt;
  final GlobalKey _receiptImageBoundaryKey = GlobalKey();
  _WalletFlow? _walletFlow;
  _HoldingPosition? _selectedHoldingDetail;
  String? _walletBalanceRaw;
  String? _financialDataError;
  bool _financialDataLoading = false;
  bool _isSubmittingDeposit = false;
  bool _isSubmittingTransfer = false;
  bool _investmentConfigurationLoading = false;
  bool _investmentProductUnavailable = false;
  final List<Map<String, dynamic>> _creditedDeposits = [];
  final List<Map<String, dynamic>> _depositRequests = [];
  final List<Map<String, dynamic>> _withdrawalRequests = [];
  final List<Map<String, dynamic>> _investmentOrders = [];
  final List<Map<String, dynamic>> _redemptionOrders = [];
  final List<Map<String, dynamic>> _monthlyYieldCredits = [];
  final List<_FinancialPosition> _financialPositions = [];
  String _selectedTransferNetwork = 'Polygon';
  final TextEditingController _transferAmountController =
      TextEditingController();
  final TextEditingController _transactionHashController =
      TextEditingController();
  Map<String, dynamic>? _depositSettings;
  String? _depositSettingsError;
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
  String? _investmentUnitPriceRaw;
  String? _investmentMinimumRaw;
  String? _investmentAvailableBalanceRaw;
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
  final PageController _heroPageController = PageController();
  final ImagePicker _imagePicker = ImagePicker();
  String _profileName = '';
  String _profileEmail = '';
  String _profilePhone = '';
  final String _supportEmail = _tamleekSupportEmail;
  final String _websiteUrl = _tamleekWebsiteUrl;
  final String _facebookUrl = _tamleekFacebookUrl;
  final String _youtubeUrl = _tamleekYouTubeUrl;
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
    final financialDataError = widget.financialDataErrorForTesting;
    if (financialDataError != null) {
      _financialDataError = _walletFinancialErrorMessage(
        financialDataError,
        english: _isEnglish,
      );
    }
    _depositRequests.addAll(widget.initialDepositRequestsForTesting);
    _investmentOrders.addAll(widget.initialInvestmentOrdersForTesting);
    _financialPositions.addAll(
      widget.initialFinancialPositionsForTesting.map(
        (row) => _FinancialPosition(
          productId: row['product_id'] as String,
          name: row['name'] as String,
          category: row['category'] as String,
          unitsRaw: row['units_raw'] as String,
          unitPriceRaw: row['unit_price_raw'] as String,
          valueRaw: row['value_raw'] as String,
          costBasisRaw: row['cost_basis_raw'] as String,
          firstPurchaseAt: row['first_purchase_at'] as String,
        ),
      ),
    );
    unawaited(_loadProfile());
    if (_hasAuthenticatedInvestmentBackend &&
        widget.initialInvestmentTermsForTesting == null) {
      unawaited(_loadFinancialData());
    }
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
    _walletPageController.dispose();
    _heroPageController.dispose();
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

  bool get _hasAuthenticatedInvestmentBackend =>
      widget.initialInvestmentTermsForTesting != null ||
      (TamleekSupabaseOptions.isConfigured &&
          Supabase.instance.client.auth.currentUser != null);

  List<Map<String, dynamic>> _financialRows(dynamic value) {
    if (value is! List || value.any((row) => row is! Map)) {
      throw const FormatException('Le serveur a renvoyé une liste invalide.');
    }
    return value.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Map<String, dynamic> _financialRecord(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Le serveur a renvoyé une réponse invalide.');
    }
    return Map<String, dynamic>.from(value);
  }

  Future<void> _loadFinancialData() async {
    if (!_hasAuthenticatedInvestmentBackend) return;
    if (mounted) {
      setState(() {
        _financialDataLoading = true;
        _financialDataError = null;
      });
    }

    final client = Supabase.instance.client;
    try {
      final values = await Future.wait<Object?>([
        client.rpc('get_my_usdt_balance_scaled'),
        client.rpc('get_my_investment_positions'),
        client
            .from('onchain_deposit_verifications')
            .select(
              'id, network, transaction_hash, amount_raw, token_decimals, created_at, status',
            )
            .order('created_at', ascending: false)
            .limit(25),
        client
            .from('deposit_requests')
            .select(
              'id, network, transaction_hash, amount_usdt, status, review_note, created_at',
            )
            .order('created_at', ascending: false)
            .limit(25),
        client
            .from('withdrawal_requests')
            .select(
              'id, network, amount_raw, status, payout_transaction_hash, review_note, created_at',
            )
            .order('created_at', ascending: false)
            .limit(25),
        client
            .from('investment_orders')
            .select(
              'id, product_id, amount_raw, units_raw, status, review_note, created_at',
            )
            .order('created_at', ascending: false)
            .limit(25),
        client
            .from('investment_redemption_orders')
            .select(
              'id, product_id, amount_raw, units_raw, status, review_note, created_at',
            )
            .order('created_at', ascending: false)
            .limit(25),
        client
            .from('investment_monthly_yields')
            .select(
              'product_id, period_start, amount_raw, credit_method, credited_at',
            )
            .order('period_start', ascending: false)
            .limit(120),
        client
            .from('user_deposit_addresses')
            .select('network, recipient_address'),
        client.from('kyc_submissions').select('status').maybeSingle(),
      ]);

      final balanceRaw = values[0] as String?;
      if (balanceRaw == null || BigInt.tryParse(balanceRaw) == null) {
        throw const FormatException('Le solde renvoyé est invalide.');
      }
      final positionRows = _financialRows(values[1]);
      final deposits = _financialRows(values[2]);
      final depositRequests = _financialRows(values[3]);
      final withdrawals = _financialRows(values[4]);
      final orders = _financialRows(values[5]);
      final redemptions = _financialRows(values[6]);
      final monthlyYieldCredits = _financialRows(values[7]);
      final addressRows = _financialRows(values[8]);
      final kyc = values[9] as Map<String, dynamic>?;
      final addresses = <String, dynamic>{};
      for (final row in addressRows) {
        addresses[row['network'] as String] = {
          'address': row['recipient_address'] as String,
        };
      }
      final positions = positionRows.map((row) {
        final productId = row['product_id'] as String;
        final split = productId.split(':');
        final packId = split.length == 2 ? split[1] : '';
        final type = split.isEmpty ? '' : split.first;
        final pack = switch (type) {
          'reit' => _findPack(_reitPacks, packId),
          'fpi' => _findPack(_fpiPacks, packId),
          'commodity' => _findPack(_commodityPacks, packId),
          'crypto' => _findPack(_cryptoPacks, packId),
          'stock' => _findPack(_stockPacks, packId),
          _ => null,
        };
        final category = switch (type) {
          'reit' => 'REIT',
          'fpi' => 'FPI',
          'commodity' => 'Matières premières',
          'crypto' => 'Crypto',
          'stock' => 'Actions',
          _ => 'Autres',
        };
        return _FinancialPosition(
          productId: productId,
          name: pack?.name ?? productId,
          category: category,
          unitsRaw: row['units_raw'] as String,
          unitPriceRaw: row['unit_price_raw'] as String,
          valueRaw: row['value_raw'] as String,
          costBasisRaw: row['cost_basis_raw'] as String,
          firstPurchaseAt: row['first_purchase_at'] as String,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _walletBalanceRaw = balanceRaw;
        _financialPositions
          ..clear()
          ..addAll(positions);
        _creditedDeposits
          ..clear()
          ..addAll(deposits);
        _depositRequests
          ..clear()
          ..addAll(depositRequests);
        _withdrawalRequests
          ..clear()
          ..addAll(withdrawals);
        _investmentOrders
          ..clear()
          ..addAll(orders);
        _redemptionOrders
          ..clear()
          ..addAll(redemptions);
        _monthlyYieldCredits
          ..clear()
          ..addAll(monthlyYieldCredits);
        _depositSettings = addresses;
        _kycVerificationStatus = kyc?['status'] as String? ?? 'not_submitted';
        _investmentAvailableBalanceRaw = balanceRaw;
        _financialDataLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _financialDataLoading = false;
        _financialDataError = _walletFinancialErrorMessage(
          error,
          english: _isEnglish,
        );
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _financialDataLoading = false;
        _financialDataError = _walletFinancialErrorMessage(
          error,
          english: _isEnglish,
        );
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _financialDataLoading = false;
        _financialDataError = _walletFinancialErrorMessage(
          error,
          english: _isEnglish,
        );
      });
    }
  }

  _ReitPack? _findPack(List<_ReitPack> packs, String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  String _financialProductLabel(String? productId) {
    if (productId == null) return _tr('Actif', 'Asset');
    final split = productId.split(':');
    if (split.length != 2) return productId;
    final pack = switch (split.first) {
      'reit' => _findPack(_reitPacks, split.last),
      'fpi' => _findPack(_fpiPacks, split.last),
      'commodity' => _findPack(_commodityPacks, split.last),
      'crypto' => _findPack(_cryptoPacks, split.last),
      'stock' => _findPack(_stockPacks, split.last),
      _ => null,
    };
    return pack?.name ?? productId;
  }

  String _financialProductId(InvestmentType type, _ReitPack pack) {
    final category = switch (type) {
      InvestmentType.reit => 'reit',
      InvestmentType.fpi => 'fpi',
      InvestmentType.commodity => 'commodity',
      InvestmentType.crypto => 'crypto',
      InvestmentType.action => 'stock',
    };
    return '$category:${pack.id}';
  }

  Future<void> _loadInvestmentConfiguration(
    InvestmentType type,
    _ReitPack pack,
  ) async {
    final testingTerms = widget.initialInvestmentTermsForTesting;
    if (testingTerms != null) {
      if (!mounted) return;
      setState(() {
        _investmentUnitPriceRaw = testingTerms.unitPriceRaw;
        _investmentMinimumRaw = (BigInt.from(10) * BigInt.from(10).pow(18))
            .toString();
        _investmentAvailableBalanceRaw = testingTerms.balanceRaw;
        _investmentConfigurationLoading = false;
        _investmentProductUnavailable = false;
      });
      return;
    }
    if (!_hasAuthenticatedInvestmentBackend) {
      if (mounted) {
        setState(() {
          _investmentConfigurationLoading = false;
          _investmentProductUnavailable = false;
        });
      }
      return;
    }
    final productId = _financialProductId(type, pack);
    try {
      final values = await Future.wait<Object?>([
        Supabase.instance.client
            .from('investment_products')
            .select('unit_price_raw')
            .eq('product_id', productId)
            .eq('is_active', true)
            .maybeSingle(),
        Supabase.instance.client.rpc('get_my_usdt_balance_scaled'),
      ]);
      final product = values[0] as Map<String, dynamic>?;
      final balanceRaw = values[1] as String?;
      final unitPriceRaw = product?['unit_price_raw'] as String?;
      final unitPrice = BigInt.tryParse(unitPriceRaw ?? '');
      if (!mounted) return;
      setState(() {
        _investmentUnitPriceRaw = unitPrice != null && unitPrice > BigInt.zero
            ? unitPriceRaw
            : null;
        _investmentMinimumRaw = (BigInt.from(10) * BigInt.from(10).pow(18))
            .toString();
        _investmentAvailableBalanceRaw = balanceRaw;
        _investmentConfigurationLoading = false;
        _investmentProductUnavailable =
            unitPrice == null || unitPrice <= BigInt.zero;
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _investmentConfigurationLoading = false;
          _investmentProductUnavailable = false;
        });
      }
      if (mounted) {
        await _showMessage(
          _readableBackendError(
            error,
            fallback: 'Les conditions de souscription sont momentanément indisponibles.',
            english: _isEnglish,
          ),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _investmentConfigurationLoading = false;
          _investmentProductUnavailable = false;
        });
      }
      if (mounted) {
        await _showMessage(
          _readableBackendError(
            error,
            fallback: 'Le solde n’a pas pu être chargé. Réessayez dans quelques instants.',
            english: _isEnglish,
          ),
        );
      }
    }
  }

  String _newFinancialRequestId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  String _formatRawUsdt(String? raw) {
    final amount = BigInt.tryParse(raw ?? '');
    if (amount == null || amount < BigInt.zero) return '—';
    final unit = BigInt.from(10).pow(18);
    final whole = (amount ~/ unit).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => _isEnglish ? ',' : ' ',
    );
    final cents = ((amount % unit) ~/ BigInt.from(10).pow(16))
        .toString()
        .padLeft(2, '0');
    return '\$$whole${_isEnglish ? '.' : ','}$cents';
  }

  String _walletTotalRaw() {
    var total = BigInt.tryParse(_walletBalanceRaw ?? '') ?? BigInt.zero;
    for (final position in _financialPositions) {
      total += BigInt.tryParse(position.valueRaw) ?? BigInt.zero;
    }
    return total.toString();
  }

  BigInt? _parseUsdtAmountRaw(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (!RegExp(r'^[0-9]+(?:\.[0-9]{1,18})?$').hasMatch(normalized)) {
      return null;
    }
    final parts = normalized.split('.');
    final whole = BigInt.tryParse(parts.first);
    if (whole == null) return null;
    final fractional = parts.length == 1
        ? BigInt.zero
        : BigInt.tryParse(parts.last.padRight(18, '0'));
    if (fractional == null) return null;
    return whole * BigInt.from(10).pow(18) + fractional;
  }

  BigInt? _parseWholeInvestmentPartCount(String input) {
    final normalized = input.trim();
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(normalized)) return null;
    return BigInt.tryParse(normalized);
  }

  BigInt _wholeInvestmentAmountRaw(BigInt partCount) =>
      partCount *
      BigInt.from(_wholeInvestmentPartPriceUsdt) *
      BigInt.from(10).pow(18);

  BigInt? _investmentAmountRawFromInput(String input) {
    if (_investmentMode == _InvestmentMode.fractional) {
      return _parseUsdtAmountRaw(input);
    }
    final partCount = _parseWholeInvestmentPartCount(input);
    return partCount == null ? null : _wholeInvestmentAmountRaw(partCount);
  }

  Future<void> _submitInvestmentOrder() async {
    final amountRaw = _investmentAmountRawFromInput(
      _investmentAmountController.text,
    );
    if (amountRaw == null || amountRaw <= BigInt.zero) {
      await _showMessage(
        _investmentMode == _InvestmentMode.fractional
            ? 'Saisissez un montant valide.'
            : 'Saisissez un nombre entier de parts supérieur à zéro.',
      );
      return;
    }
    final pack = _investmentPack;
    final type = _investmentType;
    if (!_hasAuthenticatedInvestmentBackend || pack == null || type == null) {
      await _showMessage('Connectez-vous à un compte Tamleek pour souscrire.');
      return;
    }
    if (!_isValidInvestmentAmount(amountRaw)) {
      await _showMessage(
        'Le montant ne respecte pas le minimum ou les conditions du produit.',
      );
      return;
    }
    if (amountRaw > BigInt.from(5000) * BigInt.from(10).pow(18) &&
        !_kycRequirementMet) {
      await _showKycInformation();
      if (!_kycRequirementMet) {
        await _showMessage(
          'Les souscriptions supérieures à 5 000 USDT nécessitent une '
          'vérification KYC approuvée.',
        );
        return;
      }
    }

    final requestId = _newFinancialRequestId();
    setState(() => _isSubmittingInvestment = true);
    try {
      final requestForTesting = widget.investmentOrderRequestForTesting;
      if (requestForTesting != null) {
        await requestForTesting(
          productId: _financialProductId(type, pack),
          amountRaw: amountRaw.toString(),
          requestId: requestId,
        );
      } else {
        await Supabase.instance.client.rpc(
          'request_investment_order',
          params: {
            'p_product_id': _financialProductId(type, pack),
            'p_amount_raw': amountRaw.toString(),
            'p_request_id': requestId,
          },
        );
      }
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingInvestment = false);
      if (error.message.toLowerCase().contains(
        'insufficient available usdt balance',
      )) {
        await _showInsufficientInvestmentBalance();
      } else {
        await _showMessage(
          _readableBackendError(
            error,
            fallback: 'La demande n’a pas été enregistrée. Réessayez dans quelques instants.',
            english: _isEnglish,
          ),
        );
      }
      return;
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingInvestment = false);
      await _showMessage(
        _readableBackendError(
          error,
          fallback: 'La demande n’a pas été enregistrée. Réessayez dans quelques instants.',
          english: _isEnglish,
        ),
      );
      return;
    }
    if (!mounted) return;
    final receipt = _TransactionReceipt(
      reference: requestId,
      date: DateTime.now(),
      operation: 'Demande de souscription',
      amount: amountRaw.toDouble() / math.pow(10, 18),
      details: [
        ('Produit', pack.name),
        ('Montant', '${_formatTokenAmount(amountRaw.toString(), 18)} USDT'),
      ],
      status: 'En attente',
      notice:
          'La demande a été enregistrée et le montant réservé. '
          'La souscription ne sera exécutée qu’après validation.',
      backgroundAsset: _investmentImageAsset(type),
    );
    setState(() => _isSubmittingInvestment = false);
    unawaited(_loadFinancialData());
    await _showSuccessConfirmation(
      title: 'Demande de souscription enregistrée',
      message:
          'Votre demande est enregistrée et le montant réservé. '
          'La souscription sera exécutée après validation.',
    );
    if (!mounted) return;
    setState(() => _selectedReceipt = receipt);
  }

  Future<void> _loadProfile() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final photoPath = preferences.getString(_profilePhotoKey);
      final photoExists = photoPath != null && await File(photoPath).exists();
      final user = TamleekSupabaseOptions.isConfigured
          ? Supabase.instance.client.auth.currentUser
          : null;
      final name =
          preferences.getString(_profileNameKey) ??
          (user?.userMetadata?['name'] as String?) ??
          '';
      final email =
          user?.email ?? preferences.getString(_profileEmailKey) ?? '';
      final phone =
          preferences.getString(_profilePhoneKey) ??
          user?.userMetadata?['phone'] as String? ??
          '';
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

  Future<void> _showKycInformation() async {
    if (_kycRequirementMet || _kycVerificationStatus == 'pending') {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('kyc-information-dialog'),
          title: Text(_tr('Vérification KYC', 'KYC verification')),
          content: Text(
            _kycRequirementMet
                ? _tr(
                    'Votre identité a été vérifiée.',
                    'Your identity has been verified.',
                  )
                : _tr(
                    'Votre dossier est en attente de vérification.',
                    'Your documents are awaiting review.',
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
    _kycDocumentPhotoBytes = null;
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
      final bytes = await photo.readAsBytes();
      setState(() {
        _kycDocumentPhotoPath = photo.name;
        _kycDocumentPhotoBytes = bytes;
      });
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

  Future<bool> _showKycForm() async {
    if (!_hasAuthenticatedInvestmentBackend) {
      await _showMessage(
        'Connectez-vous à un compte Tamleek pour transmettre vos documents.',
      );
      return false;
    }

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
                      'Vos informations et votre pièce seront transmises de '
                          'façon sécurisée pour examen. Le dossier ne sera pas '
                          'marqué comme vérifié avant validation.',
                      'Your information and identity document will be securely '
                          'submitted for review. The request will not be marked '
                          'verified until approved.',
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
                        if (_kycDocumentPhotoBytes != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _kycDocumentPhotoBytes!,
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

    return _submitKycInformation();
  }

  Future<bool> _submitKycInformation() async {
    final photoName = _kycDocumentPhotoPath;
    final photoBytes = _kycDocumentPhotoBytes;
    if (!_hasAuthenticatedInvestmentBackend ||
        photoName == null ||
        photoBytes == null) {
      await _showMessage('Sélectionnez une pièce d’identité valide.');
      return false;
    }
    if (photoBytes.length > 5 * 1024 * 1024) {
      await _showMessage('La pièce d’identité doit faire au maximum 5 Mo.');
      return false;
    }

    final extension = photoName.split('.').last.toLowerCase();
    final normalizedExtension = extension == 'jpeg' ? 'jpg' : extension;
    final contentType = switch (normalizedExtension) {
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    if (contentType == null) {
      await _showMessage(
        'Format de pièce non accepté. Utilisez JPG, PNG ou WEBP.',
      );
      return false;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      await _showMessage('Connectez-vous à un compte Tamleek pour continuer.');
      return false;
    }
    final documentPath =
        '${user.id}/${_newFinancialRequestId()}.$normalizedExtension';
    try {
      await client.storage
          .from('kyc-documents')
          .uploadBinary(
            documentPath,
            photoBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      final result = await client.rpc(
        'submit_kyc',
        params: {
          'p_first_name': _kycFirstNameController.text.trim(),
          'p_last_name': _kycLastNameController.text.trim(),
          'p_birth_year': int.parse(_kycBirthYearController.text.trim()),
          'p_birth_place': _kycBirthPlaceController.text.trim(),
          'p_city': _kycCityController.text.trim(),
          'p_department': _kycDepartmentController.text.trim(),
          'p_country': _kycCountryController.text.trim(),
          'p_identity_number': _kycIdentityNumberController.text.trim(),
          'p_document_path': documentPath,
        },
      );
      if (result != 'pending') {
        throw const FormatException(
          'Le serveur n’a pas confirmé le dépôt du dossier KYC.',
        );
      }
      if (!mounted) return false;
      setState(() => _kycVerificationStatus = 'pending');
      _clearKycForm();
      unawaited(_loadFinancialData());
      await _showMessage(
        'Votre dossier KYC a été transmis et attend une vérification.',
      );
      return true;
    } on StorageException catch (error) {
      if (mounted) {
        await _showMessage(
          _readableBackendError(
            error,
            fallback: 'La pièce n’a pas pu être téléversée. Réessayez dans quelques instants.',
            english: _isEnglish,
          ),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        await _showMessage(
          _readableBackendError(
            error,
            fallback: 'Le dossier KYC n’a pas été enregistré. Réessayez dans quelques instants.',
            english: _isEnglish,
          ),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        await _showMessage(
          _readableBackendError(
            error,
            fallback: 'Le dossier KYC n’a pas été transmis. Réessayez dans quelques instants.',
            english: _isEnglish,
          ),
        );
      }
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

  Future<void> _showInsufficientInvestmentBalance() => _showAppFeedback(
    title: 'Solde insuffisant',
    message:
        'Votre solde ne couvre pas cet investissement. Rechargez votre compte, '
        'puis réessayez.',
    isSuccess: false,
  );

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
      await _showSuccessConfirmation(
        title: _tr('Déconnexion réussie', 'Successfully signed out'),
        message: _tr(
          'Vous avez été déconnecté de votre compte.',
          'You have been signed out of your account.',
        ),
      );
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
          _readableAuthError(
            error,
            fallback:
                'La déconnexion a échoué. Réessayez dans quelques instants.',
            english: _isEnglish,
          ),
        );
      }
    }
  }

  Future<void> _showSuccessConfirmation({
    required String title,
    required String message,
  }) => _showAppFeedback(title: title, message: message);

  void _playNotificationSound() {
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  void _openNotifications() {
    setState(() {
      if (_selectedNavigation != 4) {
        _notificationReturnNavigation = _selectedNavigation;
      }
      _selectedNavigation = 4;
      _showSupportEmail = false;
      _showAuthorizationPage = false;
      _showHelpInfoPage = false;
    });
  }

  void _closeNotifications() {
    setState(() => _selectedNavigation = _notificationReturnNavigation);
  }

  void _returnToHome() {
    setState(() {
      _selectedNavigation = 0;
      _showAllWalletActivity = false;
      _selectedReceipt = null;
      _walletFlow = null;
      _selectedHoldingDetail = null;
      _showInvestmentPage = false;
      _investmentPack = null;
      _investmentType = null;
      _selectedReitPack = null;
      _selectedFpiPack = null;
      _selectedCommodityPack = null;
      _selectedCryptoPack = null;
      _selectedStockPack = null;
      _showReitPacksPage = false;
      _showFpiPacksPage = false;
      _showCommodityPacksPage = false;
      _showCryptoPacksPage = false;
      _showStockPacksPage = false;
      _showSupportEmail = false;
      _showAuthorizationPage = false;
      _showHelpInfoPage = false;
      _selectedType = InvestmentType.reit;
      _filterIsActive = false;
      _search = '';
    });
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
                      _showAllWalletActivity ||
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
          onPressed: _openNotifications,
          badge: _userNotifications.any(
            (notification) => notification['read_at'] == null,
          ),
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
                      'Explorer',
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
                    'Explorer',
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
                    'Explorer',
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
                    'Explorer',
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
                    'Explorer',
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
                    'Explorer',
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
    final holdings = pack.holdings;
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
              if (holdings.isEmpty)
                const Text(
                  'La composition de ce pack n’est pas encore publiée.',
                  style: TextStyle(color: _muted, fontSize: 12),
                )
              else
                ...holdings.map(_buildReitHoldingCard),
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
                  'Fiche informative',
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

  bool _isValidInvestmentAmount(BigInt? amountRaw) {
    final balanceRaw = BigInt.tryParse(_investmentAvailableBalanceRaw ?? '');
    final unitPriceRaw = BigInt.tryParse(_investmentUnitPriceRaw ?? '');
    final productMinimumRaw = BigInt.tryParse(_investmentMinimumRaw ?? '');
    if (!_hasAuthenticatedInvestmentBackend ||
        amountRaw == null ||
        balanceRaw == null ||
        unitPriceRaw == null ||
        productMinimumRaw == null ||
        unitPriceRaw <= BigInt.zero) {
      return false;
    }
    final minimum = _investmentMode == _InvestmentMode.fractional
        ? productMinimumRaw
        : _wholeInvestmentAmountRaw(BigInt.one);
    return amountRaw >= minimum &&
        (_investmentMode == _InvestmentMode.fractional ||
            amountRaw % minimum == BigInt.zero);
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
    final isFractionalMode = _investmentMode == _InvestmentMode.fractional;
    final wholePartAmountRaw = _wholeInvestmentAmountRaw(BigInt.one);
    final wholePartCount = isFractionalMode
        ? null
        : _parseWholeInvestmentPartCount(_investmentAmountController.text);
    final amountRaw = isFractionalMode
        ? _parseUsdtAmountRaw(_investmentAmountController.text)
        : wholePartCount == null
        ? null
        : _wholeInvestmentAmountRaw(wholePartCount);
    final balanceRaw = BigInt.tryParse(_investmentAvailableBalanceRaw ?? '');
    final unitPriceRaw = BigInt.tryParse(_investmentUnitPriceRaw ?? '');
    final minimumRaw =
        BigInt.tryParse(_investmentMinimumRaw ?? '') ??
        BigInt.from(10) * BigInt.from(10).pow(18);
    final canContinue = _isValidInvestmentAmount(amountRaw);
    final amountPresets = isFractionalMode
        ? <BigInt>{
            minimumRaw,
            ...[
              10,
              50,
              100,
              500,
            ].map((amount) => BigInt.from(amount) * BigInt.from(10).pow(18)),
          }.where((amount) => amount >= minimumRaw).toList()
        : [1, 2, 4, 5, 10].map(BigInt.from).toList();
    final estimatedUnitsRaw =
        amountRaw == null || unitPriceRaw == null || unitPriceRaw <= BigInt.zero
        ? null
        : amountRaw * BigInt.from(10).pow(18) ~/ unitPriceRaw;
    final monthlyGainRaw = amountRaw == null || amountRaw <= BigInt.zero
        ? null
        : amountRaw *
              BigInt.from(_monthlyInvestmentYieldPercent) ~/
              BigInt.from(100);
    final annualGainRaw = monthlyGainRaw == null
        ? null
        : monthlyGainRaw * BigInt.from(12);
    final minimumAmountLabel = isFractionalMode
        ? '${_formatTokenAmount(minimumRaw.toString(), 18)} USDT'
        : '${_formatTokenAmount(wholePartAmountRaw.toString(), 18)} USDT par part';

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
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFractionalMode
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
                    isFractionalMode
                        ? 'À partir de $minimumAmountLabel'
                        : '1 part = 1 000 USDT, pour tous les actifs',
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
        Text(
          isFractionalMode ? 'Montant à investir' : 'Nombre de parts entières',
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          key: const ValueKey('investment-amount-input'),
          controller: _investmentAmountController,
          keyboardType: isFractionalMode
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          onChanged: (_) {
            setState(() {});
          },
          decoration: InputDecoration(
            prefixText: isFractionalMode ? '\$ ' : null,
            suffixText: isFractionalMode ? null : 'part(s)',
            hintText: isFractionalMode
                ? minimumAmountLabel.replaceFirst(' USDT', '')
                : '1, 2, 4…',
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
            final presetText = isFractionalMode
                ? _formatTokenAmount(preset.toString(), 18)
                : preset.toString();
            return ActionChip(
              key: ValueKey('investment-amount-preset-$presetText'),
              label: Text(
                isFractionalMode
                    ? '\$$presetText'
                    : '$presetText ${preset == BigInt.one ? 'part' : 'parts'}',
              ),
              onPressed: () {
                _investmentAmountController.text = presetText;
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
                balanceRaw == null
                    ? 'Indisponible'
                    : '${_formatTokenAmount(balanceRaw.toString(), 18)} USDT',
              ),
              const Divider(height: 22),
              _investmentSummaryRow(
                isFractionalMode
                    ? 'Minimum de souscription'
                    : 'Prix par part entière',
                isFractionalMode
                    ? minimumAmountLabel
                    : _formatRawUsdt(wholePartAmountRaw.toString()),
              ),
              if (amountRaw != null && amountRaw > BigInt.zero) ...[
                const Divider(height: 22),
                _investmentSummaryRow(
                  'Montant sélectionné',
                  '${_formatTokenAmount(amountRaw.toString(), 18)} USDT',
                  emphasize: true,
                ),
                if (estimatedUnitsRaw != null) ...[
                  const Divider(height: 22),
                  _investmentSummaryRow(
                    'Parts estimées',
                    _formatTokenAmount(estimatedUnitsRaw.toString(), 18),
                  ),
                ],
                const Divider(height: 22),
                _investmentSummaryRow(
                  'Rendement mensuel de référence',
                  '$_monthlyInvestmentYieldPercent %',
                ),
                if (monthlyGainRaw != null) ...[
                  const Divider(height: 22),
                  _investmentSummaryRow(
                    'Rendement mensuel estimé',
                    _formatRawUsdt(monthlyGainRaw.toString()),
                    emphasize: true,
                  ),
                ],
                const Divider(height: 22),
                _investmentSummaryRow(
                  'Rendement annuel estimé (simple)',
                  '${_monthlyInvestmentYieldPercent * 12} %',
                ),
                if (annualGainRaw != null) ...[
                  const Divider(height: 22),
                  _investmentSummaryRow(
                    'Rendement annuel estimé',
                    _formatRawUsdt(annualGainRaw.toString()),
                    emphasize: true,
                  ),
                ],
              ],
            ],
          ),
        ),
        if (!isFractionalMode) ...[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('investment-whole-minimum-note'),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Chaque part entière coûte ${_formatRawUsdt(wholePartAmountRaw.toString())} '
              'USDT, quel que soit l’actif. Saisissez un nombre entier de parts.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('investment-reservation-notice'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF2D99A)),
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
              const Expanded(
                child: Text(
                  'Le système crédite automatiquement 20 % du capital encore '
                  'investi après chaque mois complet. Ce calcul ne vérifie pas '
                  'les encaissements externes; la disponibilité des retraits '
                  'dépend des fonds disponibles. Le montant investi reste '
                  'réservé pendant l’examen de la souscription.',
                  style: TextStyle(
                    color: Color(0xFF70521A),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_investmentAmountController.text.isNotEmpty &&
            !canContinue &&
            !_investmentProductUnavailable &&
            !_investmentConfigurationLoading) ...[
          const SizedBox(height: 8),
          Text(
            isFractionalMode
                ? 'Minimum : $minimumAmountLabel.'
                : 'Saisissez un nombre entier de parts supérieur à zéro.',
            style: TextStyle(color: Color(0xFFB3261E), fontSize: 12),
          ),
        ],
        if (_investmentProductUnavailable) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('investment-product-unavailable'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _tr(
                'Cet actif n’est pas encore ouvert aux souscriptions. Son prix '
                    'doit être configuré avant de pouvoir envoyer une demande.',
                'This asset is not open for subscriptions yet. Its price must '
                    'be configured before you can submit an order.',
              ),
              style: const TextStyle(
                color: Color(0xFF70521A),
                fontSize: 12,
                height: 1.4,
              ),
            ),
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
    final amountRaw = _investmentAmountRawFromInput(
      _investmentAmountController.text,
    );
    final canContinue =
        !_isSubmittingInvestment && _isValidInvestmentAmount(amountRaw);
    final pack = _investmentPack;
    final type = _investmentType;
    final ownedPosition = pack == null || type == null
        ? null
        : _ownedFinancialPosition(type, pack);
    final continueButton = SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        key: const ValueKey('investment-continue-button'),
        onPressed: canContinue ? _submitInvestmentOrder : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF08A957),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB8C0CC),
          shape: const StadiumBorder(),
        ),
        child: _isSubmittingInvestment
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _investmentConfigurationLoading
                    ? _tr('Chargement…', 'Loading…')
                    : _investmentProductUnavailable
                    ? _tr(
                        'Investissement indisponible',
                        'Investment unavailable',
                      )
                    : 'Envoyer la demande',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
    if (ownedPosition == null) return continueButton;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(child: continueButton),
          const SizedBox(width: 8),
          Expanded(child: _buildRedemptionActionButton(ownedPosition)),
        ],
      ),
    );
  }

  _FinancialPosition? _ownedFinancialPosition(
    InvestmentType type,
    _ReitPack pack,
  ) {
    final productId = _financialProductId(type, pack);
    for (final position in _financialPositions) {
      if (position.productId == productId) return position;
    }
    return null;
  }

  Widget _buildRedemptionActionButton(_FinancialPosition position) {
    return Tooltip(
      message: _tr('Demander une revente', 'Request a redemption'),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton.icon(
          key: ValueKey('asset-redemption-button-${position.productId}'),
          onPressed: _isSubmittingTransfer
              ? null
              : () => _requestRedemption(position),
          icon: const Icon(Icons.sell_outlined, size: 18),
          label: Text(_tr('Revendre', 'Sell')),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB3261E),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFB8C0CC),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvestInPackButton(
    _ReitPack pack, {
    required bool isFpi,
    required bool isCommodity,
    required bool isCrypto,
    required bool isAction,
  }) {
    final type = switch ((isFpi, isCommodity, isCrypto, isAction)) {
      (true, _, _, _) => InvestmentType.fpi,
      (_, true, _, _) => InvestmentType.commodity,
      (_, _, true, _) => InvestmentType.crypto,
      (_, _, _, true) => InvestmentType.action,
      _ => InvestmentType.reit,
    };
    final ownedPosition = _ownedFinancialPosition(type, pack);
    final continueButton = SizedBox(
      height: 58,
      child: FilledButton(
        key: const ValueKey('reit-pack-invest-button'),
        onPressed: () {
          setState(() {
            _investmentPack = pack;
            _investmentType = type;
            _investmentMode = _InvestmentMode.fractional;
            _investmentAmountController.clear();
            _investmentUnitPriceRaw = null;
            _investmentAvailableBalanceRaw = null;
            _investmentConfigurationLoading = true;
            _investmentProductUnavailable = false;
            _investmentMinimumRaw = (BigInt.from(10) * BigInt.from(10).pow(18))
                .toString();
            _showInvestmentPage = true;
          });
          unawaited(_loadInvestmentConfiguration(type, pack));
        },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF28334A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB8C0CC),
          shape: const StadiumBorder(),
        ),
        child: const Text(
          'Continuer',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
    if (ownedPosition == null) return continueButton;
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Expanded(child: continueButton),
          const SizedBox(width: 8),
          Expanded(child: _buildRedemptionActionButton(ownedPosition)),
        ],
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
    if (_showAllWalletActivity) return _buildWalletActivityHistoryPage();

    final investedRaw = _financialPositions.fold<BigInt>(
      BigInt.zero,
      (total, position) =>
          total + (BigInt.tryParse(position.valueRaw) ?? BigInt.zero),
    );
    final recentActivity = _financialActivityEntries();
    return ListView(
      key: const ValueKey('wallet-local-page'),
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
        const SizedBox(height: 8),
        Text(
          _financialDataLoading
              ? _tr('Chargement de votre portefeuille…', 'Loading your wallet…')
              : _tr(
                  'Votre solde et vos opérations',
                  'Your balance and transactions',
                ),
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
        if (_financialDataError != null) ...[
          const SizedBox(height: 8),
          Text(
            _tr(
              'Impossible de charger les opérations. $_financialDataError',
              'Unable to load transactions. $_financialDataError',
            ),
            key: const ValueKey('wallet-financial-error'),
            style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          key: const ValueKey('wallet-credited-balance'),
          height: 184,
          child: PageView(
            key: const ValueKey('wallet-balance-carousel'),
            controller: _walletPageController,
            onPageChanged: (index) => setState(() => _walletCardIndex = index),
            children: [
              _walletBalanceCard(
                key: const ValueKey('wallet-total-card'),
                title: _tr('SOLDE TOTAL', 'TOTAL BALANCE'),
                amount: _hasAuthenticatedInvestmentBackend
                    ? _formatRawUsdt(_walletTotalRaw())
                    : '—',
                icon: Icons.account_balance_wallet_outlined,
              ),
              _walletBalanceCard(
                key: const ValueKey('wallet-available-card'),
                title: _tr('DISPONIBLE', 'AVAILABLE'),
                amount: _hasAuthenticatedInvestmentBackend
                    ? _formatRawUsdt(_walletBalanceRaw)
                    : '—',
                icon: Icons.account_balance_outlined,
              ),
              _walletBalanceCard(
                key: const ValueKey('wallet-invested-card'),
                title: _tr('INVESTI', 'INVESTED'),
                amount: _hasAuthenticatedInvestmentBackend
                    ? _formatRawUsdt(investedRaw.toString())
                    : '—',
                icon: Icons.show_chart_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          key: const ValueKey('wallet-page-indicators'),
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
                key: const ValueKey('wallet-deposit-action'),
                icon: Icons.add_rounded,
                label: _tr('Déposer', 'Deposit'),
                onPressed: () => _startWalletFlow(_WalletFlow.deposit),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _walletAction(
                key: const ValueKey('wallet-withdraw-action'),
                icon: Icons.arrow_upward_rounded,
                label: _tr('Retirer', 'Withdraw'),
                onPressed: () => _startWalletFlow(_WalletFlow.withdraw),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          _tr('Demandes de dépôt', 'Deposit requests'),
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_creditedDeposits.isEmpty && _depositRequests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _hasAuthenticatedInvestmentBackend
                  ? _tr(
                      'Aucune demande de dépôt enregistrée.',
                      'No deposit requests recorded.',
                    )
                  : _tr(
                      'Connectez-vous pour consulter vos dépôts.',
                      'Sign in to view your deposits.',
                    ),
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          )
        else ...[
          for (final deposit in _creditedDeposits)
            _walletHistoryRow(
              title: 'Dépôt ${deposit['network']}',
              amount: _formatTokenAmount(
                deposit['amount_raw'].toString(),
                deposit['token_decimals'] as int? ?? 18,
              ),
              status: 'Crédité',
              date: deposit['created_at'] as String?,
            ),
          for (final request in _depositRequests)
            _walletHistoryRow(
              key: ValueKey('deposit-request-receipt-${request['id']}'),
              title: 'Dépôt ${request['network']}',
              amount:
                  '${_formatTokenAmount((_parseUsdtAmountRaw(request['amount_usdt'].toString()) ?? BigInt.zero).toString(), 18)} USDT',
              status: _depositRequestStatusLabel(request['status'] as String?),
              date: request['created_at'] as String?,
              onTap: () => _showDepositRequestReceipt(request),
            ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                _tr('Activité récente', 'Recent activity'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('wallet-activity-see-all'),
              onPressed: () => setState(() => _showAllWalletActivity = true),
              child: Text(_tr('Voir tout', 'See all')),
            ),
          ],
        ),
        if (recentActivity.isEmpty)
          Container(
            key: const ValueKey('wallet-activity-empty'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7EAF0)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: _muted.withValues(alpha: 0.7),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  _hasAuthenticatedInvestmentBackend
                      ? _tr(
                          'Aucune opération enregistrée.',
                          'No transactions recorded.',
                        )
                      : _tr(
                          'Connectez-vous pour consulter vos opérations.',
                          'Sign in to view your transactions.',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          for (final activity in recentActivity)
            _walletHistoryRow(
              key: ValueKey('wallet-activity-entry-${activity.reference}'),
              title: activity.title,
              amount: activity.amount,
              status: activity.status,
              date: activity.date,
              onTap: activity.onTap,
            ),
        const SizedBox(height: 18),
        Container(
          key: const ValueKey('wallet-deposit-confirmation-notice'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _tr(
              'Les dépôts crédités apparaîtront ici après confirmation.',
              'Credited deposits will appear here after confirmation.',
            ),
            style: const TextStyle(
              color: Color(0xFF70521A),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletActivityHistoryPage() {
    final entries = _financialActivityEntries(limit: null);
    return ListView(
      key: const ValueKey('wallet-activity-history-page'),
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('wallet-activity-history-back'),
              onPressed: () => setState(() => _showAllWalletActivity = false),
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
              tooltip: 'Retour au portefeuille',
            ),
            Expanded(
              child: Text(
                _tr('Historique des opérations', 'Transaction history'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              _hasAuthenticatedInvestmentBackend
                  ? _tr(
                      'Aucune opération enregistrée.',
                      'No transactions recorded.',
                    )
                  : _tr(
                      'Connectez-vous pour consulter vos opérations.',
                      'Sign in to view your transactions.',
                    ),
              key: const ValueKey('wallet-activity-history-empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          )
        else
          for (final activity in entries)
            _walletHistoryRow(
              key: ValueKey('wallet-activity-entry-${activity.reference}'),
              title: activity.title,
              amount: activity.amount,
              status: activity.status,
              date: activity.date,
              onTap: activity.onTap,
            ),
      ],
    );
  }

  List<_WalletActivityEntry> _financialActivityEntries({int? limit = 10}) {
    final entries = <_WalletActivityEntry>[];
    for (final deposit in _creditedDeposits) {
      final decimals = deposit['token_decimals'] as int? ?? 18;
      final raw = BigInt.tryParse(deposit['amount_raw'].toString());
      if (raw == null) continue;
      final normalized = raw * BigInt.from(10).pow(18 - decimals);
      entries.add((
        title: 'Dépôt ${deposit['network']}',
        amount: '+${_formatTokenAmount(normalized.toString(), 18)} USDT',
        status: 'Crédité',
        date: deposit['created_at'] as String?,
        reference: deposit['id']?.toString() ?? '',
        onTap: () => _showFinancialHistoryReceipt(
          reference: deposit['id']?.toString(),
          operation: 'Dépôt confirmé',
          amountRaw: normalized.toString(),
          amountLabel: '+${_formatTokenAmount(normalized.toString(), 18)} USDT',
          status: 'credited',
          date: deposit['created_at'] as String?,
          details: [
            if (deposit['network'] != null)
              ('Réseau', deposit['network'].toString()),
            if (deposit['transaction_hash'] != null)
              (
                'Hash de transaction',
                _shortenReceiptIdentifier(
                  deposit['transaction_hash'].toString(),
                ),
              ),
          ],
        ),
      ));
    }
    for (final request in _depositRequests) {
      final amountRaw = _parseUsdtAmountRaw(request['amount_usdt'].toString());
      if (amountRaw == null) continue;
      final status = request['status'] as String?;
      entries.add((
        title: 'Dépôt ${request['network']}',
        amount:
            '${status == 'credited' ? '+' : ''}${_formatTokenAmount(amountRaw.toString(), 18)} USDT',
        status: _depositRequestStatusLabel(status),
        date: request['created_at'] as String?,
        reference: request['id']?.toString() ?? '',
        onTap: () => _showDepositRequestReceipt(request),
      ));
    }
    for (final request in _withdrawalRequests) {
      final amountRaw = request['amount_raw'].toString();
      entries.add((
        title: 'Retrait ${request['network']}',
        amount: '-${_formatTokenAmount(amountRaw, 18)} USDT',
        status: _financialStatusLabel(request['status'] as String?),
        date: request['created_at'] as String?,
        reference: request['id']?.toString() ?? '',
        onTap: () => _showFinancialHistoryReceipt(
          reference: request['id']?.toString(),
          operation: 'Retrait USDT',
          amountRaw: amountRaw,
          amountLabel: '-${_formatTokenAmount(amountRaw, 18)} USDT',
          status: request['status'] as String?,
          date: request['created_at'] as String?,
          details: [
            if (request['network'] != null)
              ('Réseau', request['network'].toString()),
            if (request['payout_transaction_hash'] != null)
              (
                'Hash de transaction',
                _shortenReceiptIdentifier(
                  request['payout_transaction_hash'].toString(),
                ),
              ),
            if (_readableTransactionNote(
                  request['status'] as String?,
                  request['review_note'],
                )
                case final note?)
              ('Décision', note),
          ],
        ),
      ));
    }
    for (final order in _investmentOrders) {
      final amountRaw = order['amount_raw'].toString();
      entries.add((
        title:
            'Souscription ${_financialProductLabel(order['product_id']?.toString())}',
        amount: '-${_formatTokenAmount(amountRaw, 18)} USDT',
        status: _financialStatusLabel(order['status'] as String?),
        date: order['created_at'] as String?,
        reference: order['id']?.toString() ?? '',
        onTap: () => _showFinancialHistoryReceipt(
          reference: order['id']?.toString(),
          operation: 'Souscription d’investissement',
          amountRaw: amountRaw,
          amountLabel: '-${_formatTokenAmount(amountRaw, 18)} USDT',
          status: order['status'] as String?,
          date: order['created_at'] as String?,
          cancelableOrderId: order['status'] == 'pending'
              ? order['id']?.toString()
              : null,
          details: [
            (
              'Produit',
              _financialProductLabel(order['product_id']?.toString()),
            ),
            if (order['units_raw'] != null)
              (
                'Parts estimées',
                _formatTokenAmount(order['units_raw'].toString(), 18),
              ),
            if (_readableTransactionNote(
                  order['status'] as String?,
                  order['review_note'],
                )
                case final note?)
              ('Décision', note),
          ],
        ),
      ));
    }
    for (final order in _redemptionOrders) {
      final amountRaw = order['amount_raw'].toString();
      entries.add((
        title:
            'Revente ${_financialProductLabel(order['product_id']?.toString())}',
        amount: '+${_formatTokenAmount(amountRaw, 18)} USDT',
        status: _financialStatusLabel(order['status'] as String?),
        date: order['created_at'] as String?,
        reference: order['id']?.toString() ?? '',
        onTap: () => _showFinancialHistoryReceipt(
          reference: order['id']?.toString(),
          operation: 'Demande de revente',
          amountRaw: amountRaw,
          amountLabel: '+${_formatTokenAmount(amountRaw, 18)} USDT',
          status: order['status'] as String?,
          date: order['created_at'] as String?,
          details: [
            (
              'Produit',
              _financialProductLabel(order['product_id']?.toString()),
            ),
            if (order['units_raw'] != null)
              (
                'Parts demandées',
                _formatTokenAmount(order['units_raw'].toString(), 18),
              ),
            if (_readableTransactionNote(
                  order['status'] as String?,
                  order['review_note'],
                )
                case final note?)
              ('Décision', note),
          ],
        ),
      ));
    }
    for (final credit in _monthlyYieldCredits) {
      final amountRaw = BigInt.tryParse(credit['amount_raw'].toString());
      if (amountRaw == null) continue;
      final periodStart = DateTime.tryParse(
        credit['period_start']?.toString() ?? '',
      );
      final period = periodStart == null
          ? ''
          : ' · ${periodStart.month.toString().padLeft(2, '0')}/${periodStart.year}';
      final method = credit['credit_method'] == 'scheduled_fixed_20'
          ? _tr('Rendement automatique', 'Automatic yield')
          : _tr('Rendement mensuel', 'Monthly yield');
      final amountLabel =
          '+${_formatTokenAmount(amountRaw.toString(), 18)} USDT';
      entries.add((
        title: '$method ${credit['product_id']}$period',
        amount: amountLabel,
        status: _tr('Crédité', 'Credited'),
        date: credit['credited_at'] as String?,
        reference: '${credit['product_id']}|${credit['period_start']}',
        onTap: () => _showFinancialHistoryReceipt(
          reference: '${credit['product_id']}|${credit['period_start']}',
          operation: method,
          amountRaw: amountRaw.toString(),
          amountLabel: amountLabel,
          status: 'credited',
          date: credit['credited_at'] as String?,
          details: [
            ('Produit', credit['product_id'].toString()),
            if (credit['period_start'] != null)
              ('Période', credit['period_start'].toString()),
          ],
        ),
      ));
    }
    entries.sort((left, right) {
      final leftDate = DateTime.tryParse(left.date ?? '') ?? DateTime(1970);
      final rightDate = DateTime.tryParse(right.date ?? '') ?? DateTime(1970);
      return rightDate.compareTo(leftDate);
    });
    return limit == null ? entries : entries.take(limit).toList();
  }

  void _showFinancialHistoryReceipt({
    required String? reference,
    required String operation,
    required String? amountRaw,
    required String amountLabel,
    required String? status,
    required String? date,
    String? cancelableOrderId,
    required List<(String, String)> details,
  }) {
    final amount = BigInt.tryParse(amountRaw ?? '');
    final parsedDate = DateTime.tryParse(date ?? '');
    if (reference == null ||
        reference.isEmpty ||
        amount == null ||
        amount <= BigInt.zero ||
        parsedDate == null) {
      unawaited(
        _showMessage('Les informations du reçu d’historique sont incomplètes.'),
      );
      return;
    }

    setState(() {
      _selectedReceipt = _TransactionReceipt(
        reference: reference,
        date: parsedDate,
        operation: operation,
        amount: amount.toDouble() / math.pow(10, 18),
        amountLabel: amountLabel,
        details: details,
        status: _financialStatusLabel(status),
        notice:
            'Ce reçu reprend les informations et le statut enregistrés dans '
            'l’historique Tamleek.',
        backgroundAsset: 'assets/usdt_logo.png',
        cancelableOrderId: cancelableOrderId,
      );
    });
  }

  Future<void> _cancelInvestmentOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler la souscription ?'),
        content: const Text(
          'Cette action libérera le montant réservé et ne pourra pas être '
          'annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Garder la demande'),
          ),
          FilledButton(
            key: const ValueKey('receipt-cancel-order-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Annuler la souscription'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!_hasAuthenticatedInvestmentBackend &&
        widget.investmentOrderCancellationForTesting == null) {
      await _showMessage('Connectez-vous à un compte Tamleek pour continuer.');
      return;
    }

    setState(() => _isSubmittingTransfer = true);
    try {
      final cancellationForTesting =
          widget.investmentOrderCancellationForTesting;
      if (cancellationForTesting != null) {
        await cancellationForTesting(orderId: orderId);
      } else {
        await Supabase.instance.client.rpc(
          'cancel_investment_order',
          params: {'p_order_id': orderId},
        );
      }
      await _loadFinancialData();
      if (!mounted) return;
      final receipt = _selectedReceipt;
      setState(() {
        _isSubmittingTransfer = false;
        if (receipt != null) {
          _selectedReceipt = _TransactionReceipt(
            reference: receipt.reference,
            date: receipt.date,
            operation: receipt.operation,
            amount: receipt.amount,
            amountLabel: receipt.amountLabel,
            details: receipt.details,
            status: 'Annulé',
            notice: 'Cette souscription a été annulée.',
            backgroundAsset: receipt.backgroundAsset,
          );
        }
      });
      await _showSuccessConfirmation(
        title: 'Souscription annulée',
        message:
            'Votre demande a été annulée et le montant réservé est libéré.',
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      await _showMessage(
        _readableBackendError(
          error,
          fallback: 'La souscription n’a pas pu être annulée. Réessayez.',
          english: _isEnglish,
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      await _showMessage(
        _readableBackendError(
          error,
          fallback: 'La souscription n’a pas pu être annulée. Réessayez.',
          english: _isEnglish,
        ),
      );
    } finally {
      if (mounted && _isSubmittingTransfer) {
        setState(() => _isSubmittingTransfer = false);
      }
    }
  }

  String _financialStatusLabel(String? status) => switch (status) {
    'pending' => 'En attente',
    'approved' => 'Confirmé',
    'paid' => 'Payé',
    'rejected' => 'Refusé',
    'cancelled' => 'Annulé',
    'credited' => 'Crédité',
    _ => 'Inconnu',
  };

  String? _readableTransactionNote(String? status, Object? note) {
    final normalizedNote = note?.toString().trim().toLowerCase() ?? '';
    if (normalizedNote.isEmpty) return null;
    return switch (normalizedNote) {
      'approuver' ||
      'approved' ||
      'approve' => _tr('Demande approuvée.', 'Request approved.'),
      'refuser' ||
      'rejected' ||
      'reject' => _tr('Demande refusée.', 'Request rejected.'),
      _ => switch (status) {
        'credited' ||
        'approved' ||
        'paid' => _tr('Demande approuvée.', 'Request approved.'),
        'rejected' => _tr('Demande refusée.', 'Request rejected.'),
        _ => _tr(
          'Une note de traitement a été enregistrée.',
          'A processing note was recorded.',
        ),
      },
    };
  }

  String _depositRequestStatusLabel(String? status) => switch (status) {
    'pending' => 'En attente',
    'credited' => 'Crédité',
    'rejected' => 'Refusé',
    _ => 'Inconnu',
  };

  void _showDepositRequestReceipt(Map<String, dynamic> request) {
    final reference = request['id']?.toString();
    final network = request['network']?.toString();
    final transactionHash = request['transaction_hash']?.toString();
    final amountRaw = _parseUsdtAmountRaw(
      request['amount_usdt']?.toString() ?? '',
    );
    final date = DateTime.tryParse(request['created_at']?.toString() ?? '');
    if (reference == null ||
        reference.isEmpty ||
        network == null ||
        network.isEmpty ||
        transactionHash == null ||
        transactionHash.isEmpty ||
        amountRaw == null ||
        date == null) {
      unawaited(
        _showMessage('Les informations du reçu de dépôt sont incomplètes.'),
      );
      return;
    }

    final status = request['status'] as String?;
    final statusLabel = _depositRequestStatusLabel(status);
    final reviewNote = request['review_note']?.toString().trim() ?? '';
    final notice = switch (status) {
      'pending' =>
        'Votre dépôt est en attente de validation manuelle. Le solde sera '
            'crédité uniquement après approbation.',
      'credited' => 'Votre dépôt a été vérifié et crédité sur votre compte.',
      'rejected' =>
        'Votre dépôt a été refusé et aucun montant n’a été crédité.',
      _ => 'Le statut de cette demande doit être vérifié auprès du support.',
    };

    setState(() {
      _selectedReceipt = _TransactionReceipt(
        reference: reference,
        date: date,
        operation: 'Dépôt USDT',
        amount: amountRaw.toDouble() / math.pow(10, 18),
        amountLabel: '${_formatTokenAmount(amountRaw.toString(), 18)} USDT',
        details: [
          ('Réseau', network),
          ('Hash de transaction', _shortenReceiptIdentifier(transactionHash)),
          if (_readableTransactionNote(status, reviewNote) case final note?)
            ('Décision', note),
        ],
        status: statusLabel,
        notice: notice,
        backgroundAsset: 'assets/usdt_logo.png',
      );
    });
  }

  Future<void> _showDepositRequestReceiptAfterConfirmation(
    Map<String, dynamic> request,
  ) async {
    final credited = request['status'] == 'credited';
    await _showSuccessConfirmation(
      title: credited ? 'Dépôt confirmé' : 'Demande de dépôt enregistrée',
      message: credited
          ? 'Votre transaction a été vérifiée et le montant crédité.'
          : 'Votre demande est en attente d’une validation manuelle. Le '
                'montant sera crédité uniquement après approbation.',
    );
    if (!mounted) return;
    _showDepositRequestReceipt(request);
  }

  Widget _walletHistoryRow({
    Key? key,
    required String title,
    required String amount,
    required String status,
    required String? date,
    VoidCallback? onTap,
  }) {
    final parsedDate = DateTime.tryParse(date ?? '');
    final dateLabel = parsedDate == null
        ? ''
        : '${parsedDate.day.toString().padLeft(2, '0')}/'
              '${parsedDate.month.toString().padLeft(2, '0')}/'
              '${parsedDate.year}';
    return Container(
      key: key,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EAF0))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF314A70),
                  size: 20,
                ),
                const SizedBox(width: 10),
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
                      const SizedBox(height: 3),
                      Text(
                        [
                          status,
                          dateLabel,
                        ].where((value) => value.isNotEmpty).join(' · '),
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amount,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF667085),
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _walletBalanceCard({
    required Key key,
    required String title,
    required String amount,
    required IconData icon,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF11141E),
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
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletAction({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        key: key,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF18A765),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB8C0CC),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  void _startWalletFlow(_WalletFlow flow) {
    setState(() {
      _walletFlow = flow;
      _transferAmountController.clear();
      _transactionHashController.clear();
      _destinationAddressController.clear();
      _selectedTransferNetwork = 'Polygon';
    });
    unawaited(_loadFinancialData());
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
                setState(() {
                  _selectedTransferNetwork = network;
                });
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
        ...[
          const SizedBox(height: 22),
          _buildPackSectionTitle(
            isDeposit ? 'Montant à déposer (USDT)' : 'Montant en dollars',
          ),
          const SizedBox(height: 10),
          Form(
            key: _transferFormKey,
            child: TextFormField(
              key: const ValueKey('transfer-amount-input'),
              controller: _transferAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                final amount = _parseUsdtAmountRaw(value ?? '');
                if (amount == null || amount <= BigInt.zero) {
                  return 'Saisissez un montant valide.';
                }
                if (amount < BigInt.from(10) * BigInt.from(10).pow(18)) {
                  return isDeposit
                      ? 'Le dépôt minimum est de 10 \$.'
                      : 'Le retrait minimum est de 10 USDT.';
                }
                return null;
              },
            ),
          ),
        ],
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
              if (!isDeposit) {
                final address = value!.trim();
                final valid = switch (_selectedTransferNetwork) {
                  'Polygon' || 'BNB Smart Chain' || 'Ethereum (ERC-20)' =>
                    RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address),
                  'Solana' => RegExp(
                    r'^[1-9A-HJ-NP-Za-km-z]{32,44}$',
                  ).hasMatch(address),
                  'TRON (TRC-20)' => RegExp(
                    r'^T[1-9A-HJ-NP-Za-km-z]{33}$',
                  ).hasMatch(address),
                  _ => false,
                };
                if (!valid) {
                  return 'Adresse invalide pour le réseau $_selectedTransferNetwork.';
                }
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 10),
        Text(
          isDeposit
              ? 'Votre dépôt sera crédité uniquement après vérification de sa réception.'
              : 'Le retrait sera traité après vérification du solde.',
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
                      ? 'Le solde ne change qu’après vérification et confirmation de la réception.'
                      : 'Aucun retrait ne sera exécuté avant confirmation.',
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
            onPressed: _isSubmittingDeposit || _isSubmittingTransfer
                ? null
                : _submitTransferRequest,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF18A765),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: Text(
              isDeposit
                  ? _isSubmittingDeposit
                        ? 'Envoi en cours…'
                        : 'Envoyer la demande de dépôt'
                  : _kycRequirementMet
                  ? _isSubmittingTransfer
                        ? 'Envoi en cours…'
                        : 'Envoyer la demande de retrait'
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

  Future<void> _shareTamleekApp() async {
    final shareText = _isEnglish
        ? '🏡💰 Discover TAMLEEK, a new way to participate in real estate '
              'and cryptocurrency investment projects!\n\n'
              '🚀 Start with just \$10 and explore investment opportunities. '
              'Some projects advertise target returns of up to 20% per month; '
              'returns are not guaranteed.\n\n'
              '📱 Invest easily from your phone and follow your participation '
              'with ease.\n\n'
              '💎 TAMLEEK – Invest today, build your future!\n\n'
              'Join us now:\n$_tamleekShareUrl\n\n'
              '⚠️ Returns are not guaranteed. All investments involve risk.'
        : '🏡💰 Découvrez TAMLEEK, une nouvelle façon de participer à des '
              'projets d’investissement dans l’immobilier et les '
              'cryptomonnaies !\n\n'
              '🚀 Commencez avec seulement 10 \$ et découvrez des opportunités '
              'd’investissement. Certains projets affichent des objectifs de '
              'rendement pouvant atteindre 20 % par mois; ces rendements ne '
              'sont pas garantis.\n\n'
              '📱 Investissez simplement depuis votre téléphone et suivez '
              'votre participation en toute simplicité.\n\n'
              '💎 TAMLEEK – Investissez aujourd’hui, construisez votre avenir !'
              '\n\nRejoignez-nous dès maintenant :\n$_tamleekShareUrl\n\n'
              '⚠️ Les rendements ne sont pas garantis. Tout investissement '
              'comporte des risques.';

    try {
      final shareImageData = await rootBundle.load(
        'assets/tamleek_share_image.png',
      );
      final temporaryDirectory = await getTemporaryDirectory();
      final shareImageFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        'tamleek-share-image.png',
      );
      await shareImageFile.writeAsBytes(
        shareImageData.buffer.asUint8List(
          shareImageData.offsetInBytes,
          shareImageData.lengthInBytes,
        ),
        flush: true,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(shareImageFile.path)],
          previewThumbnail: XFile(shareImageFile.path),
          subject: _isEnglish ? 'Discover TAMLEEK' : 'Découvrez TAMLEEK',
          text: shareText,
        ),
      );
    } on FileSystemException {
      if (mounted) {
        await _showMessage(
          _tr(
            'Le logo Tamleek n’a pas pu être préparé pour le partage.',
            'The Tamleek logo could not be prepared for sharing.',
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _showMessage(
          '${_tr('Le partage de Tamleek a échoué.', 'Sharing Tamleek failed.')} '
          '${error.message ?? ''}',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        await _showMessage(
          _tr(
            'Le partage n’est pas disponible sur cet appareil.',
            'Sharing is not available on this device.',
          ),
        );
      }
    }
  }

  Widget _buildReceiptPage(_TransactionReceipt receipt) {
    final date = receipt.date;
    final profilePhotoPath = _profilePhotoPath;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final isSuccessful = const {
      'Confirmé',
      'Réussi',
      'Crédité',
      'Payé',
    }.contains(receipt.status);
    final isFailed = const {
      'Annulé',
      'Refusé',
      'Invalide',
    }.contains(receipt.status);
    final statusColor = isSuccessful
        ? const Color(0xFF188A58)
        : isFailed
        ? const Color(0xFFB3261E)
        : const Color(0xFF8A5B00);
    final statusBackground = isSuccessful
        ? const Color(0xFFE7F7EC)
        : isFailed
        ? const Color(0xFFFDECEC)
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
                          _shortenReceiptIdentifier(receipt.reference),
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
                              CircleAvatar(
                                key: const ValueKey('receipt-profile-avatar'),
                                radius: 19,
                                backgroundColor: Colors.white,
                                backgroundImage: profilePhotoPath == null
                                    ? null
                                    : FileImage(File(profilePhotoPath)),
                                child: profilePhotoPath == null
                                    ? const Icon(
                                        Icons.person_outline_rounded,
                                        color: _ink,
                                      )
                                    : null,
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
                            'Montant total',
                            receipt.amountLabel ??
                                _formatInvestmentCurrency(receipt.amount),
                            emphasize: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          key: ValueKey('receipt-status-${receipt.status}'),
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
                                    : isFailed
                                    ? Icons.cancel_rounded
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
        if (receipt.cancelableOrderId != null) ...[
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              key: const ValueKey('receipt-cancel-investment-order'),
              onPressed: _isSubmittingTransfer
                  ? null
                  : () => _cancelInvestmentOrder(receipt.cancelableOrderId!),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Annuler la souscription'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
                side: const BorderSide(color: Color(0xFFB3261E)),
                shape: const StadiumBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
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

  String _shortenReceiptIdentifier(String value) {
    const prefixLength = 8;
    const suffixLength = 6;
    if (value.length <= prefixLength + suffixLength + 1) return value;
    return '${value.substring(0, prefixLength)}…'
        '${value.substring(value.length - suffixLength)}';
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
    final settings = _depositSettings?[_selectedTransferNetwork];
    final networkSettings = settings is Map
        ? Map<String, dynamic>.from(settings)
        : <String, dynamic>{};
    final assignedAddress = networkSettings['address'] as String?;
    final isPersonalAddress = assignedAddress?.trim().isNotEmpty ?? false;
    final address = isPersonalAddress
        ? assignedAddress
        : _restoredDepositAddresses[_selectedTransferNetwork];
    if (address == null || address.trim().isEmpty) {
      return Container(
        key: const ValueKey('transfer-deposit-settings-error'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF2D99A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _depositSettingsError ??
                  _tr(
                    'Aucune adresse de dépôt personnelle n’est attribuée sur ce réseau.',
                    'No personal deposit address has been assigned for this network.',
                  ),
              style: const TextStyle(color: Color(0xFF70521A), fontSize: 12),
            ),
          ],
        ),
      );
    }
    final qrUrl = networkSettings['qr_url'] as String?;
    final qrAsset = _restoredDepositQrAssets[_selectedTransferNetwork];
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
              child: qrUrl != null && qrUrl.isNotEmpty
                  ? Image.network(
                      qrUrl,
                      key: const ValueKey('transfer-deposit-qr'),
                      width: 156,
                      height: 156,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _DepositQrUnavailable(),
                    )
                  : qrAsset != null
                  ? Image.asset(
                      qrAsset,
                      key: const ValueKey('transfer-deposit-qr'),
                      width: 156,
                      height: 156,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _DepositQrUnavailable(),
                    )
                  : const _DepositQrUnavailable(),
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

  Future<Map<String, dynamic>> _loadDepositRequest(String? requestId) async {
    if (requestId == null || requestId.isEmpty) {
      throw const FormatException(
        'Le serveur n’a pas renvoyé la référence de la demande de dépôt.',
      );
    }

    final client = Supabase.instance.client;
    final request = await client
        .from('deposit_requests')
        .select(
          'id, network, transaction_hash, amount_usdt, status, review_note, created_at',
        )
        .eq('id', requestId)
        .single();
    if (request['status'] is! String) {
      throw const FormatException(
        'Le serveur n’a pas renvoyé le statut de la demande.',
      );
    }
    return Map<String, dynamic>.from(request);
  }

  Future<Map<String, dynamic>> _saveManualDepositRequest(
    BigInt amountRaw, {
    required String requestId,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'request_manual_deposit',
      params: {
        'p_request_id': requestId,
        'p_amount_raw': amountRaw.toString(),
        'p_network': _selectedTransferNetwork,
        'p_transaction_hash': _transactionHashController.text.trim(),
      },
    );
    if (response is! String || response.isEmpty) {
      throw const FormatException(
        'Le serveur n’a pas confirmé l’enregistrement de la demande.',
      );
    }
    return _loadDepositRequest(response);
  }

  Future<void> _submitTransferRequest() async {
    final isDeposit = _walletFlow == _WalletFlow.deposit;
    if (!_hasAuthenticatedInvestmentBackend &&
        !(isDeposit && widget.manualDepositRequestForTesting != null)) {
      await _showMessage('Connectez-vous à un compte Tamleek pour continuer.');
      return;
    }

    if (isDeposit) {
      if (!(_transferFormKey.currentState?.validate() ?? false)) return;
      if (!(_transactionHashFormKey.currentState?.validate() ?? false)) return;
      final amountRaw = _parseUsdtAmountRaw(_transferAmountController.text);
      if (amountRaw == null) return;

      setState(() => _isSubmittingDeposit = true);
      Map<String, dynamic>? receiptRequest;
      try {
        final requestId = _newFinancialRequestId();
        final requestForTesting = widget.manualDepositRequestForTesting;
        receiptRequest = requestForTesting != null
            ? await requestForTesting(
                requestId: requestId,
                amountRaw: amountRaw.toString(),
                network: _selectedTransferNetwork,
                transactionHash: _transactionHashController.text.trim(),
              )
            : await _saveManualDepositRequest(amountRaw, requestId: requestId);
        await _loadFinancialData();
      } on Exception catch (error) {
        if (mounted) {
          await _showMessage(
            _readableBackendError(
              error,
              fallback:
                  'La demande de dépôt n’a pas pu être enregistrée. '
                  'Réessayez dans quelques instants.',
              english: _isEnglish,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmittingDeposit = false);
      }
      if (receiptRequest != null && mounted) {
        await _showDepositRequestReceiptAfterConfirmation(receiptRequest);
      }
      return;
    }

    if (!_kycRequirementMet) {
      await _showKycInformation();
      return;
    }
    if (!(_transferFormKey.currentState?.validate() ?? false) ||
        !(_destinationAddressFieldKey.currentState?.validate() ?? false)) {
      return;
    }
    final amountRaw = _parseUsdtAmountRaw(_transferAmountController.text);
    if (amountRaw == null) return;
    final requestId = _newFinancialRequestId();
    setState(() => _isSubmittingTransfer = true);
    late final _TransactionReceipt receipt;
    try {
      final value = await Supabase.instance.client.rpc(
        'request_withdrawal',
        params: {
          'p_amount_raw': amountRaw.toString(),
          'p_network': _selectedTransferNetwork,
          'p_recipient_address': _destinationAddressController.text.trim(),
          'p_request_id': requestId,
        },
      );
      final request = _financialRecord(value);
      if (request['status'] != 'pending') {
        throw const FormatException(
          'Le serveur n’a pas confirmé le statut de la demande.',
        );
      }
      if (!mounted) return;
      receipt = _TransactionReceipt(
        reference: requestId,
        date: DateTime.now(),
        operation: 'Demande de retrait',
        amount: amountRaw.toDouble() / math.pow(10, 18),
        details: [
          ('Réseau', _selectedTransferNetwork),
          ('Adresse de destination', _destinationAddressController.text.trim()),
          (
            'Montant demandé',
            '${_formatTokenAmount(amountRaw.toString(), 18)} USDT',
          ),
        ],
        status: 'En attente',
        notice:
            'Votre demande est enregistrée. Le traitement peut prendre '
            'jusqu’à 1 heure. Le statut sera actualisé dans votre historique.',
        backgroundAsset: 'assets/usdt_logo.png',
      );
      setState(() => _isSubmittingTransfer = false);
      unawaited(_loadFinancialData());
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingTransfer = false);
      await _showMessage(
        _readableBackendError(
          error,
          fallback: 'La demande de retrait a échoué. Réessayez dans quelques instants.',
          english: _isEnglish,
        ),
      );
      return;
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingTransfer = false);
      await _showMessage(
        _readableBackendError(
          error,
          fallback: 'La demande de retrait a échoué. Réessayez dans quelques instants.',
          english: _isEnglish,
        ),
      );
      return;
    }
    await _showSuccessConfirmation(
      title: 'Demande de retrait enregistrée',
      message:
          'Votre demande est en attente de traitement. Le transfert sera '
          'effectué après vérification.',
    );
    if (!mounted) return;
    setState(() => _selectedReceipt = receipt);
  }

  String _formatTokenAmount(String raw, int decimals) {
    final amount = BigInt.tryParse(raw);
    if (amount == null ||
        amount < BigInt.zero ||
        decimals < 0 ||
        decimals > 18) {
      throw const FormatException('Invalid token amount.');
    }
    final unit = BigInt.from(10).pow(decimals);
    final whole = amount ~/ unit;
    final fractional = decimals == 0
        ? ''
        : (amount % unit)
              .toString()
              .padLeft(decimals, '0')
              .replaceFirst(RegExp(r'0+$'), '');
    return fractional.isEmpty ? '$whole' : '$whole.$fractional';
  }

  Widget _buildHoldingsPage() {
    const categories = [
      'Tous les actifs',
      'REIT',
      'Crypto',
      'FPI',
      'Matières premières',
      'Actions',
    ];
    final visiblePositions = _financialPositions.where(
      (position) =>
          _selectedHoldingCategory == 'Tous les actifs' ||
          position.category == _selectedHoldingCategory,
    );
    final totalValueRaw = _financialPositions.fold<BigInt>(
      BigInt.zero,
      (total, position) =>
          total + (BigInt.tryParse(position.valueRaw) ?? BigInt.zero),
    );

    return ListView(
      key: const ValueKey('holdings-local-page'),
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 112),
      children: [
        Text(
          _tr('Mes actifs', 'My assets'),
          style: const TextStyle(
            color: _ink,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _tr('Vos investissements détenus', 'Your held investments'),
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        KeyedSubtree(
          key: const ValueKey('holdings-total-card'),
          child: Container(
            key: const ValueKey('investment-approved-total'),
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
                  _tr('VALEUR DE MES ACTIFS', 'MY ASSET VALUE'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _hasAuthenticatedInvestmentBackend
                      ? _formatRawUsdt(totalValueRaw.toString())
                      : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _holdingsAllocationCard(),
        const SizedBox(height: 24),
        Text(
          _tr('Positions détenues', 'Held positions'),
          style: const TextStyle(
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
        for (final position in visiblePositions)
          _holdingCard(_toHoldingPosition(position, totalValueRaw)),
        if (visiblePositions.isEmpty)
          Container(
            key: const ValueKey('holdings-positions-empty'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7EAF0)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: _muted.withValues(alpha: 0.7),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  _hasAuthenticatedInvestmentBackend
                      ? _tr(
                          'Aucune position enregistrée.',
                          'No positions recorded.',
                        )
                      : _tr(
                          'Connectez-vous pour consulter vos positions.',
                          'Sign in to view your positions.',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  _HoldingPosition _toHoldingPosition(
    _FinancialPosition position,
    BigInt totalValueRaw,
  ) {
    final value = BigInt.tryParse(position.valueRaw) ?? BigInt.zero;
    final costBasis = BigInt.tryParse(position.costBasisRaw) ?? BigInt.zero;
    final total = totalValueRaw;
    final categoryColor = switch (position.category) {
      'REIT' => const Color(0xFF3769C8),
      'Crypto' => const Color(0xFFF49A17),
      'FPI' => const Color(0xFF188A58),
      'Matières premières' => const Color(0xFFBD8117),
      'Actions' => const Color(0xFF7454B8),
      _ => const Color(0xFF667085),
    };
    final icon = switch (position.category) {
      'REIT' => Icons.apartment_rounded,
      'Crypto' => Icons.currency_bitcoin_rounded,
      'FPI' => Icons.account_balance_rounded,
      'Matières premières' => Icons.diamond_outlined,
      'Actions' => Icons.show_chart_rounded,
      _ => Icons.pie_chart_outline_rounded,
    };
    final productSplit = position.productId.split(':');
    return _HoldingPosition(
      id: position.productId,
      category: position.category,
      packId: productSplit.length == 2 ? productSplit.last : '',
      name: position.name,
      subtitle: 'Position Tamleek',
      value: value.toDouble() / math.pow(10, 18),
      costBasis: costBasis.toDouble() / math.pow(10, 18),
      quantity: '${_formatTokenAmount(position.unitsRaw, 18)} parts',
      portfolioTotal: total.toDouble() / math.pow(10, 18),
      icon: icon,
      color: categoryColor,
      monthlyHistory: _monthlyYieldHistoryFor(position.productId),
      annualHistory: _annualYieldHistoryFor(position.productId),
    );
  }

  List<(String, double)> _monthlyYieldHistoryFor(String productId) {
    final credits =
        _monthlyYieldCredits
            .where((credit) => credit['product_id'] == productId)
            .toList()
          ..sort((left, right) {
            final leftDate =
                DateTime.tryParse(left['period_start']?.toString() ?? '') ??
                DateTime(1970);
            final rightDate =
                DateTime.tryParse(right['period_start']?.toString() ?? '') ??
                DateTime(1970);
            return leftDate.compareTo(rightDate);
          });
    final recentCredits = credits.length > 6
        ? credits.sublist(credits.length - 6)
        : credits;
    return recentCredits.map((credit) {
      final period = DateTime.tryParse(credit['period_start'].toString());
      final amountRaw = BigInt.tryParse(credit['amount_raw'].toString());
      if (period == null || amountRaw == null) return ('', 0.0);
      return (
        '${period.month.toString().padLeft(2, '0')}/${period.year}',
        amountRaw.toDouble() / math.pow(10, 18),
      );
    }).toList();
  }

  List<(String, double)> _annualYieldHistoryFor(String productId) {
    final totals = <int, BigInt>{};
    for (final credit in _monthlyYieldCredits) {
      if (credit['product_id'] != productId) continue;
      final period = DateTime.tryParse(
        credit['period_start']?.toString() ?? '',
      );
      final amountRaw = BigInt.tryParse(credit['amount_raw'].toString());
      if (period == null || amountRaw == null) continue;
      totals.update(
        period.year,
        (total) => total + amountRaw,
        ifAbsent: () => amountRaw,
      );
    }
    final entries = totals.entries.toList()
      ..sort((left, right) => right.key.compareTo(left.key));
    return entries
        .map(
          (entry) =>
              (entry.key.toString(), entry.value.toDouble() / math.pow(10, 18)),
        )
        .toList();
  }

  Future<bool?> _showRedemptionConfirmation(_FinancialPosition position) async {
    final message =
        'Demander la revente de ${_formatTokenAmount(position.unitsRaw, 18)} '
        'parts de ${position.name}, valorisées actuellement à '
        '${_formatRawUsdt(position.valueRaw)} ? '
        'Le montant sera crédité après validation.';
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const ValueKey('redemption-confirmation-dialog'),
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
                color: Colors.white.withValues(alpha: 0.9),
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
                            key: const ValueKey('redemption-confirmation-logo'),
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
                              color: const Color(0xFF3769C8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.help_outline_rounded,
                              key: ValueKey('redemption-confirmation-icon'),
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Confirmer la demande de revente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('redemption-cancel-button'),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            shape: const StadiumBorder(),
                            side: const BorderSide(color: Color(0xFFD0D5DD)),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('redemption-confirm-button'),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF18A765),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Confirmer'),
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
    );
  }

  Future<void> _requestRedemption(_FinancialPosition position) async {
    final confirmed = await _showRedemptionConfirmation(position);
    if (confirmed != true) return;
    if (!_hasAuthenticatedInvestmentBackend &&
        widget.redemptionOrderRequestForTesting == null) {
      await _showMessage('Connectez-vous à un compte Tamleek pour continuer.');
      return;
    }

    final requestId = _newFinancialRequestId();
    setState(() => _isSubmittingTransfer = true);
    late final _TransactionReceipt receipt;
    try {
      final redemptionForTesting = widget.redemptionOrderRequestForTesting;
      final result = redemptionForTesting != null
          ? await redemptionForTesting(
              productId: position.productId,
              unitsRaw: position.unitsRaw,
              requestId: requestId,
            )
          : await Supabase.instance.client.rpc(
              'request_investment_redemption',
              params: {
                'p_product_id': position.productId,
                'p_units_raw': position.unitsRaw,
                'p_request_id': requestId,
              },
            );
      final request = _financialRecord(result);
      if (request['status'] != 'pending') {
        throw const FormatException(
          'Le serveur n’a pas confirmé le statut de la revente.',
        );
      }
      if (!mounted) return;
      receipt = _TransactionReceipt(
        reference: requestId,
        date: DateTime.now(),
        operation: 'Demande de revente',
        amount:
            (BigInt.tryParse(position.valueRaw) ?? BigInt.zero).toDouble() /
            math.pow(10, 18),
        details: [
          ('Produit', position.name),
          ('Parts demandées', _formatTokenAmount(position.unitsRaw, 18)),
          (
            'Montant estimé',
            '${_formatTokenAmount(position.valueRaw, 18)} USDT',
          ),
        ],
        status: 'En attente',
        notice:
            'Les parts sont réservées pendant l’examen. Le montant ne sera '
            'crédité qu’après validation de la revente.',
        backgroundAsset: 'assets/usdt_logo.png',
      );
      setState(() => _isSubmittingTransfer = false);
      unawaited(_loadFinancialData());
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingTransfer = false);
      final message =
          error.message.toLowerCase().contains(
            'insufficient available investment units',
          )
          ? 'Certaines parts ne sont plus disponibles. Actualisez votre '
                'portefeuille et réessayez.'
          : _readableBackendError(
              error,
              fallback: 'La demande de revente a échoué. Réessayez dans quelques instants.',
              english: _isEnglish,
            );
      await _showMessage(message);
      return;
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingTransfer = false);
      await _showMessage(
        _readableBackendError(
          error,
          fallback: 'La demande de revente a échoué. Réessayez dans quelques instants.',
          english: _isEnglish,
        ),
      );
      return;
    }
    await _showSuccessConfirmation(
      title: 'Demande de revente enregistrée',
      message:
          'Vos parts sont réservées pendant l’examen. Le montant sera crédité '
          'après validation.',
    );
    if (!mounted) return;
    setState(() => _selectedReceipt = receipt);
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
    final positionIndex = _financialPositions.indexWhere(
      (position) => position.productId == holding.id,
    );
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
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$pnlSign\$${holding.pnl.abs().toStringAsFixed(2)}  '
                    '($pnlSign${holding.pnlPercent.abs().toStringAsFixed(1)}%)',
                    key: ValueKey('holding-pnl-${holding.id}'),
                    style: TextStyle(
                      color: pnlColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (positionIndex >= 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: ValueKey('redeem-${holding.id}'),
                      onPressed: _isSubmittingTransfer
                          ? null
                          : () => _requestRedemption(
                              _financialPositions[positionIndex],
                            ),
                      child: const Text('Demander une revente'),
                    ),
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
                    if (index + 1 < metrics.length) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _holdingMetric(
                          metrics[index + 1].$1,
                          metrics[index + 1].$2,
                          metrics[index + 1].$3,
                        ),
                      ),
                    ],
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
              Text(
                _tr(
                  'Versements mensuels crédités selon le taux de 20 %',
                  'Monthly credits at the fixed 20% rate',
                ),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
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
                'Les données de marché et les rendements sont fournis à titre '
                'informatif et ne constituent pas une garantie.',
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
    const categories = [
      (id: 'REIT', label: 'REIT', color: Color(0xFF3769C8)),
      (id: 'Crypto', label: 'Crypto', color: Color(0xFFF49A17)),
      (id: 'FPI', label: 'FPI', color: Color(0xFF188A58)),
      (
        id: 'Matières premières',
        label: 'Matières premières',
        color: Color(0xFFBD8117),
      ),
      (id: 'Actions', label: 'Actions', color: Color(0xFF805AD5)),
      (id: 'Autres', label: 'Autres', color: Color(0xFF667085)),
    ];
    final valuesByCategory = {
      for (final category in categories) category.id: BigInt.zero,
    };
    for (final position in _financialPositions) {
      final valueRaw = BigInt.tryParse(position.valueRaw);
      if (valueRaw == null || valueRaw <= BigInt.zero) continue;
      final categoryId = valuesByCategory.containsKey(position.category)
          ? position.category
          : 'Autres';
      valuesByCategory[categoryId] = valuesByCategory[categoryId]! + valueRaw;
    }
    final totalValueRaw = valuesByCategory.values.fold<BigInt>(
      BigInt.zero,
      (total, value) => total + value,
    );
    final allocations =
        <
          ({
            String id,
            String label,
            Color color,
            BigInt valueRaw,
            double share,
            int percent,
            int flex,
          })
        >[
          for (final category in categories)
            if (valuesByCategory[category.id]! > BigInt.zero)
              (
                id: category.id,
                label: category.label,
                color: category.color,
                valueRaw: valuesByCategory[category.id]!,
                share:
                    valuesByCategory[category.id]!.toDouble() /
                    totalValueRaw.toDouble(),
                percent:
                    ((valuesByCategory[category.id]! * BigInt.from(100) +
                                totalValueRaw ~/ BigInt.from(2)) ~/
                            totalValueRaw)
                        .toInt(),
                flex:
                    (valuesByCategory[category.id]! *
                            BigInt.from(10000) ~/
                            totalValueRaw)
                        .toInt(),
              ),
        ];
    final legendCategories = allocations.isEmpty
        ? categories
              .where((category) => category.id != 'Autres')
              .map(
                (category) => (
                  id: category.id,
                  label: category.label,
                  color: category.color,
                ),
              )
              .toList()
        : allocations
              .map(
                (allocation) => (
                  id: allocation.id,
                  label: allocation.label,
                  color: allocation.color,
                ),
              )
              .toList();

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
                      painter: _AllocationDonutPainter([
                        for (final allocation in allocations)
                          (allocation.share, allocation.color),
                      ]),
                    ),
                    Text(
                      allocations.isEmpty ? '—' : '100%',
                      style: TextStyle(
                        color: _ink,
                        fontSize: allocations.isEmpty ? 20 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  allocations.isEmpty
                      ? _tr(
                          'La répartition apparaîtra lorsque des positions '
                              'seront disponibles.',
                          'Your allocation will appear when you hold '
                              'investment positions.',
                        )
                      : _tr(
                          'Répartition calculée selon la valeur de vos '
                              'positions détenues.',
                          'Allocation based on the value of your held '
                              'positions.',
                        ),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: const ValueKey('holdings-allocation-bar'),
              height: 14,
              color: const Color(0xFFE7EAF0),
              child: allocations.isEmpty
                  ? null
                  : Row(
                      children: [
                        for (final allocation in allocations)
                          Expanded(
                            flex: allocation.flex > 0 ? allocation.flex : 1,
                            child: Container(
                              key: ValueKey(
                                'holdings-allocation-segment-${allocation.id}',
                              ),
                              color: allocation.color,
                            ),
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
              for (final category in legendCategories)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${category.id == 'Autres' ? _tr('Autres', 'Other') : category.label}'
                      '${allocations.isEmpty ? '' : ' ${allocations.firstWhere((allocation) => allocation.id == category.id).percent}%'}',
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

  Widget _buildNotificationsPage() {
    final unreadCount = _userNotifications
        .where((notification) => notification['read_at'] == null)
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('notifications-back'),
              tooltip: _tr('Retour', 'Back'),
              onPressed: _closeNotifications,
              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
            ),
            Expanded(
              child: Text(
                _tr('Notifications', 'Notifications'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('notifications-mark-all-read'),
              onPressed: unreadCount == 0 ? null : _markAllNotificationsRead,
              child: Text(
                _tr('Tout marquer comme lu', 'Mark all as read'),
                style: const TextStyle(fontSize: 11),
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
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        if (_userNotifications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 44,
                  color: Color(0xFF98A2B3),
                ),
                const SizedBox(height: 10),
                Text(
                  _tr('Aucune notification', 'No notifications'),
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _tr(
                    'Vous n’avez aucune notification pour le moment.',
                    'You have no notifications right now.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ..._userNotifications.map((notification) {
            final id = notification['id'] as String;
            final title = notification['title'] as String? ?? '';
            final message = notification['message'] as String? ?? '';
            final unread = notification['read_at'] == null;
            return _notificationCard(
              id: id,
              title: title,
              message: message,
              time: _notificationTime(notification['created_at']),
              unread: unread,
              onTap: () => _markNotificationRead(id),
            );
          }),
      ],
    );
  }

  void _markNotificationRead(String id) {
    setState(() {
      _userNotifications = _userNotifications.map((notification) {
        if (notification['id'] != id) return notification;
        return {...notification, 'read_at': DateTime.now().toIso8601String()};
      }).toList();
    });
  }

  void _markAllNotificationsRead() {
    final readAt = DateTime.now().toIso8601String();
    setState(() {
      _userNotifications = _userNotifications
          .map((notification) => {...notification, 'read_at': readAt})
          .toList();
    });
  }

  String _notificationTime(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    final elapsed = DateTime.now().difference(date.toLocal());
    if (elapsed.inMinutes < 1) return _tr('À l’instant', 'Just now');
    if (elapsed.inHours < 1) {
      return _tr(
        'Il y a ${elapsed.inMinutes} min',
        '${elapsed.inMinutes} min ago',
      );
    }
    if (elapsed.inDays < 1) {
      return _tr('Il y a ${elapsed.inHours} h', '${elapsed.inHours} h ago');
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _notificationCard({
    String? id,
    required String title,
    required String message,
    required String time,
    required bool unread,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: unread ? const Color(0xFFEBF0FA) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('notification-${id ?? title}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
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
                    const Text(
                      'Cette information est enregistrée sur cet appareil.',
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
                                  message:
                                      'Vos informations ont été enregistrées '
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
      path: _supportEmail,
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
          child: Row(
            children: [
              const Icon(
                Icons.alternate_email_rounded,
                color: Color(0xFF314A70),
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  _supportEmail,
                  style: const TextStyle(
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
        const SizedBox(height: 18),
        Text(
          _tr('DOCUMENTS JURIDIQUES', 'LEGAL DOCUMENTS'),
          style: const TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _profileInfoCard(
          key: const ValueKey('help-terms-document'),
          icon: Icons.description_outlined,
          imageAsset: 'assets/tamleek_logo.jpg',
          imageKey: const ValueKey('help-terms-document-logo'),
          label: _tr('Conditions d’utilisation', 'Terms of Use'),
          value: _tr('Lire le document PDF', 'Read the PDF document'),
          onTap: () => _openExternalLink(
            _legalDocumentUri('conditions-utilisation.pdf').toString(),
          ),
        ),
        _profileInfoCard(
          key: const ValueKey('help-privacy-document'),
          icon: Icons.privacy_tip_outlined,
          imageAsset: 'assets/tamleek_logo.jpg',
          imageKey: const ValueKey('help-privacy-document-logo'),
          label: _tr('Politique de confidentialité', 'Privacy Policy'),
          value: _tr('Lire le document PDF', 'Read the PDF document'),
          onTap: () => _openExternalLink(
            _legalDocumentUri('politique-confidentialite.pdf').toString(),
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
              ? _tr('En attente', 'Pending')
              : _tr('Non vérifié', 'Not verified'),
          onTap: _showKycInformation,
        ),
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
          onTap: () => _openExternalLink(_websiteUrl),
        ),
        _profileInfoCard(
          icon: Icons.ondemand_video_rounded,
          label: 'YouTube',
          value: '@tamleekrealestateco5031',
          onTap: () => _openExternalLink(_youtubeUrl),
        ),
        _profileInfoCard(
          icon: Icons.facebook_rounded,
          label: 'Facebook',
          value: _tr('Page officielle de Tamleek', 'Official Tamleek page'),
          onTap: () => _openExternalLink(_facebookUrl),
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
          icon: Icons.ios_share_rounded,
          imageAsset: 'assets/tamleek_share_image.png',
          imageKey: const ValueKey('profile-share-logo'),
          label: _tr('Partager Tamleek', 'Share Tamleek'),
          value: _tr(
            'Faites découvrir Tamleek à vos proches.',
            'Invite others to discover Tamleek.',
          ),
          onTap: _shareTamleekApp,
        ),
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
          onTap: () {
            _openNotifications();
          },
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
    String? imageAsset,
    Key? imageKey,
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
          if (imageAsset == null)
            Icon(icon, color: const Color(0xFF314A70), size: 21)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                imageAsset,
                key: imageKey,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
              ),
            ),
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
                    if (index == 0) {
                      _returnToHome();
                      return;
                    }
                    setState(() {
                      _selectedNavigation = index;
                      _showAllWalletActivity = false;
                      if (index != 3) {
                        _showSupportEmail = false;
                        _showAuthorizationPage = false;
                        _showHelpInfoPage = false;
                      }
                      if (index != 2) _selectedHoldingDetail = null;
                    });
                    if (index == 1 || index == 2) {
                      unawaited(_loadFinancialData());
                    }
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
