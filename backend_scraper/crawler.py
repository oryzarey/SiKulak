import os
import requests
import fitz  
from PIL import Image, ImageChops, ImageEnhance
import pytesseract
from datetime import datetime, timedelta
import urllib3
import numpy as np
from skimage.filters import threshold_otsu
from supabase import create_client, Client
from dotenv import load_dotenv

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- KONFIGURASI ENV & SUPABASE ---
load_dotenv()
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

if os.name == 'nt':
    pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

TARGET_BARANG = {
    "beras premium": {"name": "Beras Premium", "unit": "Kg"},
    "beras medium": {"name": "Beras Medium", "unit": "Kg"},
    "gula pasir": {"name": "Gula Pasir", "unit": "Kg"},
    "gula jawa": {"name": "Gula Jawa/Merah", "unit": "Kg"},
    "gula merah": {"name": "Gula Jawa/Merah", "unit": "Kg"},
    "minyak goreng curah": {"name": "Minyak Goreng Curah", "unit": "Kg"},
    "minyak kita": {"name": "Minyakita", "unit": "Liter"},
    "telur ayam broiler": {"name": "Telur Ayam Broiler", "unit": "Kg"},
    "telur ayam kampung": {"name": "Telur Ayam Kampung", "unit": "Butir"},
    "indomilk": {"name": "Susu Kental Manis Indomilk", "unit": "Kaleng"},
    "bendera": {"name": "Susu Kental Manis Bendera", "unit": "Kaleng"},
    "rinso": {"name": "Sabun Deterjen Rinso", "unit": "Bungkus"},
    "wings": {"name": "Sabun Colek Wings", "unit": "Bungkus"},
    "terigu curah": {"name": "Tepung Terigu Curah", "unit": "Kg"},
    "terigu kemasan": {"name": "Tepung Terigu Kemasan", "unit": "Kg"},
    "indomie goreng": {"name": "Indomie Goreng", "unit": "Bungkus"}
}

DAFTAR_PASAR = [
    "Tambahrejo", "Pucang Anom", "Wonokromo",
    "Genteng", "Kembang", "Pabean", "Balongsari"
]

def generate_pdf_url(tanggal):
    bulan_indo = {
        1: "Januari", 2: "Februari", 3: "Maret", 4: "April", 5: "Mei", 6: "Juni",
        7: "Juli", 8: "Agustus", 9: "September", 10: "Oktober", 11: "November", 12: "Desember"
    }
    return f"https://pasarsurya.surabaya.go.id/wp-content/uploads/{tanggal.strftime('%Y')}/{tanggal.strftime('%m')}/{tanggal.strftime('%d')}-{bulan_indo[tanggal.month]}-{tanggal.strftime('%Y')}.pdf"

def binarize_and_enhance(image):
    if image.mode != 'L':
        image = image.convert('L')
    img_array = np.array(image)
    try:
        thresh = threshold_otsu(img_array)
        binary = img_array > thresh
        binary_img = Image.fromarray((binary * 255).astype(np.uint8)).convert('1')
    except Exception:
        binary_img = image.point(lambda p: 255 if p > 128 else 0, mode='1')
    
    binary_gray = binary_img.convert('L')
    enhancer = ImageEnhance.Contrast(binary_gray)
    return enhancer.enhance(2.0)

