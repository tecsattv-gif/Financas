import 'package:intl/intl.dart';
import 'models.dart';

final _formatos = <String, NumberFormat>{};

/// Formata um valor na moeda indicada (padrão Real). Ex.: R$ 1.234,56 · US$ 10,00 · € 5,50
String moeda(double v, [String codigo = 'BRL']) {
  final m = moedaDe(codigo);
  final f = _formatos.putIfAbsent(
      m.codigo, () => NumberFormat.currency(locale: 'pt_BR', symbol: m.simbolo));
  return f.format(v);
}

String mesAno(DateTime d) {
  final s = DateFormat('MMMM y', 'pt_BR').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String diaTitulo(DateTime d) {
  final hoje = DateTime.now();
  final ontem = hoje.subtract(const Duration(days: 1));
  bool mesmo(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  if (mesmo(d, hoje)) return 'Hoje';
  if (mesmo(d, ontem)) return 'Ontem';
  final s = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String dataCurta(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// Aceita "1.234,56", "1234,56", "12.5" ou "12" (com ou sem símbolo da moeda).
double? lerValor(String s) {
  var t = s
      .replaceAll('R\$', '')
      .replaceAll('US\$', '')
      .replaceAll('€', '')
      .replaceAll(' ', '')
      .trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(t);
}
