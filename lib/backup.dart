import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backup automático numa pasta pública (Documentos/Financas), que não é
/// apagada quando o app é desinstalado.
///
/// Depois de reinstalar, o Android não deixa o app novo ler sozinho os
/// arquivos da instalação anterior, por isso a restauração passa pelo
/// seletor de arquivos (um toque para escolher o backup).
class Backup {
  static const pasta = '/storage/emulated/0/Documents/Financas';
  static const pastaLegivel = 'Documentos › Financas';
  static const _keyNome = 'backup_arquivo';
  static const _keyPerguntou = 'backup_restauracao_perguntada';

  Future<void> _fila = Future.value();

  /// Cada instalação grava no seu próprio arquivo, porque o Android não deixa
  /// sobrescrever o arquivo criado por uma instalação anterior.
  Future<String> _arquivo() async {
    final p = await SharedPreferences.getInstance();
    var nome = p.getString(_keyNome);
    if (nome == null) {
      final d = DateTime.now();
      String dois(int n) => n.toString().padLeft(2, '0');
      nome = 'financas-backup-${d.year}-${dois(d.month)}-${dois(d.day)}'
          '_${dois(d.hour)}${dois(d.minute)}${dois(d.second)}.json';
      await p.setString(_keyNome, nome);
    }
    return '$pasta/$nome';
  }

  /// Grava o backup. Nunca lança erro: se falhar, o app segue normalmente.
  void salvar(Map<String, dynamic> dados) {
    _fila = _fila.then((_) async {
      final texto = jsonEncode(dados);
      for (var tentativa = 0; tentativa < 2; tentativa++) {
        try {
          await Directory(pasta).create(recursive: true);
          final caminho = await _arquivo();
          final tmp = File('$caminho.tmp');
          await tmp.writeAsString(texto, flush: true);
          await tmp.rename(caminho);
          return;
        } catch (_) {
          // O arquivo pode ser de uma instalação anterior (sem permissão de
          // escrita): passa a usar um arquivo novo e tenta de novo.
          await (await SharedPreferences.getInstance()).remove(_keyNome);
        }
      }
    });
  }

  /// Se a pergunta de restauração já foi feita nesta instalação.
  Future<bool> jaPerguntou() async =>
      (await SharedPreferences.getInstance()).getBool(_keyPerguntou) ?? false;

  Future<void> marcarPerguntou() async =>
      (await SharedPreferences.getInstance()).setBool(_keyPerguntou, true);

  /// Abre o seletor de arquivos e devolve o conteúdo do backup escolhido,
  /// ou null se o usuário cancelar.
  Future<String?> escolherArquivo() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final f = (r == null || r.files.isEmpty) ? null : r.files.first;
    if (f == null) return null;
    if (f.bytes != null) return utf8.decode(f.bytes!);
    if (f.path != null) return File(f.path!).readAsString();
    return null;
  }
}

final backup = Backup();
