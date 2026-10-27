import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Guarda os lançamentos, as categorias criadas e a moeda escolhida no próprio celular.
class Store extends ChangeNotifier {
  static const _key = 'lancamentos_v1';
  static const _keyCategorias = 'categorias_v1';
  static const _keyMoeda = 'moeda_atual';
  static const _keyNome = 'nome_usuario';
  String _nome = '';

  /// Nome do usuário (aparece nos PDFs).
  String get nomeUsuario => _nome;

  Future<void> salvarNome(String nome) async {
    _nome = nome.trim();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyNome, _nome);
  }
  final List<Lancamento> _itens = [];
  String _moedaAtual = 'BRL';

  List<Lancamento> get todos => List.unmodifiable(_itens);

  /// Última moeda usada (padrão dos novos lançamentos).
  String get moedaAtual => _moedaAtual;

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
    categoriasExtras.clear();
    final rawCat = p.getString(_keyCategorias);
    if (rawCat != null) {
      try {
        final list = jsonDecode(rawCat) as List;
        categoriasExtras.addAll(list.map(
            (e) => CategoriaExtra.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
    _moedaAtual = moedaDe(p.getString(_keyMoeda) ?? 'BRL').codigo;
    _nome = p.getString(_keyNome) ?? '';
    _ordenar();
    notifyListeners();
  }

  void _ordenar() => _itens.sort((a, b) => b.data.compareTo(a.data));

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_itens.map((e) => e.toJson()).toList()));
  }

  Future<void> _persistCategorias() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _keyCategorias, jsonEncode(categoriasExtras.map((e) => e.toJson()).toList()));
  }

  Future<void> trocarMoeda(String codigo) async {
    _moedaAtual = moedaDe(codigo).codigo;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyMoeda, _moedaAtual);
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

  // --- Categorias personalizadas -------------------------------------------

  /// Cria uma categoria. Devolve uma mensagem de erro, ou null se deu certo.
  Future<String?> criarCategoria(String nome, Tipo tipo, int icone, int cor) async {
    final n = nome.trim();
    if (n.isEmpty) return 'Digite o nome da categoria';
    if (n.length > 30) return 'Nome muito longo (máx. 30 letras)';
    final existe = categoriasDe(tipo)
        .any((c) => c.nome.toLowerCase() == n.toLowerCase());
    if (existe) return 'Já existe uma categoria com esse nome';
    categoriasExtras.add(CategoriaExtra(n, tipo, icone, cor));
    notifyListeners();
    await _persistCategorias();
    return null;
  }

  /// Quantos lançamentos usam a categoria.
  int usoDaCategoria(String nome, Tipo tipo) =>
      _itens.where((l) => l.tipo == tipo && l.categoria == nome).length;

  /// Apaga a categoria; os lançamentos que a usavam passam para "Outros".
  Future<void> apagarCategoria(String nome, Tipo tipo) async {
    categoriasExtras.removeWhere((e) => e.nome == nome && e.tipo == tipo);
    var mudou = false;
    for (var i = 0; i < _itens.length; i++) {
      final l = _itens[i];
      if (l.tipo == tipo && l.categoria == nome) {
        _itens[i] = Lancamento(
          id: l.id,
          tipo: l.tipo,
          valor: l.valor,
          descricao: l.descricao,
          categoria: 'Outros',
          data: l.data,
          moeda: l.moeda,
          cotacao: l.cotacao,
        );
        mudou = true;
      }
    }
    notifyListeners();
    await _persistCategorias();
    if (mudou) await _persist();
  }

  /// Planilha simples (abre no Excel e no Google Planilhas).
  String csv(List<Lancamento> itens) {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    String n(double v, [int casas = 2]) => v.toStringAsFixed(casas).replaceAll('.', ',');
    final b = StringBuffer(
        'Data;Tipo;Categoria;Descrição;Moeda;Valor original;Cotação (R\$);Valor em R\$\n');
    for (final l in itens) {
      final d = l.data;
      final data =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      final sinal = l.tipo == Tipo.receita ? 1 : -1;
      b.writeln('$data;${l.tipo == Tipo.receita ? 'Receita' : 'Despesa'};'
          '${q(l.categoria)};${q(l.descricao)};${l.moeda};${n(sinal * l.valor)};'
          '${n(l.moeda == 'BRL' ? 1 : l.cotacao, 4)};${n(l.comSinal)}');
    }
    return b.toString();
  }
}

final store = Store();
