import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AuthStore {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  final ValueNotifier<String?> token = ValueNotifier<String?>(null);

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/auth.json');
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        token.value = j['token'] as String?;
      }
    } catch (_) {}
  }

  Future<void> setToken(String? newToken) async {
    token.value = newToken;
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'token': newToken}));
    } catch (_) {}
  }
}


