import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => message;
}

/// A escrita foi aceita localmente (cache do Firestore), mas ainda não confirmada pelo servidor.
class PendingSyncException extends AppException {
  const PendingSyncException()
      : super('Sem conexão no momento. A alteração foi salva no aparelho e será sincronizada automaticamente.');
}

String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'user-disabled':
      return 'Esta conta foi desativada.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'E-mail ou senha incorretos.';
    case 'email-already-in-use':
      return 'Já existe uma conta com este e-mail.';
    case 'weak-password':
      return 'Senha fraca. Use ao menos 8 caracteres, com letras e números.';
    case 'too-many-requests':
      return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
    case 'network-request-failed':
      return 'Sem conexão com a internet.';
    case 'requires-recent-login':
      return 'Por segurança, confirme sua senha novamente.';
    default:
      return 'Não foi possível concluir a autenticação.';
  }
}

String friendlyError(Object e) {
  if (e is AppException) return e.message;
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return 'Você não tem permissão para acessar estes dados.';
    if (e.code == 'unavailable') return 'Sem conexão com a internet.';
  }
  return 'Algo deu errado. Tente novamente.';
}

/// Converte exceções do Firebase em [AppException] amigáveis (sem expor detalhes internos).
/// Com [write], aplica timeout: offline o Firestore enfileira a escrita e a Future só conclui
/// ao reconectar; nesse caso sinalizamos [PendingSyncException].
Future<T> guard<T>(Future<T> Function() f, {bool write = false}) async {
  try {
    final fut = f();
    return write ? await fut.timeout(const Duration(seconds: 8)) : await fut;
  } on TimeoutException {
    throw const PendingSyncException();
  } on FirebaseAuthException catch (e) {
    throw AppException(authErrorMessage(e));
  } on FirebaseFunctionsException catch (e) {
    throw AppException(e.message ?? 'Não foi possível concluir a operação.');
  } on FirebaseException catch (e) {
    throw AppException(friendlyError(e));
  }
}
