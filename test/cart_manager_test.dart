import 'package:flutter_test/flutter_test.dart';
import 'package:sikulak/cart_manager.dart';

// Helper yang mereplikasi guard logic dari PosPage._addItemToCart()
// (pos_page.dart baris 546-565). Mengembalikan true jika item berhasil
// ditambahkan, false jika diblokir oleh salah satu guard.
bool tryAddToCart(
  CartManager cart,
  String productId, {
  required String name,
  required double price,
  required double capitalPrice,
  required int qtyAvailable,
}) {
  if (qtyAvailable <= 0) return false;
  if (cart.quantityOf(productId) >= qtyAvailable) return false;
  cart.add(productId, name: name, price: price, capitalPrice: capitalPrice);
  return true;
}

void main() {
  late CartManager cart;

  setUp(() {
    cart = CartManager();
    cart.clear(); // reset singleton antar test
  });

  // ──────────────────────────────────────────────────────────────────
  // Case 1: Tombol checkout terblok saat keranjang kosong
  // ──────────────────────────────────────────────────────────────────
  // Logika di PosPage._openCheckoutPage(): if (_cart.isEmpty) return;
  // Flag isEmpty dari CartManager menentukan apakah guard itu aktif.
  group('Case 1: checkout blocked when cart is empty', () {
    test('cart starts empty — guard would block checkout', () {
      // Diharapkan: kartmanager baru (setelah clear) selalu isEmpty = true,
      // sehingga _openCheckoutPage() akan return lebih awal tanpa navigasi.
      expect(cart.isEmpty, isTrue);
    });

    test('isEmpty = false setelah item ditambah — checkout tidak terblok', () {
      // Diharapkan: setelah satu item masuk, isEmpty = false.
      cart.add('id-1', name: 'Beras', price: 10000, capitalPrice: 8000);
      expect(cart.isEmpty, isFalse);
    });

    test('isEmpty = true kembali setelah clear — checkout terblok lagi', () {
      // Diharapkan: clear() mengembalikan keranjang ke kondisi kosong.
      cart.add('id-1', name: 'Beras', price: 10000, capitalPrice: 8000);
      cart.clear();
      expect(cart.isEmpty, isTrue);
    });

    test('isNotEmpty adalah kebalikan isEmpty', () {
      // Diharapkan: isNotEmpty dan isEmpty selalu berlawanan nilai.
      expect(cart.isNotEmpty, isFalse);
      cart.add('id-1', name: 'Beras', price: 10000, capitalPrice: 8000);
      expect(cart.isNotEmpty, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // Case 2: Qty satu item tidak bisa melebihi stok tersedia
  // ──────────────────────────────────────────────────────────────────
  // Guard di PosPage: if (currentQty >= item.qtyAvailable) return;
  group('Case 2: qty cannot exceed available stock', () {
    const id = 'item-susu';
    const stock = 3;

    test('penambahan sampai batas stok semuanya berhasil', () {
      // Diharapkan: menambah item sebanyak tepat stok (3x) harus berhasil
      // semua — tidak ada yang diblokir.
      for (int i = 0; i < stock; i++) {
        final added = tryAddToCart(cart, id,
            name: 'Susu', price: 5000, capitalPrice: 4000, qtyAvailable: stock);
        expect(added, isTrue,
            reason: 'Penambahan ke-${i + 1} seharusnya berhasil');
      }
      expect(cart.quantityOf(id), stock);
    });

    test('penambahan ke-4 diblokir saat stok hanya 3', () {
      // Diharapkan: setelah qty di keranjang = stok, penambahan berikutnya
      // diblokir dan qty tidak berubah.
      for (int i = 0; i < stock; i++) {
        tryAddToCart(cart, id,
            name: 'Susu', price: 5000, capitalPrice: 4000, qtyAvailable: stock);
      }
      final overAdd = tryAddToCart(cart, id,
          name: 'Susu', price: 5000, capitalPrice: 4000, qtyAvailable: stock);
      expect(overAdd, isFalse);
      expect(cart.quantityOf(id), stock); // qty tidak berubah
    });

    test('remove menurunkan qty, lalu satu penambahan diizinkan lagi', () {
      // Diharapkan: setelah remove 1 unit dari qty=3 (=stok), qty menjadi 2,
      // sehingga penambahan berikutnya diizinkan kembali.
      for (int i = 0; i < stock; i++) {
        tryAddToCart(cart, id,
            name: 'Susu', price: 5000, capitalPrice: 4000, qtyAvailable: stock);
      }
      cart.remove(id); // qty 3 → 2
      final reAdd = tryAddToCart(cart, id,
          name: 'Susu', price: 5000, capitalPrice: 4000, qtyAvailable: stock);
      expect(reAdd, isTrue);
      expect(cart.quantityOf(id), stock); // kembali ke 3
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // Case 3: Barang dengan stok habis tidak bisa ditambahkan ke keranjang
  // ──────────────────────────────────────────────────────────────────
  // Guard di PosPage: if (item.qtyAvailable <= 0) return;
  group('Case 3: out-of-stock item cannot be added', () {
    test('item dengan stok 0 tidak masuk keranjang', () {
      // Diharapkan: qtyAvailable=0 menyebabkan guard memblokir; keranjang
      // tetap kosong setelah percobaan.
      final added = tryAddToCart(cart, 'item-tepung',
          name: 'Tepung', price: 8000, capitalPrice: 6000, qtyAvailable: 0);
      expect(added, isFalse);
      expect(cart.isEmpty, isTrue);
    });

    test('item dengan stok negatif juga diblokir (edge case)', () {
      // Diharapkan: stok negatif diperlakukan sama dengan habis.
      // Guard memakai <= 0 sehingga nilai negatif ikut terblokir.
      final added = tryAddToCart(cart, 'item-gula',
          name: 'Gula', price: 12000, capitalPrice: 10000, qtyAvailable: -1);
      expect(added, isFalse);
      expect(cart.isEmpty, isTrue);
    });

    test('item dengan stok 1 bisa ditambah sekali, lalu diblokir', () {
      // Diharapkan: stok=1 → penambahan pertama berhasil, penambahan kedua
      // diblokir oleh guard Case 2 (qty >= stok).
      final first = tryAddToCart(cart, 'item-minyak',
          name: 'Minyak', price: 15000, capitalPrice: 12000, qtyAvailable: 1);
      expect(first, isTrue);
      final second = tryAddToCart(cart, 'item-minyak',
          name: 'Minyak', price: 15000, capitalPrice: 12000, qtyAvailable: 1);
      expect(second, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // Case 4: Total harga di tombol checkout menyesuaikan saat qty diubah
  // ──────────────────────────────────────────────────────────────────
  // Logika di CartManager.totalPrice: fold price * quantity.
  // formattedTotalPrice dipakai langsung di UI tombol checkout.
  group('Case 4: total price updates correctly when qty changes', () {
    test('keranjang kosong → total 0.0', () {
      // Diharapkan: tidak ada item = total nol.
      expect(cart.totalPrice, 0.0);
    });

    test('satu jenis item: total = harga × qty', () {
      // Diharapkan: Kopi Rp10.000 × 3 unit = Rp30.000.
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      expect(cart.totalPrice, 30000.0);
    });

    test('total turun saat remove dipanggil', () {
      // Diharapkan: setelah remove 1 unit dari 3, total turun 1× harga.
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.remove('item-kopi');
      expect(cart.totalPrice, 20000.0);
    });

    test('beberapa jenis item: total = jumlah (harga × qty) tiap jenis', () {
      // Diharapkan: Kopi 2×Rp10.000 + Teh 3×Rp5.000 = Rp35.000.
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.add('item-teh', name: 'Teh', price: 5000, capitalPrice: 3000);
      cart.add('item-teh', name: 'Teh', price: 5000, capitalPrice: 3000);
      cart.add('item-teh', name: 'Teh', price: 5000, capitalPrice: 3000);
      expect(cart.totalPrice, 35000.0);
    });

    test('total di-reset ke 0 setelah clear', () {
      // Diharapkan: clear() menghapus semua item dan total kembali ke nol.
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.add('item-kopi', name: 'Kopi', price: 10000, capitalPrice: 7000);
      cart.clear();
      expect(cart.totalPrice, 0.0);
    });

    test('formattedTotalPrice menampilkan format Rupiah yang benar', () {
      // Diharapkan: Rp120.000 diformat menjadi "Rp. 120.000"
      // sesuai CartManager.formatPrice yang dipakai tombol checkout.
      cart.add('item-kopi', name: 'Kopi', price: 120000, capitalPrice: 90000);
      expect(cart.formattedTotalPrice, 'Rp. 120.000');
    });

    test('formatPrice untuk angka besar: 1.500.000', () {
      // Diharapkan: pemisah ribuan titik terpasang benar di semua kelompok.
      expect(CartManager.formatPrice(1500000), 'Rp. 1.500.000');
    });
  });
}
