import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class ARMeasurementScreen extends StatefulWidget {
  const ARMeasurementScreen({super.key});

  @override
  State<ARMeasurementScreen> createState() => _ARMeasurementScreenState();
}

class _ARMeasurementScreenState extends State<ARMeasurementScreen> {
  bool _isMeasuring = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.arMeasurement),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mock Camera View
          Container(
            color: Colors.black87,
            child: const Center(
              child: Icon(
                Icons.camera_alt_outlined,
                size: 100,
                color: Colors.white24,
              ),
            ),
          ),
          
          // Overlay UI
          if (_isMeasuring)
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.saffron, width: 2),
                ),
                child: const Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Icon(Icons.add, color: AppColors.saffron, size: 40),
                    )
                  ],
                ),
              ),
            ),
            
          // Measurement Results
          if (_isMeasuring)
            Positioned(
              top: 32,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMetricBox(l10n.distance, '12.4 m'),
                  _buildMetricBox(l10n.area, '148 m²'),
                ],
              ),
            ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_isMeasuring)
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _isMeasuring = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    child: Text(l10n.reset),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _isMeasuring = true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.indiaGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    child: Text(l10n.startMeasurement),
                  ),
                  
                if (_isMeasuring) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.govBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    child: Text(l10n.saveMeasurement),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.saffron,
            ),
          ),
        ],
      ),
    );
  }
}
