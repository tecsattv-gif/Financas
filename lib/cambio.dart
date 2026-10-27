import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Cotação atual para converter Dólar e Euro em Real.
/// Busca na internet (Frankfurter / Banco Central Europeu; reserva: open.er-api.com)
/// e guarda a última cotação para usar quando estiver sem internet.
class Cotacao {
  final double valor; // quantos R$ vale 1 unidade da moeda
  final DateTime data; // quando foi obtida
  final bool online; // true = acabou de vir da internet
  const Cotacao(this.valor, this.data, this.online);
}

class Cambio {
  static const _prefixo = 'cotacao_';

  static Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final body = await res.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  /// R$ por 1 unidade da moeda, direto da internet.
  static Future<double> _buscar(String codigo) async {
    try {
      final j = await _getJson(
          'https://api.frankfurter.dev/v1/latest?base=$codigo&symbols=BRL');
      final v = (j['rates']?['BRL'] as num?)?.toDouble();
      if (v != null && v > 0) return v;
    } catch (_) {}
    final j = await _getJson('https://open.er-api.com/v6/latest/$codigo');
    final v = (j['rates']?['BRL'] as num?)?.toDouble();
    if (v == null || v <= 0) throw const FormatException('Cotação inválida');
    return v;
  }

  /// Cotação da moeda em Real. Real = 1. Sem internet, usa a última guardada.
  /// Devolve null se nunca conseguiu uma cotação para essa moeda.
  static Future<Cotacao?> obter(String codigo) async {
    if (codigo == 'BRL') return Cotacao(1, DateTime.now(), true);
    final p = await SharedPreferences.getInstance();
    try {
      final v = await _buscar(codigo);
      final agora = DateTime.now();
      await p.setString('$_prefixo$codigo',
          jsonEncode({'valor': v, 'data': agora.toIso8601String()}));
      return Cotacao(v, agora, true);
    } catch (_) {
      final raw = p.getString('$_prefixo$codigo');
      if (raw == null) return null;
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        return Cotacao((j['valor'] as num).toDouble(),
            DateTime.parse(j['data'] as String), false);
      } catch (_) {
        return null;
      }
    }
  }
}
