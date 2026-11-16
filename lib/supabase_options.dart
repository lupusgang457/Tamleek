class TamleekSupabaseOptions {
  static const url = String.fromEnvironment('TAMLEEK_SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'TAMLEEK_SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
