import 'package:cuida_plus/core/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EmptyState mostra título e subtítulo', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: EmptyState(icon: Icons.inbox, title: 'Vazio', subtitle: 'Nada por aqui'))));
    expect(find.text('Vazio'), findsOneWidget);
    expect(find.text('Nada por aqui'), findsOneWidget);
  });
  testWidgets('ErrorView exibe botão de nova tentativa', (t) async {
    var tapped = false;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ErrorView(message: 'Sem conexão', onRetry: () => tapped = true))));
    await t.tap(find.text('Tentar novamente'));
    expect(tapped, isTrue);
  });
}
