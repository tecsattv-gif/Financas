import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (it != null) {
      _valor.text = it.valor.toStringAsFixed(2).replaceAll('.', ',');
      _descricao.text = it.descricao;
    }
  }

  @override
  void dispose() {
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
    await store.salvar(Lancamento(
      id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      tipo: _tipo,
      valor: v,
      descricao: _descricao.text.trim(),
      categoria: _categoria,
      data: _data,
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
            onChanged: (_) {
              if (_erro != null) setState(() => _erro = null);
            },
            decoration: InputDecoration(
              labelText: 'Valor',
              prefixText: 'R\$ ',
              hintText: '0,00',
              errorText: _erro,
              border: const OutlineInputBorder(),
            ),
          ),
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
          Text('Categoria', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categoriasDe(_tipo))
                ChoiceChip(
                  avatar: Icon(c.icone,
                      size: 18,
                      color: _categoria == c.nome ? null : c.cor),
                  label: Text(c.nome),
                  selected: _categoria == c.nome,
                  onSelected: (_) => setState(() => _categoria = c.nome),
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
