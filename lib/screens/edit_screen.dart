import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cambio.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';

/// Novo lançamento ou edição de um existente.
class EditScreen extends StatefulWidget {
  const EditScreen({super.key, this.item, this.tipo, this.data});
  final Lancamento? item;
  final Tipo? tipo;
  final DateTime? data;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late Tipo _tipo;
  late DateTime _data;
  late String _categoria;
  late String _moeda;
  final _cotacao = TextEditingController();
  String _infoCotacao = '';
  bool _buscandoCotacao = false;
  final _valor = TextEditingController();
  final _descricao = TextEditingController();
  String? _erro;

  bool get _editando => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _tipo = it?.tipo ?? widget.tipo ?? Tipo.despesa;
    _data = it?.data ?? widget.data ?? DateTime.now();
    _categoria = it?.categoria ?? categoriasDe(_tipo).first.nome;
    _moeda = it?.moeda ?? store.moedaAtual;
    if (it != null && it.moeda != 'BRL') {
      _cotacao.text = _fmtCotacao(it.cotacao);
      _infoCotacao = 'Cotação guardada neste lançamento';
    } else if (_moeda != 'BRL') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _atualizarCotacao());
    }
    if (it != null) {
      _valor.text = it.valor.toStringAsFixed(2).replaceAll('.', ',');
      _descricao.text = it.descricao;
    }
  }

  static String _fmtCotacao(double v) => v.toStringAsFixed(4).replaceAll('.', ',');

  Future<void> _atualizarCotacao() async {
    final codigo = _moeda;
    if (codigo == 'BRL') return;
    setState(() {
      _buscandoCotacao = true;
      _infoCotacao = 'Buscando cotação...';
    });
    final c = await Cambio.obter(codigo);
    if (!mounted || codigo != _moeda) return;
    setState(() {
      _buscandoCotacao = false;
      if (c == null) {
        _infoCotacao = 'Sem internet. Digite a cotação manualmente.';
      } else {
        _cotacao.text = _fmtCotacao(c.valor);
        _infoCotacao = c.online
            ? 'Cotação de hoje (${dataCurta(c.data)})'
            : 'Sem internet: usando a última cotação (${dataCurta(c.data)})';
      }
    });
  }

  void _trocarMoeda(String codigo) {
    setState(() {
      _moeda = codigo;
      _cotacao.clear();
      _infoCotacao = '';
    });
    store.trocarMoeda(codigo);
    if (codigo != 'BRL') _atualizarCotacao();
  }

  @override
  void dispose() {
    _cotacao.dispose();
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  void _trocarTipo(Tipo t) {
    setState(() {
      _tipo = t;
      if (!categoriasDe(t).any((c) => c.nome == _categoria)) {
        _categoria = categoriasDe(t).first.nome;
      }
    });
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _data = DateTime(d.year, d.month, d.day, _data.hour, _data.minute));
    }
  }

  Future<void> _salvar() async {
    final v = lerValor(_valor.text);
    if (v == null || v <= 0) {
      setState(() => _erro = 'Digite um valor maior que zero');
      return;
    }
    var cotacao = 1.0;
    if (_moeda != 'BRL') {
      final c = lerValor(_cotacao.text);
      if (c == null || c <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Informe a cotação para converter para Real')));
        return;
      }
      cotacao = c;
    }
    await store.salvar(Lancamento(
      id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      tipo: _tipo,
      valor: v,
      descricao: _descricao.text.trim(),
      categoria: _categoria,
      data: _data,
      moeda: _moeda,
      cotacao: cotacao,
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _apagar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar lançamento?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await store.remover(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _novaCategoria() async {
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => _NovaCategoriaDialog(tipo: _tipo),
    );
    if (nome != null && mounted) setState(() => _categoria = nome);
  }

  Future<void> _opcoesCategoria(Categoria c) async {
    if (!c.personalizada) return;
    final usos = store.usoDaCategoria(c.nome, _tipo);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apagar a categoria "${c.nome}"?'),
        content: Text(usos == 0
            ? 'Nenhum lançamento usa esta categoria.'
            : '$usos lançamento(s) usam esta categoria e passarão para "Outros".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await store.apagarCategoria(c.nome, _tipo);
    if (!mounted) return;
    setState(() {
      if (_categoria == c.nome) _categoria = 'Outros';
    });
  }

  @override
  Widget build(BuildContext context) {
    final receita = _tipo == Tipo.receita;
    final cor = receita ? const Color(0xFF2E9E5B) : const Color(0xFFD64545);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar lançamento' : 'Novo lançamento'),
        actions: [
          if (_editando)
            IconButton(
                tooltip: 'Apagar',
                onPressed: _apagar,
                icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<Tipo>(
            segments: const [
              ButtonSegment(
                  value: Tipo.despesa,
                  label: Text('Despesa'),
                  icon: Icon(Icons.arrow_upward)),
              ButtonSegment(
                  value: Tipo.receita,
                  label: Text('Receita'),
                  icon: Icon(Icons.arrow_downward)),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => _trocarTipo(s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _valor,
            autofocus: !_editando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: cor),
            onChanged: (_) => setState(() => _erro = null),
            decoration: InputDecoration(
              labelText: 'Valor',
              prefixText: '${moedaDe(_moeda).simbolo} ',
              hintText: '0,00',
              errorText: _erro,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final m in moedas)
                ButtonSegment(value: m.codigo, label: Text('${m.simbolo} ${m.nome}')),
            ],
            selected: {_moeda},
            onSelectionChanged: (s) => _trocarMoeda(s.first),
          ),
          if (_moeda != 'BRL') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cotacao,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Cotação: 1 ${moedaDe(_moeda).simbolo} = R\$',
                helperText: _infoCotacao.isEmpty ? null : _infoCotacao,
                border: const OutlineInputBorder(),
                suffixIcon: _buscandoCotacao
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                        tooltip: 'Atualizar cotação',
                        onPressed: _atualizarCotacao,
                        icon: const Icon(Icons.refresh)),
              ),
            ),
            Builder(builder: (context) {
              final v = lerValor(_valor.text);
              final c = lerValor(_cotacao.text);
              if (v == null || c == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text('= ${moeda(v * c)} em Real',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: cor, fontSize: 16)),
              );
            }),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _descricao,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              hintText: 'Ex.: almoço, conta de luz',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Data'),
            subtitle: Text(dataCurta(_data)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _escolherData,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: Text('Categoria',
                    style: Theme.of(context).textTheme.titleSmall)),
            Text('Segure uma categoria criada por você para apagar',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categoriasDe(_tipo))
                GestureDetector(
                  onLongPress: () => _opcoesCategoria(c),
                  child: ChoiceChip(
                    avatar: Icon(c.icone,
                        size: 18,
                        color: _categoria == c.nome ? null : c.cor),
                    label: Text(c.nome),
                    selected: _categoria == c.nome,
                    onSelected: (_) => setState(() => _categoria = c.nome),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Nova categoria'),
                onPressed: _novaCategoria,
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _salvar,
            icon: const Icon(Icons.check),
            label: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

/// Diálogo para criar uma categoria: nome, ícone e cor.
class _NovaCategoriaDialog extends StatefulWidget {
  const _NovaCategoriaDialog({required this.tipo});
  final Tipo tipo;

  @override
  State<_NovaCategoriaDialog> createState() => _NovaCategoriaDialogState();
}

class _NovaCategoriaDialogState extends State<_NovaCategoriaDialog> {
  final _nome = TextEditingController();
  int _icone = 0;
  int _cor = 5;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final erro = await store.criarCategoria(_nome.text, widget.tipo, _icone, _cor);
    if (!mounted) return;
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      Navigator.pop(context, _nome.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = coresCategoria[_cor];
    return AlertDialog(
      title: Text(widget.tipo == Tipo.receita
          ? 'Nova categoria de receita'
          : 'Nova categoria de despesa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nome,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_erro != null) setState(() => _erro = null);
              },
              onSubmitted: (_) => _criar(),
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex.: Pets, Combustível',
                errorText: _erro,
                prefixIcon: Icon(iconesCategoria[_icone], color: cor),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Ícone', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < iconesCategoria.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _icone = i),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          i == _icone ? cor : cor.withOpacity(0.12),
                      child: Icon(iconesCategoria[i],
                          size: 18, color: i == _icone ? Colors.white : cor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Cor', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < coresCategoria.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _cor = i),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: coresCategoria[i],
                      child: i == _cor
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _criar, child: const Text('Criar')),
      ],
    );
  }
}
