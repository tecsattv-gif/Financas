import 'package:flutter/material.dart';

enum Tipo { receita, despesa }

class Lancamento {
  final String id;
  final Tipo tipo;
  final double valor;
  final String descricao;
  final String categoria;
  final DateTime data;

  const Lancamento({
    required this.id,
    required this.tipo,
    required this.valor,
    required this.descricao,
    required this.categoria,
    required this.data,
  });

  /// Valor com sinal: receitas positivas, despesas negativas.
  double get comSinal => tipo == Tipo.receita ? valor : -valor;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'valor': valor,
        'descricao': descricao,
        'categoria': categoria,
        'data': data.toIso8601String(),
      };

  factory Lancamento.fromJson(Map<String, dynamic> j) => Lancamento(
        id: j['id'] as String,
        tipo: j['tipo'] == 'receita' ? Tipo.receita : Tipo.despesa,
        valor: (j['valor'] as num).toDouble(),
        descricao: (j['descricao'] ?? '') as String,
        categoria: (j['categoria'] ?? 'Outros') as String,
        data: DateTime.parse(j['data'] as String),
      );
}

class Categoria {
  final String nome;
  final IconData icone;
  final Color cor;
  const Categoria(this.nome, this.icone, this.cor);
}

const categoriasDespesa = <Categoria>[
  Categoria('Alimentação', Icons.restaurant, Color(0xFFE76F51)),
  Categoria('Mercado', Icons.shopping_cart, Color(0xFFF4A261)),
  Categoria('Moradia', Icons.home, Color(0xFF2A9D8F)),
  Categoria('Contas', Icons.receipt_long, Color(0xFF457B9D)),
  Categoria('Transporte', Icons.directions_car, Color(0xFF8E7DBE)),
  Categoria('Saúde', Icons.favorite, Color(0xFFD62828)),
  Categoria('Educação', Icons.school, Color(0xFF3A86FF)),
  Categoria('Lazer', Icons.celebration, Color(0xFFFFB703)),
  Categoria('Compras', Icons.shopping_bag, Color(0xFFB5838D)),
  Categoria('Outros', Icons.more_horiz, Color(0xFF8D99AE)),
];

const categoriasReceita = <Categoria>[
  Categoria('Salário', Icons.work, Color(0xFF2A9D8F)),
  Categoria('Extra', Icons.add_card, Color(0xFF52B788)),
  Categoria('Vendas', Icons.storefront, Color(0xFF40916C)),
  Categoria('Investimentos', Icons.trending_up, Color(0xFF1B998B)),
  Categoria('Outros', Icons.more_horiz, Color(0xFF8D99AE)),
];

List<Categoria> categoriasDe(Tipo t) =>
    t == Tipo.receita ? categoriasReceita : categoriasDespesa;

Categoria categoria(String nome, Tipo t) => categoriasDe(t).firstWhere(
      (c) => c.nome == nome,
      orElse: () => categoriasDe(t).last,
    );
