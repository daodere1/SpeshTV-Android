import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/theme/app_theme.dart';
import 'package:moonfin_design/moonfin_design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final spec = ThemeRegistry.resolveById('spesh-cinematic');
  final theme = AppTheme.buildTheme(spec);
  final c = spec.colors;
  test('Cinematic supplies Material container roles instead of purple defaults', () {
    expect(theme.colorScheme.primary, c.accent);
    expect(theme.colorScheme.primaryContainer, c.surfaceVariant);
    expect(theme.colorScheme.secondaryContainer, c.accent);
    expect(theme.colorScheme.onSecondaryContainer, c.onAccent);
    expect(theme.colorScheme.tertiaryContainer, c.surfaceVariant);
    expect(theme.colorScheme.surfaceContainerHigh, c.surfaceVariant);
    expect(theme.colorScheme.surfaceTint, Colors.transparent);
    expect(theme.textSelectionTheme.selectionHandleColor, c.inputBorderFocused);
  });
  test('Back and icon buttons use neutral surfaces and a blue focus ring', () {
    final style = theme.iconButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), c.buttonNormal);
    expect(style.foregroundColor!.resolve({}), c.accent);
    expect(style.foregroundColor!.resolve({WidgetState.disabled}), c.onButtonDisabled);
    expect(style.side!.resolve({WidgetState.focused})!.color, c.inputBorderFocused);
  });
  test('Search selections use gold with dark text and disabled text stays muted', () {
    final style = theme.segmentedButtonTheme.style!;
    expect(style.backgroundColor!.resolve({WidgetState.selected}), c.accent);
    expect(style.foregroundColor!.resolve({WidgetState.selected}), c.onAccent);
    expect(style.foregroundColor!.resolve({WidgetState.disabled}), c.onButtonDisabled);
    expect(style.backgroundColor!.resolve({}), c.surface);
  });
}
