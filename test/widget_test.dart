import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tamleek/main.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'tamleek.registration.complete': true,
    }),
  );

  testWidgets(
    'registration page follows the supplied design and saves locally',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      setMobileViewport(tester);
      tester.view.viewPadding = const FakeViewPadding(top: 28);

      await tester.pumpWidget(const TamleekApp());
      await tester.pumpAndSettle();

      expect(find.text('Inscription'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('signup-hero'))).dy,
        0,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('signup-logo'))).dy,
        greaterThanOrEqualTo(28),
      );
      expect(
        find.byKey(const ValueKey('signup-hero-copy-card')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('signup-back-button')), findsNothing);
      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(find.byKey(const ValueKey('signup-google-button')), findsNothing);
      expect(find.byKey(const ValueKey('signup-name-input')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('signup-confirm-password-input')),
        findsOneWidget,
      );
      final signupButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('signup-submit')),
      );
      expect(signupButton.style?.elevation?.resolve({}), 0);
      expect(signupButton.style?.shadowColor?.resolve({}), Colors.transparent);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('signup-submit')),
          matching: find.byIcon(Icons.arrow_forward_rounded),
        ),
        findsNothing,
      );
      final signupLoginText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('signup-login-button')),
          matching: find.text('Se connecter'),
        ),
      );
      expect(
        signupLoginText.style?.decoration,
        isNot(TextDecoration.underline),
      );
      final signupOverlay = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          );
      expect(signupOverlay.value.statusBarColor, Colors.transparent);

      await tester.enterText(
        find.byKey(const ValueKey('signup-name-input')),
        'Awa Test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('signup-email-input')),
        'awa@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('signup-phone-input')),
        '+971501234567',
      );
      await tester.enterText(
        find.byKey(const ValueKey('signup-password-input')),
        'Tamleek2026!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('signup-confirm-password-input')),
        'Different2026!',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('signup-terms-checkbox')),
      );
      await tester.tap(find.byKey(const ValueKey('signup-terms-checkbox')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('signup-submit')));
      await tester.tap(find.byKey(const ValueKey('signup-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Les mots de passe ne correspondent pas.'),
        findsOneWidget,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('tamleek.registration.complete'), isNull);
      await tester.enterText(
        find.byKey(const ValueKey('signup-confirm-password-input')),
        'Tamleek2026!',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('signup-submit')));
      await tester.tap(find.byKey(const ValueKey('signup-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Tamleek'), findsOneWidget);
      expect(find.byKey(const ValueKey('signup-submit')), findsNothing);
      expect(preferences.getBool('tamleek.registration.complete'), isTrue);
      expect(preferences.getString('tamleek.profile.name'), 'Awa Test');
      expect(preferences.getString('tamleek.profile.email'), 'awa@example.com');
      expect(preferences.getString('tamleek.profile.phone'), '+971501234567');
      expect(preferences.getString('tamleek.profile.password'), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('normal app starts locally without Supabase configuration', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    setMobileViewport(tester);

    await tester.pumpWidget(const TamleekApp());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Configuration Supabase manquante'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('signup-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup and login pages are connected', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    setMobileViewport(tester);
    tester.view.viewPadding = const FakeViewPadding(top: 28);

    await pumpTamleekApp(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('signup-login-button')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('login-hero'))).dy, 0);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('login-logo'))).dy,
      greaterThanOrEqualTo(28),
    );
    expect(find.byKey(const ValueKey('login-hero-copy-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('login-identifier-input')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('login-password-input')), findsOneWidget);
    final loginButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('login-submit')),
    );
    expect(loginButton.style?.elevation?.resolve({}), 0);
    expect(loginButton.style?.shadowColor?.resolve({}), Colors.transparent);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('login-submit')),
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsNothing,
    );
    final loginCreateAccountText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('login-create-account')),
        matching: find.text('Créer un compte'),
      ),
    );
    expect(
      loginCreateAccountText.style?.decoration,
      isNot(TextDecoration.underline),
    );

    expect(find.byKey(const ValueKey('login-google-button')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('login-identifier-input')),
      'awa@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-input')),
      'Tamleek2026!',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Connexion indisponible'), findsOneWidget);
    expect(
      find.textContaining('--dart-define-from-file=supabase_config.json'),
      findsOneWidget,
    );
    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('login-create-account')),
    );
    await tester.tap(find.byKey(const ValueKey('login-create-account')));
    await tester.pumpAndSettle();
    expect(find.text('Inscription'), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-back-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('investment dashboard renders', (WidgetTester tester) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);

    expect(find.text('Créer mon compte Tamleek'), findsNothing);
    expect(find.text('Se connecter'), findsNothing);
    expect(find.text('Tamleek'), findsOneWidget);
    final appLogo = find.byKey(const ValueKey('app-logo'));
    expect(appLogo, findsOneWidget);
    expect(tester.getSize(appLogo), const Size(40, 40));
    expect(
      (tester.widget<Image>(appLogo).image as AssetImage).assetName,
      'assets/tamleek_logo.jpg',
    );
    expect(find.text('Revenus immobiliers\npassifs'), findsOneWidget);
    expect(find.text('Fonds REIT'), findsNWidgets(2));
    expect(find.text('5 packs immobiliers à découvrir'), findsOneWidget);
    expect(find.text('20 % / an · 1,67 % / mois'), findsNothing);
    expect(find.text('Estimation indicative, non garantie'), findsNothing);
    expect(find.text('+8.5% ▲'), findsNothing);
    expect(find.byKey(const ValueKey('investment-image-reit')), findsOneWidget);
    expect(find.text('Voir tout'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-category-Action')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Cryptomonnaies'), findsNWidgets(2));
    expect(find.text('FPI'), findsNWidgets(2));
    expect(find.text('5 packs d’actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home logo no longer opens an animation', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('app-logo')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tamleek-animation-dialog')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tamleek logo and name fit on a narrow phone screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTamleekApp(tester);

    expect(find.byKey(const ValueKey('app-logo')), findsOneWidget);
    expect(find.text('Tamleek'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters investments', (WidgetTester tester) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.enterText(find.byType(TextField), 'Bitcoin');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('crypto-category-card')), findsOneWidget);
    expect(find.text('5 packs crypto'), findsOneWidget);
    expect(find.text('Bitcoin (BTC)'), findsNothing);

    await tester.enterText(find.byType(TextField), 'introuvable');
    await tester.pumpAndSettle();

    expect(find.text('Aucun actif trouvé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FPI uses the supplied image', (WidgetTester tester) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.text('FPI').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('investment-image-fpi')), findsOneWidget);
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const ValueKey('investment-image-fpi')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/fpi.jpg',
    );
    expect(find.text('Voir tout'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('investment chips filter and reset asset categories', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.ensureVisible(find.text('Crypto'));
    await tester.tap(find.text('Crypto'));
    await tester.pumpAndSettle();

    expect(find.text('5 packs crypto'), findsOneWidget);
    expect(find.text('Fonds REIT'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Crypto'));
    await tester.pumpAndSettle();

    expect(find.text('5 packs immobiliers à découvrir'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-category-FPI')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('5 packs immobiliers européens'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-category-Action')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('5 packs d’actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('REIT packs open details with indicative return and holdings', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);

    expect(find.text('Commerce de proximité'), findsNothing);
    final reitCategoryCard = find.byKey(const ValueKey('reit-category-card'));
    expect(
      find.descendant(
        of: reitCategoryCard,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: reitCategoryCard, matching: find.text('Investir')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reit-category-invest-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reit-packs-page')), findsOneWidget);

    for (final pack in [
      'Commerce de proximité',
      'Résidentiel',
      'Santé',
      'Self-storage',
      'ETF clé en main mondial',
    ]) {
      expect(find.text(pack), findsOneWidget);
    }
    expect(find.textContaining('20 % / an · 1,67 % / mois'), findsNothing);
    expect(find.text('Estimation indicative, non garantie'), findsNothing);
    expect(find.text('Investir'), findsNWidgets(5));

    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-commerce')));
    await tester.pumpAndSettle();

    expect(find.text('Commerce de proximité'), findsOneWidget);
    final detailImageSize = tester.getSize(
      find.byKey(const ValueKey('reit-pack-detail-image')),
    );
    expect(detailImageSize.width, 430);
    expect(detailImageSize.height, 248);
    expect(
      find.byKey(const ValueKey('reit-pack-overview-card')),
      findsOneWidget,
    );
    expect(find.text('Fiche informative'), findsOneWidget);
    expect(find.byKey(const ValueKey('reit-pack-return-card')), findsNothing);
    expect(find.text('Rendement estimé'), findsNothing);
    expect(find.textContaining('20 % / an · 1,67 % / mois'), findsNothing);
    expect(find.textContaining('166,67 \$'), findsNothing);
    for (final name in ['Realty Income', 'Agree Realty', 'NNN REIT']) {
      final holding = find.text(name);
      await scrollUntilBuilt(tester, holding);
      expect(holding, findsOneWidget);
    }
    expect(find.text('Fiscalité'), findsNothing);
    expect(find.text('À savoir'), findsNothing);
    expect(find.text('55 \$'), findsNothing);
    expect(
      find.byKey(const ValueKey('reit-pack-invest-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('investment-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('investment-owned-assets')), findsNothing);
    expect(
      find.byKey(const ValueKey('investment-resale-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('investment-selected-pack')),
      findsOneWidget,
    );
    expect(find.text('Montant à investir'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('investment-continue-button')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '9',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('investment-continue-button')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '8251',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('investment-continue-button')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '100',
    );
    await tester.pumpAndSettle();
    expect(find.text('\$100.00'), findsOneWidget);
    expect(find.text('20 %'), findsOneWidget);
    expect(find.text('791.61 %'), findsOneWidget);
    expect(find.text('\$20.00'), findsOneWidget);
    expect(find.text('\$891.61'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('investment-continue-button')),
          )
          .onPressed,
      isNotNull,
    );
    final modeSwitch = find.byKey(const ValueKey('investment-mode-switch'));
    expect(tester.widget<Switch>(modeSwitch).value, isFalse);
    await tester.tap(modeSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(modeSwitch).value, isTrue);
    expect(find.text('\$1,000.00'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('investment-yield-projection')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('investment-whole-minimum-note')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '999',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('investment-continue-button')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '1500',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('investment-continue-button')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '1000',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('investment-continue-button')),
          )
          .onPressed,
      isNotNull,
    );
    await scrollUntilBuilt(tester, find.text('\$200.00'));
    expect(find.text('\$200.00'), findsOneWidget);
    await scrollUntilBuilt(tester, find.text('\$8,916.10'));
    expect(find.text('\$8,916.10'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('investment-amount-summary')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(modeSwitch);
    await tester.tap(modeSwitch);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '100',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('investment-continue-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('success-confirmation-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('success-confirmation-continue')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('receipt-scalloped-clip')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('receipt-banner-image')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('receipt-watermark-image')),
      findsOneWidget,
    );
    final shareButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('receipt-share-button')),
    );
    expect(shareButton.style?.shape?.resolve({}), isA<CircleBorder>());
    expect(find.text('Demande d’investissement'), findsOneWidget);
    expect(find.textContaining('Non exécuté'), findsOneWidget);
    expect(find.text('Commerce de proximité'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('receipt-back')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('investment-page')),
      const Offset(0, 1600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('investment-page-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('investment-page')), findsNothing);
    expect(
      find.byKey(const ValueKey('reit-pack-detail-commerce')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-back')));
    await tester.pumpAndSettle();
    expect(find.text('Commerce de proximité'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-packs-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reit-category-card')), findsOneWidget);
  }, skip: true);

  testWidgets('investment CTA opens a form without creating a local order', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('reit-category-invest-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-commerce')));
    await tester.pumpAndSettle();
    expect(find.text('Fiche informative'), findsOneWidget);

    final subscribeButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('reit-pack-invest-button')),
    );
    expect(subscribeButton.onPressed, isNotNull);
    expect(find.text('Continuer'), findsOneWidget);
    expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('investment-page')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '10',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('investment-continue-button')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'zero balance still allows fractional and whole investment selection',
    (WidgetTester tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: InvestmentPage(
            initialInvestmentTermsForTesting: (
              balanceRaw: '0',
              unitPriceRaw: '1000000000000000000000',
            ),
            investmentOrderRequestForTesting:
                ({
                  required String productId,
                  required String amountRaw,
                  required String requestId,
                }) async {
                  throw PostgrestException(
                    message: 'Insufficient available USDT balance.',
                  );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('reit-category-invest-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reit-pack-invest-commerce')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reit-pack-invest-button')));
      await tester.pumpAndSettle();

      final modeSwitch = find.byKey(const ValueKey('investment-mode-switch'));
      expect(tester.widget<Switch>(modeSwitch).onChanged, isNotNull);
      await tester.enterText(
        find.byKey(const ValueKey('investment-amount-input')),
        '100',
      );
      await tester.pumpAndSettle();
      expect(find.text('Jusqu’à 20 %'), findsOneWidget);
      expect(find.text('\$20,00'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('investment-continue-button')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.ensureVisible(modeSwitch);
      await tester.tap(modeSwitch);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('investment-amount-input')),
        '1000',
      );
      await tester.pumpAndSettle();
      expect(find.text('\$200,00'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('investment-continue-button')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('investment-continue-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('investment-continue-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('app-information-dialog')),
        findsOneWidget,
      );
      expect(find.text('Solde insuffisant'), findsOneWidget);
      expect(find.textContaining('Rechargez votre compte'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('success-confirmation-dialog')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FPI category lists five packs and opens FPI detail', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('fpi-category-invest-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fpi-packs-page')), findsOneWidget);
    for (final pack in [
      'Commerce de proximité',
      'Résidentiel',
      'Santé',
      'Bureaux',
      'Diversifié européen',
    ]) {
      expect(find.text(pack), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('fpi-pack-invest-commerce')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fpi-pack-detail-commerce')),
      findsOneWidget,
    );
    expect(find.text('Carmila'), findsOneWidget);
    expect(find.text('Mercialys'), findsOneWidget);
    expect(find.text('Klépierre'), findsOneWidget);
    expect(find.text('FPI'), findsWidgets);
    expect(find.text('Fiche informative'), findsOneWidget);
    expect(find.textContaining('20 % / an · 1,67 % / mois'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crypto category lists five packs and opens crypto details', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('crypto-category-invest-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('crypto-packs-page')), findsOneWidget);
    for (final pack in [
      'Majors',
      'Layer 1 alternatifs',
      'DeFi et infrastructure',
      'Memecoins et haute volatilité',
      'Diversifié crypto',
    ]) {
      expect(find.text(pack), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('crypto-pack-invest-majors')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('crypto-pack-detail-majors')),
      findsOneWidget,
    );
    expect(find.text('CRYPTO'), findsOneWidget);
    expect(find.text('Fiche informative'), findsOneWidget);
    for (final holding in {
      'BTC': 'Bitcoin',
      'ETH': 'Ethereum',
      'SOL': 'Solana',
      'OKB': 'OKX',
      'BNB': 'BNB',
    }.entries) {
      final card = find.byKey(ValueKey('reit-holding-${holding.key}'));
      await scrollUntilBuilt(tester, card);
      expect(
        find.descendant(of: card, matching: find.text(holding.value)).first,
        findsOneWidget,
      );
    }
    for (final ticker in ['ETH', 'SOL', 'BNB']) {
      await scrollUntilBuilt(
        tester,
        find.byKey(ValueKey('reit-holding-$ticker')),
      );
      final card = find.byKey(ValueKey('reit-holding-$ticker'));
      expect(
        find.descendant(of: card, matching: find.byType(Image)),
        findsNothing,
      );
      final icon = tester.widget<Icon>(
        find.byKey(ValueKey('pack-holding-icon-$ticker')),
      );
      expect(icon.icon, Icons.apartment_rounded);
    }
    expect(find.textContaining('risque élevé de perte'), findsOneWidget);
    expect(find.text('Rendement estimé'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('crypto-packs-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('crypto-packs-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('crypto-category-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commodity category lists five packs and opens pack details', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(
      find.byKey(const ValueKey('commodity-category-invest-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('commodity-packs-page')), findsOneWidget);
    for (final pack in [
      'Métaux précieux',
      'Énergie',
      'Agricoles',
      'Industriels',
      'Diversifié multi-matières',
    ]) {
      expect(find.text(pack), findsOneWidget);
    }

    await tester.tap(
      find.byKey(const ValueKey('commodity-pack-invest-metaux-precieux')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('commodity-pack-detail-metaux-precieux')),
      findsOneWidget,
    );
    expect(find.text('Diversification matières premières'), findsOneWidget);
    expect(find.text('Or'), findsOneWidget);
    expect(find.text('Argent'), findsOneWidget);
    expect(find.text('Platine'), findsOneWidget);
    expect(find.text('Palladium'), findsOneWidget);
    expect(find.text('Fiche informative'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global REIT ETF details show regional allocations', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('reit-category-invest-button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('reit-pack-mondial')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-mondial')));
    await tester.pumpAndSettle();

    expect(find.textContaining('20 % / an · 1,67 % / mois'), findsNothing);
    for (final entry in {
      'VNQ': '40 %',
      'IWDP': '30 %',
      'Asie-Pacifique': '20 %',
      'SCHH': '10 %',
    }.entries) {
      final holding = find.byKey(ValueKey('reit-holding-${entry.key}'));
      await scrollUntilBuilt(tester, holding);
      expect(
        find.descendant(
          of: holding,
          matching: find.textContaining(entry.value),
        ),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('investment-owned-assets')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('investment-owned-assets')),
        matching: find.text('ETF clé en main mondial'),
      ),
      findsOneWidget,
    );
    final resaleButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('investment-resale-button')),
    );
    expect(
      resaleButton.style?.backgroundColor?.resolve({}),
      const Color(0xFFB3261E),
    );
    await tester.tap(find.byKey(const ValueKey('investment-resale-button')));
    await tester.pumpAndSettle();
    expect(find.text('Revendre ETF clé en main mondial ?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('investment-resale-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('success-confirmation-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('success-confirmation-continue')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-page')), findsOneWidget);
    expect(find.text('Demande de revente du pack'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('receipt-ticket')),
        matching: find.text('ETF clé en main mondial'),
      ),
      findsOneWidget,
    );
    expect(find.text('\$90.00'), findsOneWidget);
    expect(find.text('\$1,710.00'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  }, skip: true);

  testWidgets('action chip filters the action section', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.ensureVisible(find.text('Action').first);
    await tester.tap(find.text('Action').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('action-category-card')), findsOneWidget);
    expect(find.text('5 packs d’actions'), findsOneWidget);
    expect(find.text('Bitcoin (BTC)'), findsNothing);
    expect(find.text('FPI Performance'), findsNothing);
    expect(
      find.byKey(const ValueKey('investment-image-action')),
      findsOneWidget,
    );
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const ValueKey('investment-image-action')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/stocks.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('action category lists five packs and opens stock detail', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action-category-invest-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('action-packs-page')), findsOneWidget);
    for (final pack in [
      'Méga-capitalisations technologiques',
      'Santé et défensif',
      'Finance et énergie',
      'Industrie et consommation cyclique',
      'Diversifié actions mondial',
    ]) {
      expect(find.text(pack), findsOneWidget);
    }

    await tester.tap(
      find.byKey(const ValueKey('action-pack-invest-mega-tech')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('action-pack-detail-mega-tech')),
      findsOneWidget,
    );
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('Fiche informative'), findsOneWidget);
    for (final holding in {
      'AAPL': 'Apple',
      'MSFT': 'Microsoft',
      'NVDA': 'Nvidia',
      'GOOGL': 'Alphabet',
      'AMZN': 'Amazon',
      'META': 'Meta',
      'TSLA': 'Tesla',
    }.entries) {
      final card = find.byKey(ValueKey('reit-holding-${holding.key}'));
      await scrollUntilBuilt(tester, card);
      expect(
        find.descendant(of: card, matching: find.text(holding.value)),
        findsOneWidget,
      );
    }
    expect(find.textContaining('risque élevé de perte'), findsOneWidget);
    expect(find.text('Rendement estimé'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('action-packs-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('action-packs-back')));
    await tester.pumpAndSettle();
    await scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('action-category-card')),
    );
    expect(find.byKey(const ValueKey('action-category-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home featured cards advance automatically', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    expect(
      find.byKey(const ValueKey('home-featured-image-reit')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(
      find.text('Investissez dans\nles fonds immobiliers'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-featured-image-fpi')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('homepage categories follow the requested order', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    final orderedKeys = [
      'home-category-Fonds REIT',
      'home-category-FPI',
      'home-category-Matières premières',
      'home-category-Cryptomonnaies',
      'home-category-Action',
    ];
    final scrollOffsets = <double>[];
    for (final key in orderedKeys) {
      final finder = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      scrollOffsets.add(Scrollable.of(tester.element(finder)).position.pixels);
    }

    expect(
      scrollOffsets.asMap().entries.every(
        (entry) =>
            entry.key == scrollOffsets.length - 1 ||
            entry.value <= scrollOffsets[entry.key + 1],
      ),
      isTrue,
      reason: scrollOffsets.toString(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification bell opens notifications page', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Aucune notification'), findsOneWidget);
    expect(find.text('Votre portefeuille est à jour'), findsNothing);
    expect(find.text('Suivez le marché crypto'), findsNothing);
    expect(
      find.text('Vous n’avez aucune notification pour le moment.'),
      findsOneWidget,
    );
    expect(find.text('Tout marquer comme lu'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('notifications-mark-all-read')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile success popup plays alert sound without demo notices', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);
    final platformChannel = SystemChannels.platform;
    var alertSoundCount = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      platformChannel,
      (call) async {
        if (call.method == 'SystemSound.play' &&
            call.arguments == SystemSoundType.alert.toString()) {
          alertSoundCount++;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        platformChannel,
        null,
      ),
    );

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-info-Nom complet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-input')),
      'Awa Test',
    );
    await tester.tap(find.byKey(const ValueKey('profile-save-button')));
    await tester.pumpAndSettle();
    expect(alertSoundCount, 1);
    await tester.tap(
      find.byKey(const ValueKey('success-confirmation-continue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await tester.pumpAndSettle();

    expect(alertSoundCount, 1);
    expect(find.text('Aucune notification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile replaces notifications in bottom navigation', (
    WidgetTester tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    String? launchedUrl;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launchedUrl =
            (call.arguments as Map<Object?, Object?>)['url'] as String;
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Membre Tamleek'), findsOneWidget);
    expect(find.text('INFORMATIONS DU COMPTE'), findsNothing);
    expect(find.text('Se déconnecter'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-info-Nom complet')),
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsOneWidget,
    );
    await scrollUntilBuilt(tester, find.text('CANAUX OFFICIELS'));
    expect(find.text('CANAUX OFFICIELS'), findsOneWidget);
    expect(find.text('Site internet'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    for (final (label, url) in [
      ('Site internet', 'https://www.tamleek.ae/'),
      ('Facebook', 'https://www.facebook.com/share/19zxueAV7K/'),
      (
        'YouTube',
        'https://youtube.com/@tamleekrealestateco5031?si=coJCsHz5c0GJH_q7',
      ),
    ]) {
      final linkCard = find.byKey(ValueKey('profile-info-$label'));
      await tester.ensureVisible(linkCard);
      expect(
        find.descendant(
          of: linkCard,
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsNothing,
      );
      await tester.tap(linkCard);
      await tester.pumpAndSettle();
      expect(launchedUrl, url);
    }
    expect(find.text('NOTRE EMPLACEMENT'), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-headquarters-card')),
      findsNothing,
    );
    final centerEntries = [
      'profile-info-Partager Tamleek',
      'profile-info-Mes notifications',
      'profile-info-Support par e-mail',
      'profile-info-Aide et informations',
      'profile-info-Autorisation',
    ];
    for (final entryKey in centerEntries) {
      await scrollUntilBuilt(tester, find.byKey(ValueKey(entryKey)));
      expect(find.byKey(ValueKey(entryKey)), findsOneWidget);
    }
    final shareEntry = find.byKey(
      const ValueKey('profile-info-Partager Tamleek'),
    );
    final languageEntry = find.byKey(const ValueKey('profile-language'));
    await scrollUntilBuilt(tester, languageEntry);
    expect(find.byKey(const ValueKey('profile-share-logo')), findsOneWidget);
    expect(
      tester.getRect(shareEntry).bottom,
      lessThanOrEqualTo(tester.getRect(languageEntry).top),
    );
    final notificationsEntry = find.byKey(
      const ValueKey('profile-info-Mes notifications'),
    );
    await scrollUntilBuilt(tester, notificationsEntry);
    await tester.ensureVisible(notificationsEntry);
    await tester.tap(notificationsEntry);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home profile avatar opens the profile page', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Membre Tamleek'), findsOneWidget);
    expect(find.text('INFORMATIONS DU COMPTE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language can be changed from Centre and is saved', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();

    final languageCard = find.byKey(const ValueKey('profile-language'));
    final notificationsCard = find.byKey(
      const ValueKey('profile-info-Mes notifications'),
    );
    await scrollUntilBuilt(tester, notificationsCard);
    await tester.ensureVisible(notificationsCard);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(languageCard).dy,
      lessThan(tester.getTopLeft(notificationsCard).dy),
    );
    await scrollUntilBuilt(tester, languageCard);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(languageCard);
    await tester.pumpAndSettle();
    await tester.tap(languageCard);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('language-picker-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('language-option-en')));
    await tester.pumpAndSettle();

    var preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('tamleek.language'), 'en');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.text('MY INFORMATION'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Search assets...'), findsOneWidget);
    expect(find.text('REIT funds'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();
    await scrollUntilBuilt(tester, languageCard);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(languageCard);
    await tester.pumpAndSettle();
    await tester.tap(languageCard);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-option-fr')));
    await tester.pumpAndSettle();

    preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('tamleek.language'), 'fr');
    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.text('MES INFORMATIONS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile opens email support and prepares a mail draft', (
    WidgetTester tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    MethodCall? launchCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      launchCall = call;
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();

    final supportButton = find.byKey(
      const ValueKey('profile-info-Support par e-mail'),
    );
    await scrollUntilBuilt(tester, supportButton);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(supportButton);
    await tester.pumpAndSettle();
    await tester.tap(supportButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-email-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('support-email-address-card')),
      findsOneWidget,
    );
    expect(find.text('tamleek.contact@gmail.com'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('support-email-compose')));
    await tester.pumpAndSettle();

    expect(launchCall?.method, 'launch');
    final arguments = launchCall!.arguments as Map<Object?, Object?>;
    expect(
      arguments['url'],
      startsWith('mailto:tamleek.contact@gmail.com?subject=Assistance+Tamleek'),
    );

    await tester.tap(find.byKey(const ValueKey('support-email-back')));
    await tester.pumpAndSettle();
    expect(find.text('Mon profil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile requires an authenticated account to submit KYC', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();

    final kycCard = find.byKey(const ValueKey('profile-kyc-status'));
    await scrollUntilBuilt(tester, kycCard);
    expect(kycCard, findsOneWidget);
    expect(find.text('Non vérifié'), findsOneWidget);
    expect(find.byKey(const ValueKey('kyc-verified-badge')), findsNothing);

    await tester.tap(kycCard);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kyc-form-sheet')), findsNothing);
    expect(
      find.textContaining('Connectez-vous à un compte Tamleek'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('app-feedback-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kyc-form-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('investment above \$5000 requires all KYC information', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('reit-category-invest-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-commerce')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-button')));
    await tester.pumpAndSettle();

    final continueButton = find.byKey(
      const ValueKey('investment-continue-button'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '5001',
    );
    await tester.pumpAndSettle();
    expect(find.text('Compléter le KYC requis'), findsOneWidget);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('kyc-form-sheet')), findsOneWidget);
    for (final fieldKey in [
      'kyc-first-name-input',
      'kyc-last-name-input',
      'kyc-birth-year-input',
      'kyc-birth-place-input',
      'kyc-city-input',
      'kyc-department-input',
      'kyc-country-input',
      'kyc-identity-number-input',
    ]) {
      await scrollKycUntilVisible(tester, find.byKey(ValueKey(fieldKey)));
      expect(find.byKey(ValueKey(fieldKey)), findsOneWidget);
    }

    await scrollKycUntilVisible(
      tester,
      find.byKey(const ValueKey('kyc-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('kyc-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Ce champ est obligatoire.'), findsNWidgets(7));
    expect(find.text('Saisissez une année valide.'), findsOneWidget);
    for (final entry in {
      'kyc-first-name-input': 'Awa',
      'kyc-last-name-input': 'Test',
      'kyc-birth-year-input': '1995',
      'kyc-birth-place-input': 'Lomé',
      'kyc-city-input': 'Lomé',
      'kyc-department-input': 'Maritime',
      'kyc-country-input': 'Togo',
      'kyc-identity-number-input': 'ID-12345',
    }.entries) {
      await enterKycField(tester, entry.key, entry.value);
    }
    await scrollKycUntilVisible(
      tester,
      find.byKey(const ValueKey('kyc-submit-button')),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('kyc-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kyc-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Ajoutez une photo de votre pièce d’identité.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('kyc-form-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('kyc-verified-badge')), findsNothing);
    await scrollKycUntilVisible(
      tester,
      find.byKey(const ValueKey('kyc-cancel-button')),
    );
    await tester.tap(find.byKey(const ValueKey('kyc-cancel-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kyc-form-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: true);

  testWidgets('investment of exactly \$5000 does not require KYC', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('reit-category-invest-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-commerce')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount-input')),
      '5000',
    );
    await tester.pumpAndSettle();

    expect(find.text('Compléter le KYC requis'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('investment-continue-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kyc-form-sheet')), findsNothing);
    expect(
      find.byKey(const ValueKey('success-confirmation-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }, skip: true);

  testWidgets('verified KYC state retains its profile badge', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await tester.pumpWidget(
      const MaterialApp(home: InvestmentPage(kycVerified: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('kyc-verified-badge')), findsOneWidget);
    expect(find.text('Vérifié'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-kyc-status')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile authorization page displays the framed license', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();

    final authorizationButton = find.byKey(
      const ValueKey('profile-info-Autorisation'),
    );
    await scrollUntilBuilt(tester, authorizationButton);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(authorizationButton);
    await tester.pumpAndSettle();
    await tester.tap(authorizationButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('authorization-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('authorization-license-frame')),
      findsOneWidget,
    );
    final licenseImage = tester.widget<Image>(
      find.byKey(const ValueKey('authorization-license-image')),
    );
    expect(
      (licenseImage.image as AssetImage).assetName,
      'assets/tamleek_trade_license.png',
    );
    expect(find.text('7770 · Commerciale'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile help page shows Tamleek history and founder photo', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();

    final helpButton = find.byKey(
      const ValueKey('profile-info-Aide et informations'),
    );
    await scrollUntilBuilt(tester, helpButton);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(helpButton);
    await tester.pumpAndSettle();
    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('help-info-page')), findsOneWidget);
    expect(find.text('L’HISTOIRE DE TAMLEEK'), findsOneWidget);
    expect(find.textContaining('Fondée à la mi-2018'), findsOneWidget);
    expect(find.textContaining('2 milliards AED'), findsOneWidget);
    final founderPhoto = tester.widget<Image>(
      find.byKey(const ValueKey('help-founder-photo')),
    );
    expect(
      (founderPhoto.image as AssetImage).assetName,
      'assets/tamleek_founder.png',
    );
    final pillarsHeading = find.text('NOS CINQ PILIERS');
    await tester.scrollUntilVisible(
      pillarsHeading,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(pillarsHeading, findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('help-pillar-REIT')));
    expect(find.text('REIT'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('help-info-back')));
    await tester.pumpAndSettle();
    expect(find.text('Mon profil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile logout returns to signup and keeps profile details', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tamleek.registration.complete': true,
      'tamleek.profile.name': 'Awa Test',
      'tamleek.profile.email': 'awa@example.com',
    });
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();
    final logoutButton = find.byKey(const ValueKey('profile-logout-button'));
    await tester.scrollUntilVisible(
      logoutButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Voulez-vous vraiment vous déconnecter ?'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('profile-logout-confirm')));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('tamleek.registration.complete'), isFalse);
    expect(preferences.getString('tamleek.profile.name'), 'Awa Test');
    expect(preferences.getString('tamleek.profile.email'), 'awa@example.com');
    expect(find.text('Inscription'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-logout-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved profile photo is shown in the home header', (
    WidgetTester tester,
  ) async {
    final photoPath = File('assets/tamleek_logo.jpg').absolute.path;
    SharedPreferences.setMockInitialValues({
      'tamleek.registration.complete': true,
      'tamleek.profile.photo': photoPath,
    });
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('tamleek.profile.photo'), photoPath);
    expect(File(photoPath).existsSync(), isTrue);
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-load-error')), findsNothing);
    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('home-profile-avatar')),
    );

    expect(avatar.backgroundImage, isA<FileImage>());
    expect((avatar.backgroundImage! as FileImage).file.path, photoPath);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile information can be edited and persists locally', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tamleek.registration.complete': true,
      'tamleek.profile.email': 'awa@example.com',
    });
    setMobileViewport(tester);
    tester.view.physicalSize = const Size(320, 700);
    await pumpTamleekApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('Modifier mes informations'), findsNothing);

    Future<void> editField({
      required String cardLabel,
      required String inputKey,
      required String value,
      required List<String> hiddenInputKeys,
    }) async {
      final card = find.byKey(ValueKey('profile-info-$cardLabel'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(inputKey)), findsOneWidget);
      for (final hiddenInputKey in hiddenInputKeys) {
        expect(find.byKey(ValueKey(hiddenInputKey)), findsNothing);
      }
      await tester.enterText(find.byKey(ValueKey(inputKey)), value);
      await tester.tap(find.byKey(const ValueKey('profile-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('Profil mis à jour'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('success-confirmation-continue')),
      );
      await tester.pumpAndSettle();
    }

    await editField(
      cardLabel: 'Nom complet',
      inputKey: 'profile-name-input',
      value: 'Awa Test',
      hiddenInputKeys: ['profile-phone-input'],
    );
    await editField(
      cardLabel: 'Téléphone',
      inputKey: 'profile-phone-input',
      value: '+971501234567',
      hiddenInputKeys: ['profile-name-input'],
    );

    final emailCard = find.byKey(const ValueKey('profile-info-Adresse e-mail'));
    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(emailCard);
    expect(
      find.descendant(
        of: emailCard,
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsNothing,
    );
    await tester.tap(emailCard);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-email-input')), findsNothing);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('tamleek.profile.name'), 'Awa Test');
    expect(preferences.getString('tamleek.profile.email'), 'awa@example.com');
    expect(preferences.getString('tamleek.profile.phone'), '+971501234567');
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('Awa Test'), findsNWidgets(2));
    expect(find.text('awa@example.com'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpTamleekApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();
    expect(find.text('Awa Test'), findsNWidgets(2));
    expect(find.text('awa@example.com'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('+971501234567'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('+971501234567'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crypto and commodity cards use their supplied images', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);

    await tester.ensureVisible(find.text('Crypto'));
    await tester.tap(find.text('Crypto'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('investment-image-crypto')),
      findsOneWidget,
    );
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const ValueKey('investment-image-crypto')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/cryptocurrencies.png',
    );

    await tester.tap(find.byTooltip('Filtres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matières premières').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('investment-image-commodity')),
      findsOneWidget,
    );
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const ValueKey('investment-image-commodity')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/commodities.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('financial buttons are interactive without local transactions', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-local-page')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('wallet-total-card')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('wallet-deposit-action')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('wallet-deposit-action')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const ValueKey('wallet-withdraw-action')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('wallet-withdraw-action')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('wallet-deposit-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deposit-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transfer-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-withdraw-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('withdraw-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('transfer-amount-input')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.restorationId == 'transfer-destination-input',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('transfer-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-local-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wallet-balance-carousel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wallet-page-indicators')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('wallet-total-card')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('wallet-balance-carousel')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-available-card')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('wallet-balance-carousel')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-invested-card')), findsOneWidget);
    expect(find.text('Activité récente'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-activity-empty')), findsOneWidget);
    for (final sampleValue in [
      '\$12,450.00',
      '\$8,250.00',
      '\$4,200.00',
      'Dépôt de fonds',
      'Achat Bitcoin',
      'Revente d’or',
    ]) {
      expect(find.text(sampleValue), findsNothing);
    }

    await tester.tap(find.byIcon(Icons.pie_chart_outline_rounded).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holdings-local-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('holdings-total-card')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('investment-approved-total')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('holdings-allocation-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('holdings-category-dropdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('holdings-positions-empty')),
      findsOneWidget,
    );
    expect(find.text('Global Real Estate REIT'), findsNothing);
    expect(find.text('Bitcoin (BTC)'), findsNothing);
    expect(find.textContaining('USDT'), findsNothing);
    expect(find.text('REIT 43%'), findsNothing);
    expect(find.text('Crypto 30%'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpTamleekApp(tester);
    await tester.tap(find.byKey(const ValueKey('reit-category-invest-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-commerce')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('reit-pack-invest-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('reit-pack-invest-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('investment-page')), findsOneWidget);
    expect(find.textContaining('20 % par mois'), findsNothing);
    expect(find.text('791.61 %'), findsNothing);
    expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending deposit request opens a receipt from wallet history', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);
    const requestId = '12345678-9abc-4def-8123-456789abcdef';
    const transactionHash =
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    final photoPath = File('assets/tamleek_logo.jpg').absolute.path;
    SharedPreferences.setMockInitialValues({
      'tamleek.profile.photo': photoPath,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: InvestmentPage(
          initialDepositRequestsForTesting: [
            {
              'id': requestId,
              'network': 'Polygon',
              'transaction_hash': transactionHash,
              'amount_usdt': '25.75',
              'status': 'pending',
              'review_note': null,
              'created_at': '2026-11-18T18:05:00Z',
            },
          ],
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();

    final requestRow = find.byKey(
      const ValueKey('deposit-request-receipt-$requestId'),
    );
    await tester.ensureVisible(requestRow);
    await tester.tap(requestRow);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('receipt-page')), findsOneWidget);
    expect(find.text('Dépôt USDT'), findsOneWidget);
    expect(find.text('Polygon'), findsOneWidget);
    expect(find.text('12345678…abcdef'), findsOneWidget);
    expect(find.text(transactionHash), findsNothing);
    expect(find.text('0x123456…abcdef'), findsOneWidget);
    expect(find.text('25.75 USDT'), findsOneWidget);
    expect(find.textContaining('Statut : En attente'), findsOneWidget);
    expect(find.textContaining('vérification manuelle'), findsNothing);
    expect(find.textContaining('jusqu’à 1 heure'), findsOneWidget);
    final profileAvatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('receipt-profile-avatar')),
    );
    expect(profileAvatar.backgroundImage, isA<FileImage>());
    expect((profileAvatar.backgroundImage! as FileImage).file.path, photoPath);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deposit and withdrawal forms offer a network dropdown', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    Future<void> chooseNetwork(String networkKey) async {
      await tester.tap(find.byKey(const ValueKey('transfer-network-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('transfer-network-option-$networkKey')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('transfer-network-picker-confirm')),
      );
      await tester.pumpAndSettle();
    }

    void expectQrAsset(String assetPath) {
      expect(
        (tester
                    .widget<Image>(
                      find.byKey(const ValueKey('transfer-deposit-qr')),
                    )
                    .image
                as AssetImage)
            .assetName,
        assetPath,
      );
    }

    await pumpTamleekApp(tester);
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('wallet-deposit-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deposit-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('transfer-amount-input')), findsOneWidget);
    expect(find.text('Montant à déposer (USDT)'), findsOneWidget);
    expect(find.text('Soumettre le dépôt'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('transfer-network-selected')))
          .data,
      'Polygon',
    );
    expect(
      find.byKey(const ValueKey('transfer-network-dropdown')),
      findsOneWidget,
    );
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(
                      const ValueKey('transfer-network-selected-logo'),
                    ),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/polygon_logo.png',
    );
    expect(
      find.byKey(const ValueKey('transfer-deposit-address')),
      findsOneWidget,
    );
    expect(
      find.text('0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863'),
      findsOneWidget,
    );
    expectQrAsset('assets/deposit_polygon_qr.jpg');
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const ValueKey('transfer-asset-logo-usdt')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/usdt_logo.png',
    );

    await tester.tap(find.byKey(const ValueKey('transfer-network-dropdown')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('transfer-network-picker-dialog')),
      findsOneWidget,
    );
    expect(find.text('Choisir un réseau'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transfer-network-search')),
      findsOneWidget,
    );
    for (final network in [
      'Polygon',
      'BNB Smart Chain',
      'TRON (TRC-20)',
      'Solana',
      'Ethereum (ERC-20)',
    ]) {
      expect(find.text(network), findsWidgets);
    }
    for (final logo in {
      'transfer-network-logo-polygon': 'assets/polygon_logo.png',
      'transfer-network-logo-bnb-smart-chain': 'assets/bnb_logo.png',
      'transfer-network-logo-tron (trc-20)': 'assets/tron_logo.png',
      'transfer-network-logo-solana': 'assets/solana_logo.png',
      'transfer-network-logo-ethereum (erc-20)': 'assets/ethereum_logo.png',
    }.entries) {
      expect(find.byKey(ValueKey(logo.key)), findsOneWidget);
      expect(
        (tester.widget<Image>(find.byKey(ValueKey(logo.key))).image
                as AssetImage)
            .assetName,
        logo.value,
      );
    }
    await tester.tap(
      find.byKey(const ValueKey('transfer-network-option-polygon')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('transfer-network-picker-confirm')),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('deposit-page')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('transfer-amount-input')),
      '9',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getRect(find.byKey(const ValueKey('transfer-submit'))).center,
    );
    await tester.pumpAndSettle();
    expect(find.text('Le dépôt minimum est de 10 \$.'), findsOneWidget);
    expect(find.byKey(const ValueKey('deposit-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transfer-not-connected-dialog')),
      findsNothing,
    );

    await chooseNetwork('tron (trc-20)');
    expectQrAsset('assets/deposit_tron_qr.png');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('transfer-network-selected')))
          .data,
      'TRON (TRC-20)',
    );
    expect(find.text('TARxxEKmcTttRA5Gs8MgheH7PXGRsaV3fd'), findsOneWidget);
    for (final (networkKey, networkName, address, qrAsset) in [
      (
        'solana',
        'Solana',
        'Yp2iCDR4rmMiYrfHJh7iucvEWkSCUAhbZPUrqF9T1SK',
        'assets/deposit_solana_qr.png',
      ),
      (
        'bnb-smart-chain',
        'BNB Smart Chain',
        '0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863',
        'assets/deposit_bnb_qr.png',
      ),
      (
        'ethereum (erc-20)',
        'Ethereum (ERC-20)',
        '0xADF9F3E5693bBfaCF81ba7B4AC3E29098E6Cd863',
        'assets/deposit_ethereum_qr.png',
      ),
    ]) {
      await chooseNetwork(networkKey);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('transfer-network-selected')),
            )
            .data,
        networkName,
      );
      expect(find.text(address), findsOneWidget);
      expectQrAsset(qrAsset);
    }
    await chooseNetwork('tron (trc-20)');
    await scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('transfer-amount-input')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('transfer-amount-input')),
      '10',
    );
    await scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('transfer-transaction-hash-input')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('transfer-transaction-hash-input')),
      'invalid-hash',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('transfer-submit')),
    );
    await tester.tapAt(
      tester.getRect(find.byKey(const ValueKey('transfer-submit'))).center,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Le format du hash ne correspond pas au réseau'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('transfer-transaction-hash-input')),
      List.filled(64, 'a').join(),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('transfer-submit')),
    );
    await tester.tapAt(
      tester.getRect(find.byKey(const ValueKey('transfer-submit'))).center,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('success-confirmation-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('success-confirmation-continue')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-page')), findsOneWidget);
    expect(find.text('Demande de dépôt'), findsOneWidget);
    expect(find.textContaining('Non exécuté'), findsOneWidget);
    expect(find.textContaining('Aucun dépôt n’a été transmis'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('receipt-back')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('deposit-page')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('wallet-withdraw-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('withdraw-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transfer-network-dropdown')),
      findsOneWidget,
    );
    expect(find.text('Polygon'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transfer-network-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('transfer-network-option-solana')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('transfer-network-picker-confirm')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Solana'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('transfer-amount-input')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('transfer-amount-input')),
      '25',
    );
    await scrollUntilBuilt(tester, find.byType(TextFormField).last);
    await tester.enterText(find.byType(TextFormField).last, 'wallet-example');
    await scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('transfer-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('transfer-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('withdrawal-kyc-required')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('kyc-form-sheet')), findsOneWidget);
    await completeKycForm(tester);
    expect(
      find.text('Ajoutez une photo de votre pièce d’identité.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('kyc-form-sheet')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('kyc-cancel-button')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('kyc-cancel-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-page')), findsNothing);
    expect(find.byKey(const ValueKey('withdraw-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: true);

  testWidgets('commodities filter and held-assets navigation work', (
    WidgetTester tester,
  ) async {
    setMobileViewport(tester);

    await pumpTamleekApp(tester);

    final commodityChip = find.byKey(const ValueKey('commodity-category-chip'));
    expect(tester.getSize(commodityChip).width, 160);
    expect(
      find.descendant(
        of: commodityChip,
        matching: find.text('Matières premières'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Filtres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matières premières').last);
    await tester.pumpAndSettle();

    expect(find.text('5 packs de matières premières'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('commodity-category-invest-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Métaux précieux'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('commodity-pack-invest-metaux-precieux')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Or'), findsOneWidget);
    expect(find.text('Bitcoin (BTC)'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('reit-pack-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('commodity-packs-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.pie_chart_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mes actifs'), findsOneWidget);
    expect(find.text('Positions détenues'), findsOneWidget);
    expect(find.text('Répartition des actifs'), findsOneWidget);
    expect(find.text('REIT 43%'), findsOneWidget);
    expect(find.text('Crypto 30%'), findsOneWidget);
    expect(find.text('Matières premières 9%'), findsOneWidget);
    expect(find.text('Or 9%'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('holdings-allocation-bar')))
          .height,
      14,
    );
    expect(
      find.byKey(const ValueKey('holdings-allocation-donut')),
      findsOneWidget,
    );
    expect(find.text('Global Real Estate REIT'), findsOneWidget);
    expect(find.text('Bitcoin (BTC)'), findsOneWidget);
    expect(find.text('Or'), findsNothing);
    final holdingsDropdown = find.byKey(
      const ValueKey('holdings-category-dropdown'),
    );
    expect(holdingsDropdown, findsOneWidget);
    expect(
      tester.widget<InkWell>(holdingsDropdown).borderRadius,
      BorderRadius.circular(18),
    );
    await tester.tap(holdingsDropdown);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('holdings-category-picker-dialog')),
      findsOneWidget,
    );
    expect(find.text('Choisir une catégorie'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('holdings-category-search')),
      findsOneWidget,
    );
    expect(find.text('Tous les actifs'), findsWidgets);
    expect(find.text('Crypto'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('holdings-category-option-crypto')).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('holdings-category-picker-confirm')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bitcoin (BTC)'), findsOneWidget);
    expect(find.text('Global Real Estate REIT'), findsNothing);
    expect(find.text('FPI Performance'), findsNothing);
    await tester.tap(holdingsDropdown);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byKey(const ValueKey('holdings-category-option-tous-les-actifs'))
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('holdings-category-picker-confirm')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Global Real Estate REIT'), findsOneWidget);
    final reitPosition = find.byKey(
      const ValueKey('holding-position-global-reit'),
    );
    await scrollUntilBuilt(tester, reitPosition);
    await tester.tap(reitPosition);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('holding-detail-page-global-reit')),
      findsOneWidget,
    );
    expect(find.text('Détail de position'), findsOneWidget);
    expect(find.text('\$1800.00'), findsOneWidget);
    expect(find.text('42.9%'), findsOneWidget);
    expect(find.text('12 parts'), findsOneWidget);
    expect(find.text('15 janv. 2024'), findsOneWidget);
    expect(find.text('+\$150.00'), findsOneWidget);
    expect(find.text('Historique mensuel des gains'), findsOneWidget);
    expect(find.text('Historique annuel des gains'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('holding-monthly-history-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('holding-detail-annual-history')),
      findsOneWidget,
    );
    for (final panelKey in [
      const ValueKey('holding-detail-summary'),
      const ValueKey('holding-detail-metrics'),
      const ValueKey('holding-detail-monthly-history'),
      const ValueKey('holding-detail-annual-history'),
    ]) {
      final panel = find.byKey(panelKey);
      await scrollUntilBuilt(tester, panel);
      final decoration =
          tester.widget<Container>(panel).decoration! as BoxDecoration;
      expect(
        decoration.gradient,
        isA<LinearGradient>().having(
          (gradient) => gradient.colors,
          'blue card colors',
          const [Color(0xFF17233A), Color(0xFF314A70)],
        ),
      );
    }
    await tester.tap(find.byKey(const ValueKey('holding-detail-back')));
    await tester.pumpAndSettle();
    expect(find.text('Positions détenues'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: true);
}

Future<void> scrollUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      return;
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll to $finder');
}

Future<void> completeKycForm(WidgetTester tester) async {
  for (final entry in {
    'kyc-first-name-input': 'Awa',
    'kyc-last-name-input': 'Test',
    'kyc-birth-year-input': '1995',
    'kyc-birth-place-input': 'Lomé',
    'kyc-city-input': 'Lomé',
    'kyc-department-input': 'Maritime',
    'kyc-country-input': 'Togo',
    'kyc-identity-number-input': 'ID-12345',
  }.entries) {
    await enterKycField(tester, entry.key, entry.value);
  }
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await scrollKycUntilVisible(
    tester,
    find.byKey(const ValueKey('kyc-submit-button')),
  );
  await tester.ensureVisible(find.byKey(const ValueKey('kyc-submit-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('kyc-submit-button')));
  await tester.pumpAndSettle();
}

Future<void> enterKycField(
  WidgetTester tester,
  String fieldKey,
  String value,
) async {
  final finder = find.byKey(ValueKey(fieldKey));
  await scrollKycUntilVisible(tester, finder);
  await tester.enterText(finder, value);
}

Future<void> scrollKycUntilVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('kyc-form-sheet')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(finder, 180, scrollable: scrollable.first);
}

Future<void> pumpTamleekApp(WidgetTester tester) async {
  await tester.pumpWidget(const TamleekApp.forTesting());
  await tester.pumpAndSettle();
}

void setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
