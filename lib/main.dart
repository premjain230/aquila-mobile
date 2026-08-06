import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase bootstrap runs inside the app's boot gate so that any failure
  // renders a branded error screen with Retry — never a bare grey surface.
  runApp(const AquilaApp());
}