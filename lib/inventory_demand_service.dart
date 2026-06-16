import 'dart:math';

/// Hasil dari [buildDailyDemand]: deret harian dan rentang observasi kalender.
class DailyDemandResult {
  const DailyDemandResult({
    required this.series,
    required this.observationSpanDays,
  });

  /// Deret permintaan harian sepanjang windowDays. Hari tanpa transaksi = 0.
  final List<int> series;

  /// Selisih hari antara transaksi paling awal dan hari ini, dibatasi windowDays.
  /// Nol jika tidak ada transaksi sama sekali dalam window.
  final int observationSpanDays;
}

/// Statistik permintaan harian yang digunakan untuk menghitung SS dan ROP.
class DemandStats {
  const DemandStats({
    required this.mean,
    required this.stdDev,
    required this.observationSpanDays,
    required this.isFallback,
  });

  final double mean;
  final double stdDev;
  final int observationSpanDays;

  /// true jika observationSpanDays < 14 — gunakan rumus fallback di [computeSafetyStock].
  final bool isFallback;
}

/// Membangun deret permintaan harian sepanjang [windowDays] dari baris transaksi mentah.
///
/// Setiap entri [rows] harus berisi:
///   - `'date'`: [DateTime]? (waktu lokal)
///   - `'qty'`:  [int]
///
/// Hari di luar window [today − windowDays + 1 .. today] diabaikan.
/// [DailyDemandResult.observationSpanDays] =
///   min(today − tanggal_transaksi_paling_awal + 1, windowDays), atau 0 jika kosong.
DailyDemandResult buildDailyDemand(
  List<Map<String, dynamic>> rows,
  int windowDays,
  DateTime today,
) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final startDate = todayDate.subtract(Duration(days: windowDays - 1));

  final Map<String, int> dailyQty = {};
  DateTime? earliestDate;

  for (final row in rows) {
    final dt = row['date'] as DateTime?;
    if (dt == null) continue;
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date.isBefore(startDate) || date.isAfter(todayDate)) continue;

    final key = _dateKey(date);
    dailyQty[key] = (dailyQty[key] ?? 0) + (row['qty'] as int? ?? 0);

    if (earliestDate == null || date.isBefore(earliestDate)) {
      earliestDate = date;
    }
  }

  final series = List<int>.generate(
    windowDays,
    (i) => dailyQty[_dateKey(startDate.add(Duration(days: i)))] ?? 0,
  );

  int observationSpanDays = 0;
  if (earliestDate != null) {
    final span = todayDate.difference(earliestDate).inDays + 1;
    observationSpanDays = span.clamp(0, windowDays);
  }

  return DailyDemandResult(series: series, observationSpanDays: observationSpanDays);
}

/// Menghitung mean dan sample std dev dari [result.series].
///
/// Mean = total / windowDays (hari kosong dihitung sebagai 0).
/// Std dev = sample (dibagi n−1). Aman karena series selalu sepanjang windowDays ≥ 2.
/// [isFallback] aktif jika [observationSpanDays] < 14.
DemandStats computeDemandStats(DailyDemandResult result) {
  final series = result.series;
  final n = series.length;

  final double mean = series.fold<double>(0, (s, x) => s + x) / n;

  double variance = 0;
  for (final x in series) {
    final diff = x - mean;
    variance += diff * diff;
  }
  final double stdDev = sqrt(variance / (n - 1));

  return DemandStats(
    mean: mean,
    stdDev: stdDev,
    observationSpanDays: result.observationSpanDays,
    isFallback: result.observationSpanDays < 14,
  );
}

/// Z-value per kelas ABC.
/// A = 2.33 (service level 99%), B = 1.65 (95%), C / null = 1.28 (90%).
double zValueForClass(String? abcClass) {
  switch (abcClass) {
    case 'A':
      return 2.33;
    case 'B':
      return 1.65;
    default:
      return 1.28;
  }
}

/// Safety Stock = Z × σ × √L (dibulatkan ke atas).
///
/// Fallback (observationSpanDays < 14): SS = ceil(d̄ × L).
/// Std dev tidak pernah diakses saat isFallback == true.
int computeSafetyStock(DemandStats stats, int leadTime, String? abcClass) {
  if (stats.isFallback) {
    return (stats.mean * leadTime).ceil();
  }
  return (zValueForClass(abcClass) * stats.stdDev * sqrt(leadTime.toDouble())).ceil();
}

/// Reorder Point = ceil(d̄ × L) + safetyStock.
int computeReorderPoint(DemandStats stats, int leadTime, int safetyStock) {
  return (stats.mean * leadTime).ceil() + safetyStock;
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
