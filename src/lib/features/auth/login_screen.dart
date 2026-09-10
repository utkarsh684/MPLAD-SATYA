import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/server_status_provider.dart';
import '../../widgets/app_logo.dart';

/// Real phone-OTP sign-in. There is no bypass button and no prefilled
/// credential: the only way in is a code the server actually issued.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp(AuthProvider auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await auth.requestOtp(_phoneController.text.trim());
    // In console SMS mode the server returns the code; prefill it so the demo
    // does not depend on a live SMS gateway.
    final debug = auth.debugOtp;
    if (debug != null && mounted) _otpController.text = debug;
  }

  Future<void> _verify(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    await auth.verifyOtp(_otpController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final server = context.watch<ServerStatusProvider>();
    final awaitingOtp = auth.status == AuthStatus.awaitingOtp;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _LanguageSelector(),
                  ),
                  const SizedBox(height: 12),
                  AppLogo(size: 64, light: isDark),
                  const SizedBox(height: 12),
                  Text(
                    l10n.appSubtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: theme.textTheme.bodyMedium?.color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: awaitingOtp
                        ? _buildOtpStep(auth, theme)
                        : _buildPhoneStep(auth, theme, l10n),
                  ),
                  const SizedBox(height: 20),
                  _ServerBadge(server: server),
                  const SizedBox(height: 12),
                  Text(
                    'SIH26102 • v1.0.0',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
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

  Widget _buildPhoneStep(
      AuthProvider auth, ThemeData theme, AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.signIn,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your registered mobile number. We will send a one-time code.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              LengthLimitingTextInputFormatter(16),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '+919876543210',
              prefixIcon: Icon(Icons.phone_android_rounded),
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.length < 8) return 'Enter a valid mobile number';
              return null;
            },
            onFieldSubmitted: (_) => auth.busy ? null : _requestOtp(auth),
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: auth.error!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: auth.busy ? null : () => _requestOtp(auth),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: auth.busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send code'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(AuthProvider auth, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the code',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Sent to ${auth.phone ?? ''}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        if (auth.debugOtp != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.saffron.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.saffron.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.developer_mode_rounded,
                    size: 16, color: AppColors.saffronDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Server is in console SMS mode — code ${auth.debugOtp}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.saffronDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.robotoMono(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 12,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••••',
          ),
          onSubmitted: (_) => auth.busy ? null : _verify(auth),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: auth.error!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: auth.busy ? null : () => _verify(auth),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: auth.busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify and sign in'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: auth.busy ? null : auth.backToPhone,
              child: const Text('Change number'),
            ),
            TextButton(
              onPressed: auth.busy ? null : auth.resendOtp,
              child: const Text('Resend code'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows exactly which backend this build is talking to — invaluable when a
/// demo phone is silently pointed at the wrong host.
class _ServerBadge extends StatelessWidget {
  const _ServerBadge({required this.server});
  final ServerStatusProvider server;

  @override
  Widget build(BuildContext context) {
    final ok = server.reachable;
    final color = ok ? AppColors.indiaGreen : AppColors.error;
    final status = server.status;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            ok
                ? 'Server online · ${status?.env ?? ''} · rules ${status?.shortRulesSha ?? ''}'
                : 'Server unreachable',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return DropdownButtonHideUnderline(
          child: DropdownButton<Locale>(
            value: localeProvider.locale,
            icon: const Icon(Icons.language_rounded, size: 20),
            alignment: Alignment.centerRight,
            items: LocaleProvider.locales.map((locale) {
              return DropdownMenuItem(
                value: locale,
                child: Text(
                  LocaleProvider.supportedLocales[locale.languageCode]!,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (newLocale) {
              if (newLocale != null) localeProvider.setLocale(newLocale);
            },
          ),
        );
      },
    );
  }
}
