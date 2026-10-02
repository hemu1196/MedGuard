class HospitalQueueInfo {
  final String hospitalId;
  final int estimatedWaitMinutes;
  final String queueStatus; // Low, Moderate, High Wait
  final bool isEmergencyOpen;
  final bool isSimulatedData;

  HospitalQueueInfo({
    required this.hospitalId,
    required this.estimatedWaitMinutes,
    required this.queueStatus,
    required this.isEmergencyOpen,
    this.isSimulatedData = true,
  });
}

class HospitalQueueService {
  Future<HospitalQueueInfo> getQueuePrediction(String hospitalId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    int waitMins = 15;
    if (hospitalId.endsWith('2')) waitMins = 35;
    if (hospitalId.endsWith('3')) waitMins = 50;

    String status = 'Low Wait';
    if (waitMins > 20) status = 'Moderate Wait';
    if (waitMins > 40) status = 'High Wait';

    return HospitalQueueInfo(
      hospitalId: hospitalId,
      estimatedWaitMinutes: waitMins,
      queueStatus: status,
      isEmergencyOpen: true,
    );
  }
}
