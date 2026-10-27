import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'format.dart';
import 'models.dart';

/// O que entra no relatório em PDF.
enum ConteudoPdf { receitas, despesas, tudo }

const _verde = PdfColor.fromInt(0xFF2E9E5B);
const _vermelho = PdfColor.fromInt(0xFFD64545);
const _cinza = PdfColor.fromInt(0xFF6B7280);
const _fundo = PdfColor.fromInt(0xFFF1F5F4);

Future<pw.ThemeData> _tema() async {
  // Fonte com acentos e símbolos (€, R$). Se faltar, usa a padrão do PDF.
  try {
    final normal = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final negrito = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    return pw.ThemeData.withFont(base: normal, bold: negrito);
  } catch (_) {
    return pw.ThemeData.base();
  }
}

/// Gera o PDF do mês, na moeda indicada, e devolve o arquivo.
Future<File> gerarPdf({
  required List<Lancamento> itens,
  required DateTime mes,
  required ConteudoPdf conteudo,
  String nomeUsuario = '',
}) async {
  String fmt(double v) => moeda(v);
  final temEstrangeira = itens.any((l) => l.moeda != 'BRL');

  final receitas = itens.where((l) => l.tipo == Tipo.receita).toList()
    ..sort((a, b) => a.data.compareTo(b.data));
  final despesas = itens.where((l) => l.tipo == Tipo.despesa).toList()
    ..sort((a, b) => a.data.compareTo(b.data));
  final totalR = receitas.fold<double>(0, (s, l) => s + l.valorReal);
  final totalD = despesas.fold<double>(0, (s, l) => s + l.valorReal);

  final titulo = switch (conteudo) {
    ConteudoPdf.receitas => 'Relatório de Receitas',
    ConteudoPdf.despesas => 'Relatório de Despesas',
    ConteudoPdf.tudo => 'Relatório Financeiro',
  };

  pw.Widget resumoLinha(String rotulo, double v, PdfColor cor, {bool forte = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(rotulo,
                  style: pw.TextStyle(
                      fontWeight: forte ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Text(fmt(v),
              style: pw.TextStyle(color: cor, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  pw.Widget porCategoria(List<Lancamento> lista, Tipo tipo, double total) {
    final mapa = <String, double>{};
    for (final l in lista) {
      mapa[l.categoria] = (mapa[l.categoria] ?? 0) + l.valorReal;
    }
    final ordem = mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return pw.TableHelper.fromTextArray(
      headers: ['Categoria', 'Valor', '%'],
      data: [
        for (final e in ordem)
          [
            e.key,
            fmt(e.value),
            total > 0 ? '${(e.value / total * 100).toStringAsFixed(1).replaceAll('.', ',')}%' : '-',
          ],
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: tipo == Tipo.receita ? _verde : _vermelho),
      cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
      cellStyle: const pw.TextStyle(fontSize: 10),
      border: null,
      rowDecoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
    );
  }

  pw.Widget tabela(List<Lancamento> lista, Tipo tipo, double total) {
    final cor = tipo == Tipo.receita ? _verde : _vermelho;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.TableHelper.fromTextArray(
        headers: [
          'Data',
          'Categoria',
          'Descrição',
          if (temEstrangeira) 'Valor original',
          'Valor (R\$)',
        ],
        data: [
          for (final l in lista)
            [
              dataCurta(l.data),
              l.categoria,
              l.descricao.isEmpty ? '-' : l.descricao,
              if (temEstrangeira)
                l.moeda == 'BRL'
                    ? '-'
                    : '${moeda(l.valor, l.moeda)}\n'
                        '(1 ${moedaDe(l.moeda).simbolo} = ${moeda(l.cotacao)})',
              fmt(l.valorReal),
            ],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: cor),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignments: temEstrangeira
            ? {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight}
            : {3: pw.Alignment.centerRight},
        columnWidths: temEstrangeira
            ? {
                0: const pw.FixedColumnWidth(58),
                1: const pw.FixedColumnWidth(80),
                2: const pw.FlexColumnWidth(),
                3: const pw.FixedColumnWidth(95),
                4: const pw.FixedColumnWidth(80),
              }
            : {
                0: const pw.FixedColumnWidth(62),
                1: const pw.FixedColumnWidth(95),
                2: const pw.FlexColumnWidth(),
                3: const pw.FixedColumnWidth(85),
              },
        border: null,
        rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text('Total (${lista.length} lançamento${lista.length == 1 ? '' : 's'})',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Text(fmt(total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: cor)),
        ]),
      ),
    ]);
  }

  pw.Widget secao(String nome, List<Lancamento> lista, Tipo tipo, double total) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(height: 14),
        pw.Text(nome,
            style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: tipo == Tipo.receita ? _verde : _vermelho)),
        pw.SizedBox(height: 6),
        if (lista.isEmpty)
          pw.Text('Nenhum lançamento neste mês.', style: const pw.TextStyle(color: _cinza))
        else ...[
          porCategoria(lista, tipo, total),
          pw.SizedBox(height: 10),
          tabela(lista, tipo, total),
        ],
      ]);

  final doc = pw.Document(
      theme: await _tema(),
      title: titulo,
      author: nomeUsuario.trim().isEmpty ? 'Finanças' : nomeUsuario.trim());
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children: [
        pw.Expanded(
            child: pw.Text(titulo,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
        pw.Text('Finanças', style: const pw.TextStyle(color: _cinza)),
      ]),
      pw.SizedBox(height: 2),
      if (nomeUsuario.trim().isNotEmpty)
        pw.Text('Nome: ${nomeUsuario.trim()}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.Text(
          temEstrangeira
              ? '${mesAno(mes)} · valores convertidos para Real (cotação do dia de cada lançamento)'
              : mesAno(mes),
          style: const pw.TextStyle(color: _cinza)),
      pw.Divider(color: PdfColors.grey400),
    ]),
    footer: (ctx) => pw.Row(children: [
      pw.Text('Gerado em ${dataCurta(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: _cinza)),
      pw.Spacer(),
      pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: _cinza)),
    ]),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: _fundo, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(children: [
          if (conteudo != ConteudoPdf.despesas) resumoLinha('Receitas', totalR, _verde),
          if (conteudo != ConteudoPdf.receitas) resumoLinha('Despesas', totalD, _vermelho),
          if (conteudo == ConteudoPdf.tudo) ...[
            pw.Divider(color: PdfColors.grey400),
            resumoLinha('Saldo do mês', totalR - totalD,
                totalR - totalD < 0 ? _vermelho : _verde,
                forte: true),
          ],
        ]),
      ),
      if (conteudo != ConteudoPdf.despesas) secao('Receitas', receitas, Tipo.receita, totalR),
      if (conteudo != ConteudoPdf.receitas) secao('Despesas', despesas, Tipo.despesa, totalD),
    ],
  ));

  final dir = await getTemporaryDirectory();
  final parte = switch (conteudo) {
    ConteudoPdf.receitas => 'Receitas',
    ConteudoPdf.despesas => 'Despesas',
    ConteudoPdf.tudo => 'Relatorio',
  };
  final nome =
      'Financas $parte ${mes.year}-${mes.month.toString().padLeft(2, '0')}.pdf';
  final f = File('${dir.path}/$nome');
  await f.writeAsBytes(await doc.save());
  return f;
}
