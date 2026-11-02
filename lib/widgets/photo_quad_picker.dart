import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';

class PhotoQuadPicker extends StatelessWidget {
  final Map<String, String> photos; // 'DEPAN', 'BELAKANG', 'KIRI', 'KANAN' -> base64
  final Function(String angle, String base64) onPhotoCaptured;
  final Function(String angle)? onPhotoRemoved;

  const PhotoQuadPicker({
    Key? key,
    required this.photos,
    required this.onPhotoCaptured,
    this.onPhotoRemoved,
  }) : super(key: key);

  static const List<Map<String, String>> angles = [
    {'key': 'DEPAN', 'label': 'Tampak Depan', 'icon': 'directions_car'},
    {'key': 'BELAKANG', 'label': 'Tampak Belakang', 'icon': 'drive_eta'},
    {'key': 'KIRI', 'label': 'Sisi Kiri', 'icon': 'swap_horiz'},
    {'key': 'KANAN', 'label': 'Sisi Kanan', 'icon': 'swap_horiz'},
  ];

  Future<void> _takePhoto(BuildContext context, String angle) async {
    final picker = ImagePicker();
    try {
      final xFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 960,
        imageQuality: 80,
      );

      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        final b64 = base64Encode(bytes);
        onPhotoCaptured(angle, b64);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Foto Fisik 4 Sudut',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '${photos.length}/4 Terisi',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: photos.length == 4 ? AppTheme.successGreen : AppTheme.amberGold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemCount: angles.length,
          itemBuilder: (context, index) {
            final item = angles[index];
            final key = item['key']!;
            final label = item['label']!;
            final hasPhoto = photos.containsKey(key);

            return InkWell(
              onTap: () => _takePhoto(context, key),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: hasPhoto ? AppTheme.surfaceWhite : AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasPhoto ? AppTheme.successGreen : AppTheme.cardBorder,
                    width: hasPhoto ? 1.5 : 1,
                  ),
                ),
                child: hasPhoto
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.memory(
                              base64Decode(photos[key]!),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: AppTheme.corporateNavy.withOpacity(0.6), size: 24),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '+ Ambil Foto',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.corporateBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ],
    );
  }
}
