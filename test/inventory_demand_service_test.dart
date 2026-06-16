import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikulak/inventory_demand_service.dart';

void main() {
  // Tanggal tetap agar semua test reproducible.
  // startDate = 2025-03-19 (today − 89 hari).
  final today = DateTime(2025, 6, 16);
  const windowDays = 90;

  Map<String, dynamic> row(DateTime date, int qty) =>
      {'date': date, 'qty': qty};

  // ──────────────────────────────────────────────────────────────────────────
  // Case 1 – rows kosong
  // ──────────────────────────────────────────────────────────────────────────
  group('Case 1: rows kosong', () {
    test('observationSpanDays=0, isFallback=true, SS=0, ROP=0', () {
      // Tidak ada transaksi → earliestDate null → observationSpanDays = 0.
      // isFallback = (0 < 14) = true.
      // mean = 0/90 = 0.0 → SS_fallback = ceil(0 × L) = 0, ROP = 0 + 0 = 0.
      const leadTime = 5;

      final result = buildDailyDemand([], windowDays, today);

      expect(result.observationSpanDays, 0);
      expect(result.series.length, windowDays);
      expect(result.series.every((v) => v == 0), isTrue);

      final stats = computeDemandStats(result);

      expect(stats.isFallback, isTrue);
      expect(stats.mean, 0.0);

      final ss = computeSafetyStock(stats, leadTime, 'A');
      final rop = computeReorderPoint(stats, leadTime, ss);

      expect(ss, 0);
      expect(rop, 0);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Case 2 – 10 hari kalender berisi penjualan → isFallback true
  // ──────────────────────────────────────────────────────────────────────────
  group('Case 2: 10 hari kalender → fallback', () {
    test('SS pakai ceil(mean × L), bukan jalur z × σ × √L', () {
      // Transaksi today−9 s/d today (10 hari), masing-masing 5 unit.
      // observationSpanDays = (today − (today−9)).inDays + 1 = 10.
      // isFallback = (10 < 14) = true.
      // total = 50, mean = 50/90 = 5/9 ≈ 0.5556.
      // SS_fallback = ceil(5/9 × 3) = ceil(5/3) = ceil(1.6̄) = 2.
      // ROP = ceil(5/9 × 3) + 2 = 2 + 2 = 4.
      const leadTime = 3;

      final rows = List.generate(
        10,
        (i) => row(today.subtract(Duration(days: i)), 5),
      );

      final result = buildDailyDemand(rows, windowDays, today);
      expect(result.observationSpanDays, 10);

      final stats = computeDemandStats(result);
      expect(stats.isFallback, isTrue);

      final ss = computeSafetyStock(stats, leadTime, 'A');
      expect(ss, 2); // ceil(5/9 × 3) = ceil(1.6̄) = 2

      final rop = computeReorderPoint(stats, leadTime, ss);
      expect(rop, 4); // 2 + 2 = 4
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Case 3 – demand stabil: 5 unit/hari selama 90 hari
  // ──────────────────────────────────────────────────────────────────────────
  group('Case 3: demand stabil (5 unit/hari × 90 hari)', () {
    test('stdDev=0, SS=0, ROP didominasi mean × L', () {
      // Semua 90 hari bernilai 5.
      // mean = 5.0, variance = Σ(5−5)²/89 = 0, stdDev = 0.0.
      // observationSpanDays = 90 → NOT fallback.
      // SS = ceil(2.33 × 0 × √7) = 0.
      // ROP = ceil(5.0 × 7) + 0 = 35.
      const leadTime = 7;

      final rows = List.generate(
        windowDays,
        (i) => row(today.subtract(Duration(days: i)), 5),
      );

      final result = buildDailyDemand(rows, windowDays, today);
      final stats = computeDemandStats(result);

      expect(stats.isFallback, isFalse);
      expect(stats.mean, closeTo(5.0, 1e-10));
      expect(stats.stdDev, closeTo(0.0, 1e-10));

      final ss = computeSafetyStock(stats, leadTime, 'A');
      expect(ss, 0);

      final rop = computeReorderPoint(stats, leadTime, ss);
      expect(rop, 35); // ceil(5.0 × 7) + 0 = 35
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Case 4 – demand volatil: alternating 0/10, mean=5 sama dengan case 3
  // ──────────────────────────────────────────────────────────────────────────
  group('Case 4: demand volatil (0/10 bergantian, mean=5)', () {
    test('stdDev besar → SS jauh lebih besar dari case 3', () {
      // i genap → qty 10 (45 hari), i ganjil → qty 0 (45 hari).
      // mean = (45×10 + 45×0)/90 = 5.0.
      // variance = (45×(10−5)² + 45×(0−5)²)/89 = 2250/89 ≈ 25.281.
      // stdDev = √(2250/89) ≈ 5.0280.
      // SS (class A, L=7) = ceil(2.33 × 5.0280 × √7)
      //   = ceil(2.33 × 5.0280 × 2.6458)
      //   = ceil(30.996…) = 31.
      // Case 3 SS = 0; 31 > 0 ✓
      const leadTime = 7;

      final rows = List.generate(
        windowDays,
        (i) => row(today.subtract(Duration(days: i)), i.isEven ? 10 : 0),
      );

      final result = buildDailyDemand(rows, windowDays, today);
      final stats = computeDemandStats(result);

      expect(stats.isFallback, isFalse);
      expect(stats.mean, closeTo(5.0, 1e-10));

      // stdDev = √(2250/89)
      expect(stats.stdDev, closeTo(sqrt(2250 / 89), 1e-9));

      final ss = computeSafetyStock(stats, leadTime, 'A');
      expect(ss, 31);
      expect(ss, greaterThan(0)); // case 3 adalah 0
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Case 5 – deret identik, kelas A vs C
  // ──────────────────────────────────────────────────────────────────────────
  group('Case 5: kelas A (z=2.33) vs kelas C (z=1.28)', () {
    test('SS_A > SS_C pada data yang sama', () {
      // Pakai data sama dengan case 4 (alternating 0/10, 90 hari).
      // stdDev = √(2250/89) ≈ 5.0280, L=7.
      // SS_A = ceil(2.33 × 5.0280 × √7) = ceil(30.996…) = 31.
      // SS_C = ceil(1.28 × 5.0280 × √7) = ceil(17.028…) = 18.
      // 31 > 18 ✓
      const leadTime = 7;

      final rows = List.generate(
        windowDays,
        (i) => row(today.subtract(Duration(days: i)), i.isEven ? 10 : 0),
      );

      final result = buildDailyDemand(rows, windowDays, today);
      final stats = computeDemandStats(result);

      final ssA = computeSafetyStock(stats, leadTime, 'A');
      final ssC = computeSafetyStock(stats, leadTime, 'C');

      expect(ssA, 31);
      expect(ssC, 18);
      expect(ssA, greaterThan(ssC));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Case 6 – transaksi hanya 5 hari dari 90; mean dihitung dari deret penuh
  // ──────────────────────────────────────────────────────────────────────────
  group('Case 6: transaksi 5 hari saja → mean berbasis 90 hari', () {
    test('mean = 50/90, bukan 50/5', () {
      // today−19 s/d today−15: 5 hari berturut-turut, masing-masing 10 unit.
      // Total = 50 unit; 85 hari sisanya = 0.
      // observationSpanDays = (today − (today−19)).inDays + 1 = 20 → NOT fallback.
      // mean = 50/90 = 5/9 ≈ 0.5556 (BUKAN 50/5 = 10).
      // variance = (85×(5/9)² + 5×(85/9)²)/89 = 38250/7209.
      // stdDev = √(38250/7209) ≈ 2.3034.
      // SS (class C, L=3) = ceil(1.28 × 2.3034 × √3)
      //   = ceil(1.28 × 2.3034 × 1.7321)
      //   = ceil(5.107…) = 6.
      // ROP = ceil(5/9 × 3) + 6 = ceil(1.6̄) + 6 = 2 + 6 = 8.
      const leadTime = 3;

      final rows = List.generate(
        5,
        (i) => row(today.subtract(Duration(days: 15 + i)), 10),
      );

      final result = buildDailyDemand(rows, windowDays, today);
      expect(result.observationSpanDays, 20);

      final stats = computeDemandStats(result);
      expect(stats.isFallback, isFalse);

      // Kunci: mean harus 50/90, BUKAN rata-rata 5 hari aktif (= 10)
      expect(stats.mean, closeTo(50 / 90, 1e-10));
      expect(stats.mean, isNot(closeTo(10.0, 0.5)));

      // stdDev = √(38250/7209)
      expect(stats.stdDev, closeTo(sqrt(38250 / 7209), 1e-9));

      final ss = computeSafetyStock(stats, leadTime, 'C');
      expect(ss, 6);

      final rop = computeReorderPoint(stats, leadTime, ss);
      expect(rop, 8);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Case 7 – edge: semua nilai identik, variance nol
  // ──────────────────────────────────────────────────────────────────────────
  group('Case 7: semua nilai sama persis (variance nol)', () {
    test('stdDev = 0.0 (bukan NaN), tidak crash', () {
      // 90 hari masing-masing 3 unit.
      // mean = 3.0, variance = Σ(3−3)²/89 = 0/89 = 0.0.
      // stdDev = √0.0 = 0.0 — bukan NaN.
      // isFallback = false (observationSpanDays = 90).
      // SS (class B, L=5) = ceil(1.65 × 0 × √5) = 0.
      // ROP = ceil(3.0 × 5) + 0 = 15.
      const leadTime = 5;

      final rows = List.generate(
        windowDays,
        (i) => row(today.subtract(Duration(days: i)), 3),
      );

      final result = buildDailyDemand(rows, windowDays, today);
      final stats = computeDemandStats(result);

      expect(stats.isFallback, isFalse);
      expect(stats.mean, closeTo(3.0, 1e-10));
      expect(stats.stdDev.isNaN, isFalse,
          reason: 'stdDev tidak boleh NaN meski variance = 0');
      expect(stats.stdDev, closeTo(0.0, 1e-10));

      final ss = computeSafetyStock(stats, leadTime, 'B');
      expect(ss, 0);

      final rop = computeReorderPoint(stats, leadTime, ss);
      expect(rop, 15); // ceil(3.0 × 5) + 0 = 15
    });
  });
}
