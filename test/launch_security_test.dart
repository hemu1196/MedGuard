import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/core/api/api_client.dart';
import 'package:med_ai/services/private_local_store.dart';
import 'package:med_ai/services/offline_emergency_store.dart';
import 'package:med_ai/services/medicine_action_outbox.dart';

void main() {
  test(
    'medicine outbox isolates accounts and retains only the first action per dose',
    () async {
      final action = <String, dynamic>{
        'medicineId': 'test',
        'scheduledDate': '2026-11-17',
        'scheduledTime': '08:00',
        'status': 'taken',
      };
      await Future.wait(
        List.generate(
          6,
          (_) => MedicineActionOutbox.enqueue('account-a', action),
        ),
      );
      expect(await MedicineActionOutbox.pendingCount('account-a'), 1);
      expect(await MedicineActionOutbox.pendingCount('account-b'), 0);
      await MedicineActionOutbox.enqueue('account-a', {
        ...action,
        'status': 'skipped',
      });
      expect(await MedicineActionOutbox.pendingCount('account-a'), 1);
      await PrivateLocalStore.clear();
      expect(await MedicineActionOutbox.pendingCount('account-a'), 0);
    },
  );
  test(
    'legacy session migrates to protected storage and logout purges snapshots',
    () async {
      SharedPreferences.setMockInitialValues({
        'medguard_auth_token': 'legacy-token',
        'medguard_user_data': '{"_id":"account-a","fullName":"Test account"}',
      });
      final api = ApiClient();
      expect((await api.getStoredUser())?['_id'], 'account-a');
      expect(
        (await SharedPreferences.getInstance()).getString('medguard_user_data'),
        isNull,
      );
      await PrivateLocalStore.write(
        OfflineEmergencyStore.key('account-a'),
        '{"userId":"account-a","userName":"Private"}',
      );
      expect(await OfflineEmergencyStore.read('account-b'), isNull);
      expect(
        (await OfflineEmergencyStore.read('account-a'))?['userName'],
        'Private',
      );
      await api.clearAuthSession();
      expect(await OfflineEmergencyStore.read('account-a'), isNull);
      expect(await PrivateLocalStore.read('medguard_user_data'), isNull);
    },
  );
}
