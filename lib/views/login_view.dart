import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'home_nav_view.dart';

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
        MaterialPageRoute(builder: (_) => const HomeNavView()),
      );
    } else {
      setState(() {
        _errorMessage = res['message'] ??
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
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // Header login selalu navy, sehingga ikon status bar harus terang.
    final overlay = AppTheme.overlayStyle(Brightness.dark, scheme).copyWith(
      systemNavigationBarIconBrightness:
          scheme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLow,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final heroHeight = isWide ? 300.0 : 260.0;
            final sheetMinHeight =
                constraints.maxHeight > heroHeight
                    ? constraints.maxHeight - heroHeight + 24
                    : 0.0;

            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    _LoginHero(height: heroHeight),
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(minHeight: sheetMinHeight),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.xl + bottomInset,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          boxShadow: AppShadows.raised(context),
                        ),
                        child: Align(
                          alignment: isWide
                              ? Alignment.center
                              : Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: _buildForm(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AKSES PETUGAS',
          style: texts.labelMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Masuk ke Pos Security',
          style: texts.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Gunakan akun POS yang terdaftar untuk memulai shift.',
          style: texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
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
          '© ${DateTime.now().year} Master Truck · KIM 3',
          textAlign: TextAlign.center,
          style: texts.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: height),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -48,
            top: -56,
            child: _HeroCircle(
              size: 190,
              color: AppTheme.surfaceWhite.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            left: -64,
            bottom: -72,
            child: _HeroCircle(
              size: 210,
              color: AppTheme.surfaceWhite.withValues(alpha: 0.04),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              topInset + AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxl + AppSpacing.md,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppTheme.surfaceWhite.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/master-truck-logo-transparent.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_rounded,
                          color: AppTheme.amberGold,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'MASTER TRUCK',
                      textAlign: TextAlign.center,
                      style: texts.titleLarge?.copyWith(
                        color: AppTheme.surfaceWhite,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Pos Security Gerbang',
                      textAlign: TextAlign.center,
                      style: texts.bodyMedium?.copyWith(
                        color: AppTheme.surfaceWhite.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.amberGold,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'BENGKEL KIM 3',
                        style: texts.labelSmall?.copyWith(
                          color: const Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCircle extends StatelessWidget {
  const _HeroCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: scheme.onErrorContainer),
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
