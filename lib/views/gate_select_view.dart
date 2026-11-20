import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/gate_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'home_nav_view.dart';
import 'login_view.dart';

/// Layar wajib pemilihan Gate setelah login.
/// Petugas belum dapat menggunakan aplikasi sebelum memilih gerbang tugasnya.
class GateSelectView extends StatefulWidget {
  const GateSelectView({super.key});

  @override
  State<GateSelectView> createState() => _GateSelectViewState();
}

class _GateSelectViewState extends State<GateSelectView> {
  bool _loading = true;
  bool _saving = false;
  List<GateModel> _gates = [];
  GateModel? _selectedGate;

  @override
  void initState() {
    super.initState();
    _loadGates();
  }

  Future<void> _loadGates() async {
    setState(() => _loading = true);
    final gates = await ApiService.getGates();
    if (!mounted) return;
    setState(() {
      _gates = gates;
      _loading = false;
    });
  }

  Future<void> _confirmGate() async {
    final gate = _selectedGate;
    if (gate == null) return;
    setState(() => _saving = true);
    await AuthService.setSelectedGate(gate);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeNavView()));
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final session = AuthService.currentSession;

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
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppShadows.soft(context),
                            ),
                            child: const Icon(
                              Icons.door_sliding_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, ${session?.name ?? 'Petugas'}',
                                  style: texts.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Pilih gerbang (Gate) tugas Anda sebelum memulai.',
                                  style: texts.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _gates.isEmpty
                            ? Center(
                                child: AppCard(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cloud_off_rounded,
                                        size: 40,
                                        color: scheme.error,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        'Daftar gate tidak dapat dimuat.',
                                        style: texts.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Pastikan koneksi internet aktif lalu muat ulang.',
                                        textAlign: TextAlign.center,
                                        style: texts.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      AppButton(
                                        label: 'Muat Ulang Gate',
                                        icon: Icons.refresh_rounded,
                                        onPressed: _loadGates,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _gates.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final gate = _gates[index];
                                  final selected = _selectedGate?.id == gate.id;
                                  return InkWell(
                                    onTap: _saving
                                        ? null
                                        : () => setState(
                                            () => _selectedGate = gate,
                                          ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    child: AnimatedContainer(
                                      duration: AppDurations.fast,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.lg,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? scheme.primary.withValues(
                                                alpha: 0.1,
                                              )
                                            : scheme.surface,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.lg,
                                        ),
                                        border: Border.all(
                                          color: selected
                                              ? scheme.primary
                                              : scheme.outlineVariant,
                                          width: selected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            selected
                                                ? Icons
                                                      .radio_button_checked_rounded
                                                : Icons
                                                      .radio_button_off_rounded,
                                            color: selected
                                                ? scheme.primary
                                                : scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  gate.namaGate,
                                                  style: texts.titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: selected
                                                            ? scheme.primary
                                                            : scheme.onSurface,
                                                      ),
                                                ),
                                                if (gate.keterangan != null &&
                                                    gate.keterangan!.isNotEmpty)
                                                  Text(
                                                    gate.keterangan!,
                                                    style: texts.bodySmall
                                                        ?.copyWith(
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.pill,
                                                  ),
                                            ),
                                            child: Text(
                                              gate.kodeGate,
                                              style: texts.labelSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
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
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: _selectedGate == null
                            ? 'Pilih Gate Terlebih Dahulu'
                            : 'Masuk ke ${_selectedGate!.namaGate}',
                        icon: Icons.arrow_forward_rounded,
                        loading: _saving,
                        onPressed: (_selectedGate == null || _saving)
                            ? null
                            : _confirmGate,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: _saving ? null : _logout,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Keluar / Ganti Akun'),
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
}