def main_crawler():
    tanggal_target = datetime.now()
    pdf_path = "temp_harga.pdf"
    berhasil_download = False
    
    print("Mencari file PDF harga terbaru...")
    for i in range(7):
        url = generate_pdf_url(tanggal_target)
        try:
            response = requests.get(url, verify=False, timeout=10)
            if response.status_code == 200 and b"%PDF" in response.content[:5]:
                with open(pdf_path, "wb") as f:
                    f.write(response.content)
                berhasil_download = True
                print(f"✅ PDF ditemukan ({tanggal_target.strftime('%d %b %Y')})")
                break
            tanggal_target -= timedelta(days=1)
        except Exception:
            tanggal_target -= timedelta(days=1)
            
    if not berhasil_download:
        print("Gagal menemukan PDF terbaru.")
        return

    # --- RENDER & OCR ---
    doc = fitz.open(pdf_path)
    halaman_pertama = doc.load_page(0)
    rect = halaman_pertama.rect
    clip_area = fitz.Rect(rect.x0, rect.y0, rect.width / 2, rect.height / 2) 
    zoom_matrix = fitz.Matrix(1100 / 72, 1100 / 72)
    pix = halaman_pertama.get_pixmap(matrix=zoom_matrix, clip=clip_area)
    doc.close()
    
    gambar_hi_res = "debug_hi_res.png"
    pix.save(gambar_hi_res)

    gambar = Image.open(gambar_hi_res)
    gambar_gray = gambar.convert('L')
    kotak_tabel = ImageChops.invert(gambar_gray).getbbox()
    
    if kotak_tabel:
        margin = 50
        x1, y1 = max(0, kotak_tabel[0] - margin), max(0, kotak_tabel[1] - margin)
        x2, y2 = min(gambar.width, kotak_tabel[2] + margin), min(gambar.height, kotak_tabel[3] + margin)
        gambar_dicrop = gambar.crop((x1, y1, x2, y2))
    else:
        gambar_dicrop = gambar

    gambar_final = binarize_and_enhance(gambar_dicrop)
    teks_pdf = pytesseract.image_to_string(gambar_final, config='--psm 6')

    if not teks_pdf.strip():
        print("❌ OCR kosong.")
        return

    # --- PENGUMPULAN DATA ---
    data_hasil = []
    
    for baris in teks_pdf.split('\n'):
        baris_lower = baris.lower()
        for kunci, properti in TARGET_BARANG.items():
            if kunci in baris_lower:
                potongan_kata = baris.split()
                data_harga = []
                for idx, kata in enumerate(potongan_kata):
                    kata_bersih = kata.replace('.', '').replace(',', '')
                    if kata in ['-', '–', '—'] and idx > 2:
                        data_harga.append(None)
                    elif kata_bersih.isdigit() and len(kata_bersih) > 2:
                        data_harga.append(int(kata_bersih))
                
                if data_harga:
                    for i in range(min(len(DAFTAR_PASAR), len(data_harga))):
                        if data_harga[i] is not None:
                            data_hasil.append({
                                "product_name": properti["name"],
                                "unit": properti["unit"],
                                "supplier_name": DAFTAR_PASAR[i],
                                "price": data_harga[i]
                            })
                break 

    # --- INTEGRASI SUPABASE MANY-TO-MANY ---
    if data_hasil:
        print(f"\nMenyiapkan {len(data_hasil)} data untuk Database...")

        # 1. Pastikan semua supplier (pasar) terdaftar
        list_supplier = [{"name": p} for p in DAFTAR_PASAR]
        supabase.table("suppliers").upsert(list_supplier, on_conflict="name").execute()
        
        # 2. Pastikan semua produk terdaftar
        list_product = []
        nama_produk_unik = set()
        for d in data_hasil:
            if d["product_name"] not in nama_produk_unik:
                list_product.append({"name": d["product_name"], "unit": d["unit"]})
                nama_produk_unik.add(d["product_name"])
        supabase.table("products").upsert(list_product, on_conflict="name").execute()

        # 3. Tarik ID dari database untuk disandingkan
        sup_db = supabase.table("suppliers").select("id, name").execute()
        prod_db = supabase.table("products").select("id, name").execute()
        
        map_supplier = {row["name"]: row["id"] for row in sup_db.data}
        map_product = {row["name"]: row["id"] for row in prod_db.data}

        payload_relasi = []
        for d in data_hasil:
            payload_relasi.append({
                "product_id": map_product[d["product_name"]],
                "supplier_id": map_supplier[d["supplier_name"]],
                "price": d["price"],
                "last_updated": tanggal_target.strftime("%Y-%m-%d")
            })

        response = supabase.table("supplier_products").upsert(
            payload_relasi, on_conflict="product_id, supplier_id"
        ).execute()
        
        print("✅ Berhasil menyimpan/mengupdate data relasi ke Supabase!")

if __name__ == "__main__":
    main_crawler()