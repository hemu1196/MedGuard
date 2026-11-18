import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/widgets/dashboard/launch_features_section.dart';

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('Seven tools navigate at width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: LaunchFeaturesSection()),
          ),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Tool')),
              body: Text('destination:${settings.name}'),
            ),
          ),
        ),
      );
      for (final feature in LaunchFeaturesSection.features) {
        await tester.ensureVisible(find.text(feature.$2));
        await tester.tap(find.text(feature.$2));
        await tester.pumpAndSettle();
        expect(find.text('destination:${feature.$4}'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
