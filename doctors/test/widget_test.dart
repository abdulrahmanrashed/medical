// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:doctors/app/medical_records_app.dart';

void main() {
  testWidgets('App shows role selection', (WidgetTester tester) async {
    await tester.pumpWidget(const MedicalRecordsApp());

    expect(find.text('Sign in (demo roles)'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Patient'), findsOneWidget);
  });
}
