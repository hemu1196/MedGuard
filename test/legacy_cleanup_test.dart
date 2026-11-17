import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/core/database/database_helper.dart';
import 'package:med_ai/services/private_local_store.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'legacy cleanup verifies encrypted backup before deleting a synthetic database',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp(
        'medguard-cache-test',
      );
      final oldPath = await getDatabasesPath();
      // ignore: deprecated_member_use
      await databaseFactory.setDatabasesPath(directory.path);
      addTearDown(() async {
        // ignore: deprecated_member_use
        await databaseFactory.setDatabasesPath(oldPath);
        await directory.delete(recursive: true);
      });
      final filename = path.join(directory.path, 'medguard_local.db');
      final db = await openDatabase(
        filename,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE fixture (value TEXT)');
          await db.insert('fixture', {'value': 'synthetic private record'});
        },
      );
      await db.close();
      await expectLater(
        DatabaseHelper.instance.cleanupVerifiedLegacyCaches(confirmed: false),
        throwsStateError,
      );
      expect(await databaseExists(filename), isTrue);
      expect(
        await DatabaseHelper.instance.cleanupVerifiedLegacyCaches(
          confirmed: true,
        ),
        1,
      );
      expect(await databaseExists(filename), isFalse);
      final envelope = jsonDecode(
        await File('$filename.encrypted-backup').readAsString(),
      );
      final key = await PrivateLocalStore.read(
        'legacy_backup_key_medguard_local.db',
      );
      final bytes = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(envelope['cipher']),
          nonce: base64Decode(envelope['nonce']),
          mac: Mac(base64Decode(envelope['mac'])),
        ),
        secretKey: SecretKey(base64Decode(key!)),
      );
      final restored = path.join(directory.path, 'restored.db');
      await File(restored).writeAsBytes(bytes);
      final restoredDb = await openDatabase(restored);
      expect(
        (await restoredDb.query('fixture')).single['value'],
        'synthetic private record',
      );
      await restoredDb.close();
      expect(
        await DatabaseHelper.instance.cleanupVerifiedLegacyCaches(
          confirmed: true,
        ),
        0,
      );
    },
  );
}
