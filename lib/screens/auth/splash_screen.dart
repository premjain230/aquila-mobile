import 'package:flutter/material.dart';

import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AquilaColors.bgBase,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AquilaLogo(size: 76),
            const SizedBox(height: 24),
            Text(
              'AQUILA',
              style: AquilaThemeExt.of(context).monoMicro(13, color: AquilaColors.accent),
            ),
            const SizedBox(height: 10),
            Text(
              'Learning, reimagined.',
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 15,
                color: AquilaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AquilaColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}