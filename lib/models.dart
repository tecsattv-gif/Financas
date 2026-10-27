import 'package:flutter/material.dart';

enum Tipo { receita, despesa }

// ---------------------------------------------------------------------------
// Moedas (cada lançamento tem a sua; os totais nunca misturam moedas)
// ---------------------------------------------------------------------------
class Moeda {
  final String codigo;
  final String simbolo;
  final String nome;
  const Moeda(this.codigo, this.simbolo, this.nome);
}

const moedas = <Moeda>[
  Moeda('BRL', 'R\$', 'Real'),
  Moeda('USD', 'US\$', 'Dólar'),
  Moeda('EUR', '€', 'Euro'),
];

Moeda moedaDe(String codigo) =>
    moedas.firstWhere((m) => m.codigo == codigo, orElse: () => moedas.first);

// ---------------------------------------------------------------------------
// Lançamento
// ---------------------------------------------------------------------------
class Lancamento {
  final String id;
  final Tipo tipo;
  final double valor;
  final String descricao;
  final String categoria;
  final DateTime data;
  final String moeda; // BRL | USD | EUR

  const Lancamento({
    required this.id,
    required this.tipo,
    required this.valor,
    required this.descricao,
    required this.categoria,
    required this.data,
    this.moeda = 'BRL',
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
        'moeda': moeda,
      };

  factory Lancamento.fromJson(Map<String, dynamic> j) => Lancamento(
        id: j['id'] as String,
        tipo: j['tipo'] == 'receita' ? Tipo.receita : Tipo.despesa,
        valor: (j['valor'] as num).toDouble(),
        descricao: (j['descricao'] ?? '') as String,
        categoria: (j['categoria'] ?? 'Outros') as String,
        data: DateTime.parse(j['data'] as String),
        // Lançamentos antigos (antes da opção de moeda) eram em Real.
        moeda: (j['moeda'] ?? 'BRL') as String,
      );
}

// ---------------------------------------------------------------------------
// Categorias
// ---------------------------------------------------------------------------
class Categoria {
  final String nome;
  final IconData icone;
  final Color cor;
  final bool personalizada;
  const Categoria(this.nome, this.icone, this.cor, {this.personalizada = false});
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

/// Ícones e cores que o usuário pode escolher ao criar uma categoria.
/// (Lista fixa para o ícone ser guardado pelo índice.)
const iconesCategoria = <IconData>[
  Icons.label,
  Icons.pets,
  Icons.local_gas_station,
  Icons.local_cafe,
  Icons.fastfood,
  Icons.fitness_center,
  Icons.phone_android,
  Icons.wifi,
  Icons.flight,
  Icons.child_care,
  Icons.checkroom,
  Icons.build,
  Icons.card_giftcard,
  Icons.savings,
  Icons.attach_money,
  Icons.local_hospital,
  Icons.sports_esports,
  Icons.music_note,
  Icons.volunteer_activism,
  Icons.credit_card,
];

const coresCategoria = <Color>[
  Color(0xFFE76F51),
  Color(0xFFF4A261),
  Color(0xFFFFB703),
  Color(0xFF52B788),
  Color(0xFF2A9D8F),
  Color(0xFF3A86FF),
  Color(0xFF457B9D),
  Color(0xFF8E7DBE),
  Color(0xFFB5838D),
  Color(0xFFD62828),
];

/// Categoria criada pelo usuário (guardada pelo Store).
class CategoriaExtra {
  final String nome;
  final Tipo tipo;
  final int icone; // índice em iconesCategoria
  final int cor; // índice em coresCategoria
  const CategoriaExtra(this.nome, this.tipo, this.icone, this.cor);

  Categoria get categoria => Categoria(
        nome,
        iconesCategoria[icone.clamp(0, iconesCategoria.length - 1)],
        coresCategoria[cor.clamp(0, coresCategoria.length - 1)],
        personalizada: true,
      );

  Map<String, dynamic> toJson() =>
      {'nome': nome, 'tipo': tipo.name, 'icone': icone, 'cor': cor};

  factory CategoriaExtra.fromJson(Map<String, dynamic> j) => CategoriaExtra(
        (j['nome'] ?? '') as String,
        j['tipo'] == 'receita' ? Tipo.receita : Tipo.despesa,
        (j['icone'] ?? 0) as int,
        (j['cor'] ?? 0) as int,
      );
}

/// Categorias personalizadas carregadas (preenchida pelo Store).
final List<CategoriaExtra> categoriasExtras = [];

/// Categorias do tipo: padrão + personalizadas, com "Outros" sempre no fim.
List<Categoria> categoriasDe(Tipo t) {
  final base = t == Tipo.receita ? categoriasReceita : categoriasDespesa;
  final outros = base.last;
  return [
    ...base.take(base.length - 1),
    for (final e in categoriasExtras.where((e) => e.tipo == t)) e.categoria,
    outros,
  ];
}

Categoria categoria(String nome, Tipo t) => categoriasDe(t).firstWhere(
      (c) => c.nome == nome,
      orElse: () => categoriasDe(t).last,
    );
