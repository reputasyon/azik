import 'dart:io';

import 'package:azik/main.dart';
import 'package:azik/data/store_base.dart';
import 'package:azik/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in [const Size(390, 844), const Size(1280, 850)]) {
    testWidgets('Search and checklist work at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = MemoryStore();
      await tester.pumpWidget(AzikApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('6 rehber cihazında'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ILETISIM');
      await tester.pumpAndSettle();
      expect(find.text('Aile iletişim planı'), findsOneWidget);
      expect(find.text('Şarj planını önceden yap'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Rehberi kaydet').first);
      await tester.tap(find.byTooltip('Rehberi kaydet').first);
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getStringList('saved'),
        isNotEmpty,
      );
      await tester.tap(find.text('Hazırlığım').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('1 / 6 adım tamamlandı'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getStringList('checked'), [
        'plan',
      ]);
    });
  }
}

class MemoryStore implements LibraryStore {
  ContentPack? pack = ContentPack.parse(
    File('assets/content/temel.json').readAsStringSync(),
  );
  @override
  Future<void> open() async {}
  @override
  Future<int> version() async => pack?.version ?? 0;
  @override
  Future<List<Guide>> guides() async => pack?.guides ?? [];
  @override
  Future<void> install(String text) async {
    pack = ContentPack.parse(text);
  }
}
