import 'package:azik/main.dart';
import 'package:azik/data/store_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets('Search, saved guides and checklist work without a network', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = ContentStore(
      testFactory: databaseFactoryFfiNoIsolate,
      testPath: inMemoryDatabasePath,
    );
    addTearDown(store.close);
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
