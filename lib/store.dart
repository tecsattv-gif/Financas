import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Guarda os lançamentos no próprio celular.
class Store extends ChangeNotifier {
  static const _key = 'lancamentos_v1';
  final List<Lancamento> _itens = [];

  List<Lancamento> get todos => List.unmodifiable(_itens);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    _itens.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _itens.addAll(list.map(
            (e) => Lancamento.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
    _ordenar();
    notifyListeners();
  }

  void _ordenar() => _itens.sort((a, b) => b.data.compareTo(a.data));

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_itens.map((e) => e.toJson()).toList()));
  }

  List<Lancamento> doMes(DateTime mes) => _itens
      .where((l) => l.data.year == mes.year && l.data.month == mes.month)
      .toList();

  Future<void> salvar(Lancamento l) async {
    final i = _itens.indexWhere((e) => e.id == l.id);
    if (i >= 0) {
      _itens[i] = l;
    } else {
      _itens.add(l);
    }
    _ordenar();
    notifyListeners();
    await _persist();
  }

  Future<void> remover(String id) async {
    _itens.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }

  /// Planilha simples (abre no Excel e no Google Planilhas).
  String csv(List<Lancamento> itens) {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Data;Tipo;Categoria;Descrição;Valor\n');
    for (final l in itens) {
      final d = l.data;
      final data =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      final valor = l.comSinal.toStringAsFixed(2).replaceAll('.', ',');
      b.writeln(
          '$data;${l.tipo == Tipo.receita ? 'Receita' : 'Despesa'};${q(l.categoria)};${q(l.descricao)};$valor');
    }
    return b.toString();
  }
}

final store = Store();
