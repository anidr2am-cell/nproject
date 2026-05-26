import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nproject/main.dart';

void main() {
  testWidgets('shows the Nproject marketplace home', (tester) async {
    await tester.pumpWidget(const NprojectApp());

    expect(find.text('하늘상점님'), findsOneWidget);
    expect(find.text('중고거래'), findsWidgets);
    expect(find.text('해주세요'), findsWidgets);
    expect(find.text('화폐 교환'), findsWidgets);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('opens a listing detail page', (tester) async {
    await tester.pumpWidget(const NprojectApp());

    await tester.tap(find.text('아이폰 14 프로 256GB 딥퍼플'));
    await tester.pumpAndSettle();

    expect(find.text('거래 희망 장소'), findsOneWidget);
    expect(find.text('파타야 힐튼호텔 앞'), findsOneWidget);
    expect(find.text('연락처 보기'), findsOneWidget);
  });

  testWidgets('shows signup and logout menu from my page', (tester) async {
    await tester.pumpWidget(const NprojectApp());

    await tester.tap(find.text('나의 정보'));
    await tester.pumpAndSettle();

    expect(find.text('회원 가입'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);

    await tester.tap(find.text('회원 가입'));
    await tester.pumpAndSettle();

    expect(find.text('회원 가입'), findsOneWidget);
    expect(find.text('이메일 ID'), findsOneWidget);
  });

  testWidgets('shows dedicated request and currency forms', (tester) async {
    await tester.pumpWidget(const NprojectApp());

    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('해주세요'));
    await tester.pumpAndSettle();

    expect(find.text('물품명'), findsOneWidget);
    expect(find.text('배달 수수료'), findsOneWidget);
    expect(find.text('카카오톡 or 라인 ID'), findsOneWidget);

    await tester.tap(find.text('화폐 교환'));
    await tester.pumpAndSettle();

    expect(find.text('원하는 화폐'), findsOneWidget);
    expect(find.text('적용 환율'), findsOneWidget);
    expect(find.text('거래방법'), findsOneWidget);
  });
}
