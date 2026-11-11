// Design-system preview harness.
//
// Jalankan:
//   flutter test tool/preview/design_system_preview_test.dart --update-goldens
//
// File ini hanya untuk menghasilkan screenshot review desain (bukan bagian
// dari test suite utama) sehingga tidak memengaruhi `flutter test`.
import 'dart:io';

import 'package:bengkel_kim3_security_app/config/theme.dart';
import 'package:bengkel_kim3_security_app/widgets/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const String _goldenPath = '../../docs/revamp/fase-1';

void main() {
  setUpAll(() async {
    Directory('docs/revamp/fase-1').createSync(recursive: true);
    GoogleFonts.config.allowRuntimeFetching = false;

    // Daftarkan varian font yang dipakai tema langsung dari aset agar golden
    // test deterministik (tidak menunggu pemuatan font google_fonts).
    final separator = Platform.pathSeparator;
    final fontDir = 'assets${separator}fonts$separator';
    const pjs = 'PlusJakartaSans';
    await _loadLocalFont('${fontDir}PlusJakartaSans-Regular.ttf', [
      pjs,
      '${pjs}_regular',
    ]);
    await _loadLocalFont('${fontDir}PlusJakartaSans-Medium.ttf', [
      '${pjs}_500',
    ]);
    await _loadLocalFont('${fontDir}PlusJakartaSans-SemiBold.ttf', [
      '${pjs}_600',
    ]);
    await _loadLocalFont('${fontDir}PlusJakartaSans-Bold.ttf', [
      '${pjs}_700',
    ]);
    await _loadLocalFont('${fontDir}PlusJakartaSans-ExtraBold.ttf', [
      '${pjs}_800',
    ]);
    await _loadLocalFont('${fontDir}Chivo-Bold.ttf', ['Chivo', 'Chivo_700']);
    await _loadLocalFont('${fontDir}Chivo-ExtraBold.ttf', ['Chivo_800']);
    await _loadLocalFont('${fontDir}Chivo-Black.ttf', ['Chivo_900']);

    // MaterialIcons tidak otomatis tersedia di lingkungan golden test.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null || flutterRoot.isEmpty) return;
    final iconFont = File(
      '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}'
      'cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
      'material_fonts${Platform.pathSeparator}materialicons-regular.otf',
    );
    if (!iconFont.existsSync()) return;
    final bytes = await iconFont.readAsBytes();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  testWidgets('phone light - atas', (tester) async {
    await _pumpPreview(tester, const Size(360, 800), Brightness.light);
    await _capture(tester, 'phone_light_atas.png');
  });

  testWidgets('phone light - komponen', (tester) async {
    await _pumpPreview(
      tester,
      const Size(360, 800),
      Brightness.light,
      scrollOffset: 790,
    );
    await _capture(tester, 'phone_light_komponen.png');
  });

  testWidgets('phone dark - atas', (tester) async {
    await _pumpPreview(tester, const Size(360, 800), Brightness.dark);
    await _capture(tester, 'phone_dark_atas.png');
  });

  testWidgets('phone dark - komponen', (tester) async {
    await _pumpPreview(
      tester,
      const Size(360, 800),
      Brightness.dark,
      scrollOffset: 790,
    );
    await _capture(tester, 'phone_dark_komponen.png');
  });

  testWidgets('tablet light', (tester) async {
    await _pumpPreview(tester, const Size(800, 1280), Brightness.light);
    await _capture(tester, 'tablet_light.png');
  });

  testWidgets('tablet dark', (tester) async {
    await _pumpPreview(tester, const Size(800, 1280), Brightness.dark);
    await _capture(tester, 'tablet_dark.png');
  });
}

Future<void> _loadLocalFont(String path, List<String> families) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  for (final family in families) {
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

Future<void> _pumpPreview(
  WidgetTester tester,
  Size logicalSize,
  Brightness brightness, {
  double scrollOffset = 0,
}) async {
  const double dpr = 2;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(
    logicalSize.width * dpr,
    logicalSize.height * dpr,
  );
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _PreviewApp(brightness: brightness, scrollOffset: scrollOffset),
  );
  await tester.pump(const Duration(milliseconds: 50));
  // Tunggu font dari aset selesai dimuat sebelum capture.
  await GoogleFonts.pendingFonts();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _capture(WidgetTester tester, String fileName) async {
  await expectLater(
    find.byType(_PreviewApp),
    matchesGoldenFile('$_goldenPath/$fileName'),
  );
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.brightness, required this.scrollOffset});

  final Brightness brightness;
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: _PreviewHome(scrollOffset: scrollOffset),
    );
  }
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome({required this.scrollOffset});

  final double scrollOffset;

  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  late final ScrollController _controller =
      ScrollController(initialScrollOffset: widget.scrollOffset);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              controller: _controller,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                140,
              ),
              children: [
                const _BrandHeader(),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Selamat pagi,',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bambang Sutrisno',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Jumat, 6 November 2026 · Pos Gerbang KIM 3',
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SummaryCard(),
                const SizedBox(height: AppSpacing.xl),
                const _QuickActions(),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Kendaraan terbaru',
                  subtitle: 'Paling baru masuk gerbang',
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Lihat semua'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _VehicleCard(
                  plate: 'B 2156 TQR',
                  driver: 'Joko Santoso',
                  duration: '2j 15m',
                  status: AppStatus.readyToExit,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _VehicleCard(
                  plate: 'D 8821 KIM',
                  driver: 'Agus Pratama',
                  duration: '48m',
                  status: AppStatus.inProgress,
                ),
                const SizedBox(height: AppSpacing.xxl),
                const Divider(),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Status & badge',
                  subtitle: 'Warna semantik dari tema',
                  eyebrow: 'Design system',
                ),
                const SizedBox(height: AppSpacing.md),
                const Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusChip(AppStatus.booking),
                    StatusChip(AppStatus.member),
                    StatusChip(AppStatus.walkIn),
                    StatusChip(AppStatus.readyToExit),
                    StatusChip(AppStatus.inProgress),
                    StatusChip(AppStatus.paid),
                    StatusChip(AppStatus.unpaid),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Tombol',
                  subtitle: 'Tinggi minimum 48 px, status loading jelas',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Konfirmasi & Terbitkan Tiket',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Simpan sebagai Draf',
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.medium,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Batalkan',
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.medium,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Memproses',
                        loading: true,
                        size: AppButtonSize.medium,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Input',
                  subtitle: 'Label mengambang dan validasi inline',
                ),
                const SizedBox(height: AppSpacing.md),
                const AppTextField(
                  label: 'Nama Pengemudi',
                  hint: 'Contoh: Joko Santoso',
                  prefixIcon: Icons.person_outline_rounded,
                  required: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppTextField(
                  label: 'PIC / Petugas Tujuan',
                  hint: 'Pilih PIC',
                  prefixIcon: Icons.badge_outlined,
                  errorText: 'Pilih PIC terlebih dahulu.',
                  required: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                const SearchField(
                  onChanged: _noop,
                  hintText: 'Cari nopol, pengemudi, atau keluhan…',
                  isSearching: true,
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Detail & struk',
                  subtitle: 'InfoRow dengan nilai tegas',
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      const InfoRow(
                        label: 'Nomor Polisi',
                        value: 'B 2156 TQR',
                        icon: Icons.directions_car_outlined,
                      ),
                      Divider(height: AppSpacing.lg, color: scheme.outlineVariant),
                      const InfoRow(
                        label: 'Pengemudi',
                        value: 'Joko Santoso',
                        icon: Icons.person_outline_rounded,
                      ),
                      Divider(height: AppSpacing.lg, color: scheme.outlineVariant),
                      const InfoRow(
                        label: 'Tujuan',
                        value: 'Service berkala',
                        icon: Icons.build_outlined,
                      ),
                      Divider(height: AppSpacing.lg, color: scheme.outlineVariant),
                      InfoRow(
                        label: 'Invoice',
                        value: 'LUNAS',
                        icon: Icons.receipt_long_outlined,
                        valueColor: context.semantic.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Kondisi kosong & galat',
                  subtitle: 'Selalu ada jalan keluar untuk petugas',
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: SizedBox(
                    height: 250,
                    child: EmptyState(
                      compact: true,
                      icon: Icons.local_shipping_outlined,
                      title: 'Belum ada kendaraan',
                      message:
                          'Kendaraan yang sudah check-in akan muncul di sini.',
                      actionLabel: 'Scan Plat Masuk',
                      actionIcon: Icons.qr_code_scanner_rounded,
                      onAction: () {},
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: SizedBox(
                    height: 270,
                    child: ErrorState(
                      compact: true,
                      message:
                          'Periksa koneksi internet lalu coba muat ulang data.',
                      onRetry: () {},
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Memuat',
                  subtitle: 'Skeleton, bukan spinner tengah layar',
                ),
                const SizedBox(height: AppSpacing.md),
                const SkeletonList(
                  scrollable: false,
                  itemCount: 2,
                  padding: EdgeInsets.zero,
                  itemHeight: 132,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Plat nomor memakai Chivo · teks minimum 12 px · badge 11 px',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: StickyBottomBar(
        hint: 'Periksa kembali data sebelum melanjutkan',
        child: AppButton(
          label: 'Konfirmasi & Terbitkan Tiket',
          icon: Icons.check_circle_outline_rounded,
          onPressed: () {},
        ),
      ),
    );
  }
}

void _noop(String value) {}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(Icons.shield_rounded, color: scheme.onPrimary, size: 22),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MasterTruck',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                'Pos Gerbang KIM 3',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Semantics(
          label: 'Buka profil petugas',
          button: true,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              'BS',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = context.isDarkMode;
    final background = isDark ? scheme.surfaceContainerHigh : scheme.primary;
    final foreground = isDark ? scheme.onSurface : scheme.onPrimary;
    final muted = foreground.withValues(alpha: 0.72);

    return AppCard(
      backgroundColor: background,
      borderColor: isDark ? scheme.outlineVariant : Colors.transparent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(
              Icons.local_shipping_rounded,
              size: 132,
              color: foreground.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_rounded,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Kendaraan di dalam',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '24',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 8),
                    child: Text(
                      'unit',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: muted,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(height: 1, color: foreground.withValues(alpha: 0.16)),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Masuk hari ini',
                      value: '12',
                      color: foreground,
                      muted: muted,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: foreground.withValues(alpha: 0.16),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MiniStat(
                      label: 'Keluar hari ini',
                      value: '8',
                      color: foreground,
                      muted: muted,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: foreground,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.muted,
  });

  final String label;
  final String value;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan Masuk',
            background: scheme.primary,
            foreground: scheme.onPrimary,
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.exit_to_app_rounded,
            label: 'Scan Keluar',
            background: scheme.secondaryContainer,
            foreground: scheme.onSecondaryContainer,
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.local_shipping_outlined,
            label: 'Di Dalam',
            background: semantic.infoContainer,
            foreground: semantic.onInfoContainer,
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.receipt_long_outlined,
            label: 'Riwayat',
            background: semantic.neutralContainer,
            foreground: semantic.onNeutralContainer,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        children: [
          Material(
            color: background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {},
              child: SizedBox(
                width: 58,
                height: 58,
                child: Icon(icon, color: foreground, size: 26),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.plate,
    required this.driver,
    required this.duration,
    required this.status,
  });

  final String plate;
  final String driver;
  final String duration;
  final AppStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final isReady = status == AppStatus.readyToExit;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      accentColor: isReady ? semantic.success : semantic.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlateBadge(plate, size: PlateBadgeSize.small),
              const Spacer(),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            driver,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '$duration di dalam',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.build_circle_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Service berkala',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
