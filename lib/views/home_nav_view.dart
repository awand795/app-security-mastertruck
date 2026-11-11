import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/active_vehicle_model.dart';
import '../models/booking_candidate_model.dart';
import '../models/employee_model.dart';
import '../models/memo_keluar_model.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'active_inside_view.dart';
import 'beranda_view.dart';
import 'check_in_view.dart';
import 'check_out_view.dart';
import 'login_view.dart';
import 'today_exit_view.dart';

class HomeNavView extends StatefulWidget {
  const HomeNavView({
    super.key,
    this.dashboardLoader,
    this.checkInEmployeeLoader,
    this.checkInCandidateSearcher,
    this.checkOutVehicleLoader,
    this.initialCheckoutPlate,
    this.activeInsideLoader,
    this.memoLoader,
    this.clock,
  });

  /// Opsional untuk preview test; produksi memakai ApiService di BerandaView.
  final Future<BerandaData> Function()? dashboardLoader;
  final Future<List<EmployeeItem>> Function()? checkInEmployeeLoader;
  final Future<List<CheckinCandidate>> Function(String query)?
  checkInCandidateSearcher;
  final Future<List<ActiveVehicle>> Function(String query)?
  checkOutVehicleLoader;
  final String? initialCheckoutPlate;
  final Future<List<ActiveVehicle>> Function(String query)? activeInsideLoader;
  final Future<List<MemoKeluar>> Function(String query)? memoLoader;
  final DateTime Function()? clock;

  @override
  State<HomeNavView> createState() => _HomeNavViewState();
}

class _HomeNavViewState extends State<HomeNavView> {
  static const _titles = [
    'Beranda',
    'Kendaraan Masuk',
    'Kendaraan di Dalam',
    'Kendaraan Keluar',
    'Riwayat Keluar',
  ];

  static const _subtitles = [
    '',
    'Catat kendaraan yang masuk gerbang',
    'Pantau armada yang masih di bengkel',
    'Validasi invoice dan terbitkan gate pass',
    'Riwayat gate pass kendaraan keluar',
  ];

  int _currentIndex = 0;
  int _berandaRefreshToken = 0;
  String? _checkoutTargetPlate;
  final Set<int> _visitedTabs = {0};

  void _selectTab(int index) {
    if (_currentIndex == index) {
      if (index == 0) {
        setState(() => _berandaRefreshToken++);
      }
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
      if (index == 0) _berandaRefreshToken++;
    });
  }

  void _navigateToCheckout(String plate) {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _checkoutTargetPlate = plate;
      _currentIndex = 3;
      _visitedTabs.add(3);
    });
  }

  Future<void> _openProfile() async {
    final session = AuthService.currentSession;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ProfileSheet(
        session: session,
        onLogout: () => Navigator.of(sheetContext).pop('logout'),
      ),
    );

    if (!mounted || action != 'logout') return;
    await _confirmLogout();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final texts = Theme.of(sheetContext).textTheme;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: scheme.onErrorContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Keluar dari akun?',
                        style: texts.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Sesi petugas akan diakhiri dan Anda perlu masuk kembali untuk '
                  'melanjutkan pengawasan gerbang.',
                  style: texts.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Batal',
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.medium,
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Keluar',
                        icon: Icons.logout_rounded,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.medium,
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    await AuthService.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  Widget _buildTab(int index, String officerName) {
    switch (index) {
      case 0:
        return BerandaView(
          officerName: officerName,
          onOpenProfile: _openProfile,
          onOpenTab: _selectTab,
          onOpenCheckout: _navigateToCheckout,
          refreshToken: _berandaRefreshToken,
          loadData: widget.dashboardLoader,
          clock: widget.clock,
        );
      case 1:
        return CheckInView(
          employeeLoader: widget.checkInEmployeeLoader,
          candidateSearcher: widget.checkInCandidateSearcher,
        );
      case 2:
        return ActiveInsideView(
          onNavigateToCheckout: _navigateToCheckout,
          vehicleLoader: widget.activeInsideLoader,
          clock: widget.clock,
        );
      case 3:
        return CheckOutView(
          key: ValueKey(
            'checkout-${_checkoutTargetPlate ?? widget.initialCheckoutPlate ?? 'fresh'}',
          ),
          initialPlate: _checkoutTargetPlate ?? widget.initialCheckoutPlate,
          vehicleLoader: widget.checkOutVehicleLoader,
          onClearInitialPlate: () =>
              setState(() => _checkoutTargetPlate = null),
        );
      case 4:
        return TodayExitView(
          memoLoader: widget.memoLoader,
          clock: widget.clock,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final officerName = AuthService.currentSession?.name ?? 'Petugas Security';
    final showCompactHeader = _currentIndex != 0;

    final tabs = List<Widget>.generate(_titles.length, (index) {
      if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
      return _buildTab(index, officerName);
    });

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (showCompactHeader)
              _CompactHeader(
                title: _titles[_currentIndex],
                subtitle: _subtitles[_currentIndex],
                officerName: officerName,
                onOpenProfile: _openProfile,
              ),
            Expanded(
              child: _TabFadeStack(index: _currentIndex, children: tabs),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _selectTab,
            backgroundColor: scheme.surface,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Beranda',
              ),
              NavigationDestination(
                icon: Icon(Icons.login_outlined),
                selectedIcon: Icon(Icons.login_rounded),
                label: 'Masuk',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping_rounded),
                label: 'Di Dalam',
              ),
              NavigationDestination(
                icon: Icon(Icons.exit_to_app_outlined),
                selectedIcon: Icon(Icons.exit_to_app_rounded),
                label: 'Keluar',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Riwayat',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.title,
    required this.subtitle,
    required this.officerName,
    required this.onOpenProfile,
  });

  final String title;
  final String subtitle;
  final String officerName;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texts.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texts.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                InitialsAvatar(
                  name: officerName,
                  size: 40,
                  onTap: onOpenProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabFadeStack extends StatelessWidget {
  const _TabFadeStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List<Widget>.generate(children.length, (tabIndex) {
        return Positioned.fill(
          child: _TabPage(active: tabIndex == index, child: children[tabIndex]),
        );
      }),
    );
  }
}

/// Halaman tab yang memudar dan bergeser masuk/keluar.
///
/// Controller per tab membuat tab baru benar-benar fade-in, bukan hanya
/// menampilkan konten secara instan saat tab lama memudar.
class _TabPage extends StatefulWidget {
  const _TabPage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.normal,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.015, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _TabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.active,
      child: ExcludeSemantics(
        excluding: !widget.active,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(position: _slide, child: widget.child),
        ),
      ),
    );
  }
}
