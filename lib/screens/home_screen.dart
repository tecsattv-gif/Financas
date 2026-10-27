import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../format.dart';
import '../models.dart';
import '../pdf_report.dart';
import '../store.dart';
import '../widgets/donut_chart.dart';
import 'edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  void _mudarMes(int delta) =>
      setState(() => _mes = DateTime(_mes.year, _mes.month + delta));

  Future<void> _novo(Tipo tipo) async {
    final agora = DateTime.now();
    // Se estiver vendo outro mês, o lançamento novo já vem nesse mês.
    final data = (_mes.year == agora.year && _mes.month == agora.month)
        ? agora
        : DateTime(_mes.year, _mes.month, 1);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(tipo: tipo, data: data)),
    );
  }

  Future<void> _editar(Lancamento l) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => EditScreen(item: l)));

  Future<void> _exportar() async {
    final opcao = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Exportar ${mesAno(_mes)} (valores em Real)',
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFD64545)),
            title: const Text('PDF — Receitas e despesas'),
            subtitle: const Text('Relatório completo com saldo do mês'),
            onTap: () => Navigator.pop(ctx, 'tudo'),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_downward, color: Color(0xFF2E9E5B)),
            title: const Text('PDF — Só receitas'),
            onTap: () => Navigator.pop(ctx, 'receitas'),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_upward, color: Color(0xFFD64545)),
            title: const Text('PDF — Só despesas'),
            onTap: () => Navigator.pop(ctx, 'despesas'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Planilha (.csv)'),
            subtitle: const Text('Para Excel ou Google Planilhas'),
            onTap: () => Navigator.pop(ctx, 'csv'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (opcao == null) return;
    if (opcao == 'csv') return _exportarCsv();
    final conteudo = switch (opcao) {
      'receitas' => ConteudoPdf.receitas,
      'despesas' => ConteudoPdf.despesas,
      _ => ConteudoPdf.tudo,
    };
    final itens = store.doMes(_mes);
    final relevantes = switch (conteudo) {
      ConteudoPdf.receitas => itens.where((l) => l.tipo == Tipo.receita),
      ConteudoPdf.despesas => itens.where((l) => l.tipo == Tipo.despesa),
      ConteudoPdf.tudo => itens,
    };
    if (relevantes.isEmpty) {
      _aviso('Não há lançamentos neste mês para exportar');
      return;
    }
    try {
      final f = await gerarPdf(
          itens: itens, mes: _mes, conteudo: conteudo, nomeUsuario: store.nomeUsuario);
      await Share.shareXFiles([XFile(f.path, mimeType: 'application/pdf')],
          subject: 'Finanças - ${mesAno(_mes)}');
    } catch (e) {
      _aviso('Não foi possível gerar o PDF');
    }
  }

  Future<void> _exportarCsv() async {
    final itens = store.doMes(_mes);
    if (itens.isEmpty) {
      _aviso('Não há lançamentos neste mês para exportar');
      return;
    }
    final dir = await getTemporaryDirectory();
    final nome =
        'Financas ${_mes.year}-${_mes.month.toString().padLeft(2, '0')}.csv';
    final f = File('${dir.path}/$nome');
    // BOM para o Excel reconhecer os acentos.
    await f.writeAsString('\uFEFF${store.csv(itens)}');
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')],
        subject: 'Finanças - ${mesAno(_mes)}');
  }

  Future<void> _configurarNome() async {
    final ctrl = TextEditingController(text: store.nomeUsuario);
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seu nome'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v),
          decoration: const InputDecoration(
            labelText: 'Nome',
            helperText: 'Aparece no topo dos relatórios em PDF',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (nome == null) return;
    await store.salvarNome(nome);
    if (mounted) _aviso(nome.trim().isEmpty ? 'Nome removido' : 'Nome salvo');
  }

  void _aviso(String m, {SnackBarAction? acao}) {
    final sm = ScaffoldMessenger.of(context);
    sm.hideCurrentSnackBar();
    sm.showSnackBar(SnackBar(content: Text(m), action: acao));
  }

  Future<void> _remover(Lancamento l) async {
    await store.remover(l.id);
    if (!mounted) return;
    _aviso('Lançamento apagado',
        acao: SnackBarAction(label: 'Desfazer', onPressed: () => store.salvar(l)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
        actions: [
          IconButton(
            tooltip: 'Seu nome (para os PDFs)',
            icon: const Icon(Icons.person_outline),
            onPressed: _configurarNome,
          ),
          IconButton(
            tooltip: 'Exportar (PDF ou planilha)',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportar,
          ),
        ],
      ),
      floatingActionButton: _BotaoNovo(onNovo: _novo),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final itens = store.doMes(_mes);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              _SeletorMes(
                  mes: _mes,
                  onAnterior: () => _mudarMes(-1),
                  onProximo: () => _mudarMes(1)),
              const SizedBox(height: 8),
              _Resumo(itens: itens),
              const SizedBox(height: 12),
              _Grafico(itens: itens),
              const SizedBox(height: 8),
              if (itens.isEmpty)
                const _Vazio()
              else
                ..._lista(itens),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _lista(List<Lancamento> itens) {
    final out = <Widget>[];
    DateTime? dia;
    for (final l in itens) {
      final d = DateTime(l.data.year, l.data.month, l.data.day);
      if (dia != d) {
        dia = d;
        final totalDia = itens
            .where((x) =>
                x.data.year == d.year &&
                x.data.month == d.month &&
                x.data.day == d.day)
            .fold<double>(0, (s, x) => s + x.comSinal);
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Row(children: [
            Expanded(
              child: Text(diaTitulo(d),
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(moeda(totalDia),
                style: Theme.of(context).textTheme.labelMedium),
          ]),
        ));
      }
      out.add(_ItemLancamento(
        item: l,
        onTap: () => _editar(l),
        onRemover: () => _remover(l),
      ));
    }
    return out;
  }
}

class _SeletorMes extends StatelessWidget {
  const _SeletorMes(
      {required this.mes, required this.onAnterior, required this.onProximo});
  final DateTime mes;
  final VoidCallback onAnterior, onProximo;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
          tooltip: 'Mês anterior',
          onPressed: onAnterior,
          icon: const Icon(Icons.chevron_left)),
      Expanded(
        child: Text(mesAno(mes),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ),
      IconButton(
          tooltip: 'Próximo mês',
          onPressed: onProximo,
          icon: const Icon(Icons.chevron_right)),
    ]);
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.itens});
  final List<Lancamento> itens;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final receitas = itens
        .where((l) => l.tipo == Tipo.receita)
        .fold<double>(0, (s, l) => s + l.valorReal);
    final despesas = itens
        .where((l) => l.tipo == Tipo.despesa)
        .fold<double>(0, (s, l) => s + l.valorReal);
    final estrangeiras = itens.any((l) => l.moeda != 'BRL');
    final saldo = receitas - despesas;
    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(estrangeiras ? 'Saldo do mês (convertido para Real)' : 'Saldo do mês',
              style: TextStyle(color: cs.onPrimaryContainer)),
          const SizedBox(height: 4),
          Text(moeda(saldo),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: saldo < 0 ? cs.error : cs.onPrimaryContainer)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _Mini(
                    icone: Icons.arrow_downward,
                    rotulo: 'Receitas',
                    valor: receitas,
                    cor: const Color(0xFF2E9E5B))),
            const SizedBox(width: 12),
            Expanded(
                child: _Mini(
                    icone: Icons.arrow_upward,
                    rotulo: 'Despesas',
                    valor: despesas,
                    cor: const Color(0xFFD64545))),
          ]),
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(
      {required this.icone,
      required this.rotulo,
      required this.valor,
      required this.cor});
  final IconData icone;
  final String rotulo;
  final double valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        CircleAvatar(
            radius: 14,
            backgroundColor: cor.withOpacity(0.15),
            child: Icon(icone, size: 16, color: cor)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rotulo, style: Theme.of(context).textTheme.labelSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(moeda(valor),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Grafico extends StatelessWidget {
  const _Grafico({required this.itens});
  final List<Lancamento> itens;

  @override
  Widget build(BuildContext context) {
    final porCat = <String, double>{};
    for (final l in itens.where((l) => l.tipo == Tipo.despesa)) {
      porCat[l.categoria] = (porCat[l.categoria] ?? 0) + l.valorReal;
    }
    if (porCat.isEmpty) return const SizedBox.shrink();
    final total = porCat.values.fold<double>(0, (s, v) => s + v);
    final ordem = porCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final fatias = [
      for (final e in ordem)
        Fatia(e.value, categoria(e.key, Tipo.despesa).cor),
    ];
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Despesas por categoria',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            DonutChart(
              fatias: fatias,
              size: 120,
              child: Text('${ordem.length}\ncateg.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                for (final e in ordem.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: categoria(e.key, Tipo.despesa).cor,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(e.key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13))),
                      Text('${(e.value / total * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ItemLancamento extends StatelessWidget {
  const _ItemLancamento(
      {required this.item, required this.onTap, required this.onRemover});
  final Lancamento item;
  final VoidCallback onTap;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final cat = categoria(item.categoria, item.tipo);
    final receita = item.tipo == Tipo.receita;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => onRemover(),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: cat.cor.withOpacity(0.15),
            child: Icon(cat.icone, color: cat.cor, size: 20),
          ),
          title: Text(
              item.descricao.isEmpty ? cat.nome : item.descricao,
              overflow: TextOverflow.ellipsis),
          subtitle: item.descricao.isEmpty ? null : Text(cat.nome),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${receita ? '+' : '-'} ${moeda(item.valor, item.moeda)}',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: receita
                        ? const Color(0xFF2E9E5B)
                        : const Color(0xFFD64545)),
              ),
              if (item.moeda != 'BRL')
                Text('≈ ${moeda(item.valorReal)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(children: [
        Icon(Icons.account_balance_wallet_outlined,
            size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        const Text('Nenhum lançamento neste mês',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Toque em "Novo" para registrar uma receita ou despesa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      ]),
    );
  }
}

class _BotaoNovo extends StatelessWidget {
  const _BotaoNovo({required this.onNovo});
  final void Function(Tipo) onNovo;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final t = await showModalBottomSheet<Tipo>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0x262E9E5B),
                    child: Icon(Icons.arrow_downward, color: Color(0xFF2E9E5B))),
                title: const Text('Receita'),
                subtitle: const Text('Dinheiro que entrou'),
                onTap: () => Navigator.pop(ctx, Tipo.receita),
              ),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0x26D64545),
                    child: Icon(Icons.arrow_upward, color: Color(0xFFD64545))),
                title: const Text('Despesa'),
                subtitle: const Text('Dinheiro que saiu'),
                onTap: () => Navigator.pop(ctx, Tipo.despesa),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
        if (t != null) onNovo(t);
      },
      icon: const Icon(Icons.add),
      label: const Text('Novo'),
    );
  }
}
