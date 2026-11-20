import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'gate_select_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userIdFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  String? _userIdError;
  String? _passwordError;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _userIdFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text;
    final userIdError = userId.isEmpty ? 'Masukkan User ID petugas.' : null;
    final passwordError = password.isEmpty ? 'Masukkan kata sandi.' : null;

    if (userIdError != null || passwordError != null) {
      setState(() {
        _userIdError = userIdError;
        _passwordError = passwordError;
        _errorMessage = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _userIdError = null;
      _passwordError = null;
    });

    final res = await AuthService.login(userId: userId, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GateSelectView()),
      );
    } else {
      setState(() {
        _errorMessage =
            res['message'] ??
            'User ID atau kata sandi yang Anda masukkan tidak sesuai. '
                'Silakan periksa kembali dan coba lagi.';
      });
    }
  }

  void _clearErrors() {
    if (_errorMessage == null &&
        _userIdError == null &&
        _passwordError == null) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _userIdError = null;
      _passwordError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Positioned(
            right: -90,
            top: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.16),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.secondary.withValues(alpha: 0.14),
                    scheme.secondary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 60,
                          height: 60,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.14),
                            ),
                            boxShadow: AppShadows.raised(context),
                          ),
                          child: Image.asset(
                            'assets/images/darkogate-logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'DARKOGATE · POS GERBANG',
                        style: texts.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Selamat datang',
                        style: texts.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Masuk dengan akun POS terdaftar untuk memulai tugas gerbang.',
                        style: texts.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: _buildForm(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: AppDurations.normal,
          curve: Curves.easeOut,
          child: _errorMessage == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _LoginErrorBanner(message: _errorMessage!),
                ),
        ),
        AutofillGroup(
          child: Column(
            children: [
              AppTextField(
                controller: _userIdController,
                focusNode: _userIdFocus,
                label: 'User ID Petugas',
                hint: 'Masukkan User ID POS Anda',
                prefixIcon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                errorText: _userIdError,
                enabled: !_isLoading,
                onChanged: (_) => _clearErrors(),
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                label: 'Kata Sandi',
                hint: 'Masukkan kata sandi',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                showObscureToggle: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                errorText: _passwordError,
                enabled: !_isLoading,
                onChanged: (_) => _clearErrors(),
                onSubmitted: (_) => _handleLogin(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Masuk ke Sistem',
          icon: Icons.login_rounded,
          loading: _isLoading,
          onPressed: _isLoading ? null : _handleLogin,
          semanticLabel: 'Masuk ke sistem keamanan gerbang',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Akses terbatas untuk petugas keamanan gerbang.',
          textAlign: TextAlign.center,
          style: texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '© ${DateTime.now().year} DarkoGate · KIM 3',
          textAlign: TextAlign.center,
          style: texts.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: texts.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
