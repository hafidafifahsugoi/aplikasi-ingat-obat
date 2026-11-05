import 'dart:math';

class AIAssistant {
  String generateReminderMessage({
    required String medicineName,
    required String dosage,
    required String scheduledTime,
  }) {
    final greetings = [
      '⏰ Halo! Waktunya minum obat nih',
      '💊 Hai! Jangan lupa minum obat ya',
      '⏰ Pengingat ramah: Saatnya minum obat',
      '💊 Halo! Sudah waktunya minum obat',
    ];

    final greeting = greetings[Random().nextInt(greetings.length)];

    return '$greeting\n\n'
        '📋 Obat: $medicineName\n'
        '💊 Dosis: $dosage\n'
        '⏰ Jadwal: $scheduledTime\n\n'
        'Sudah minum obatnya belum? 😊';
  }

  String generateMotivationMessage(String medicineName) {
    final messages = [
      '💙 Ayo semangat! Minum obat $medicineName dulu ya. '
          'Kesehatan kamu penting banget! Jangan lupa minum air putih juga 💧',

      '🌟 Ingat, setiap obat yang kamu minum adalah langkah kecil menuju kesehatan yang lebih baik. '
          'Yuk minum $medicineName sekarang! 💪',

      '💚 Aku tahu kadang lupa itu wajar kok. Tapi sekarang sudah diingatkan, '
          'yuk minum $medicineName-nya. Kamu pasti bisa! ✨',

      '🌈 Tubuhmu butuh $medicineName untuk tetap sehat. '
          'Ayo minum sekarang, terus jaga pola hidup sehat ya! 😊',

      '💫 Konsisten minum obat = investasi kesehatan terbaik! '
          'Yuk minum $medicineName-nya, jangan sampai terlewat 🎯',
    ];

    return messages[Random().nextInt(messages.length)];
  }

  String generatePraiseMessage(String medicineName) {
    final messages = [
      '🎉 Keren! Kamu sudah minum $medicineName tepat waktu. '
          'Pertahankan kebiasaan baiknya ya! Semangat terus! 💪✨',

      '⭐ Hebat sekali! Konsisten minum obat itu penting banget. '
          'Kamu sudah melakukannya dengan baik. Proud of you! 💙',

      '🌟 Mantap! $medicineName sudah diminum. '
          'Terus jaga kesehatan dengan istirahat cukup dan minum air putih ya! 💧😊',

      '💚 Good job! Kamu sudah minum $medicineName hari ini. '
          'Langkah kecil yang konsisten akan membawa perubahan besar! 🎯',

      '✨ Luar biasa! Disiplin minum obat seperti ini yang bikin kamu makin sehat. '
          'Keep it up! 🌈💪',

      '🎊 Yes! Kamu berhasil! Minum $medicineName tepat waktu itu achievement lho. '
          'Bangga sama kamu! 💙✨',
    ];

    return messages[Random().nextInt(messages.length)];
  }

  String generateGentleReminderMessage(String medicineName) {
    final messages = [
      '💭 Halo, cuma mau ngingetin lagi nih... '
          'Jangan lupa minum $medicineName ya. Take your time! 😊',

      '🔔 Pengingat lembut: $medicineName masih menunggu diminum. '
          'Semoga kamu baik-baik saja ya! 💙',

      '💌 Hai! Aku di sini untuk mengingatkan kamu tentang $medicineName. '
          'Kapan-kapan kalau sempat, diminum ya! 😊',
    ];

    return messages[Random().nextInt(messages.length)];
  }

  String generateHealthTip() {
    final tips = [
      '💡 Tips sehat: Minum air putih minimal 8 gelas sehari ya!',
      '💡 Tips sehat: Istirahat cukup 7-8 jam sehari penting untuk pemulihan tubuh!',
      '💡 Tips sehat: Jangan lupa olahraga ringan minimal 30 menit sehari!',
      '💡 Tips sehat: Makan makanan bergizi seimbang untuk dukung pengobatan!',
      '💡 Tips sehat: Kelola stress dengan baik, kesehatan mental juga penting!',
    ];

    return tips[Random().nextInt(tips.length)];
  }
}
