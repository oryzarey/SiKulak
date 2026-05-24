import 'package:flutter/material.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';

class EditItemPage extends StatefulWidget {
  final Product product; // We pass the selected product representation
  final VoidCallback onSaved;

  const EditItemPage({
    super.key,
    required this.product,
    required this.onSaved,
  });

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _weightController;
  late TextEditingController _expDateController;
  
  int _quantity = 1;
  double _totalValue = 0.0;
  String? _imageUrl;
  bool _isSaving = false;
  
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(0));
    _quantity = widget.product.stock > 0 ? widget.product.stock : 1;
    _imageUrl = widget.product.imageUrl;
    
    // We will attempt to fetch the actual inventory record to load weight and exp_date if they exist
    _loadInventoryDetails();
    _recalculateTotalValue();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    _expDateController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryDetails() async {
    // Set default controllers first in case fetch fails
    _weightController = TextEditingController(text: '100');
    _expDateController = TextEditingController(text: '03/04/2026');

    try {
      final response = await supabase
          .from('inventories')
          .select()
          .eq('id', widget.product.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _quantity = (response['qty_available'] as num?)?.toInt() ?? _quantity;
          _priceController.text = ((response['selling_price'] as num?)?.toDouble() ?? widget.product.price).toStringAsFixed(0);
          _nameController.text = (response['name'] ?? widget.product.name) as String;
          _imageUrl = response['image_url'] as String? ?? widget.product.imageUrl;
          
          if (response['weight_gr'] != null) {
            _weightController.text = (response['weight_gr'] as num).toInt().toString();
          }
          
          if (response['exp_date'] != null) {
            final parsedDate = DateTime.tryParse(response['exp_date'].toString());
            if (parsedDate != null) {
              _selectedDate = parsedDate;
              _expDateController.text = _formatDate(parsedDate);
            }
          }
          
          _recalculateTotalValue();
        });
      }
    } catch (e) {
      debugPrint('[SiKulak] Error loading detailed inventory data: $e');
    }
  }

  void _recalculateTotalValue() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      _totalValue = _quantity * price;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2979FF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _expDateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? widget.product.price;
    final weight = int.tryParse(_weightController.text) ?? 100;
    
    String? expDateIso;
    if (_selectedDate != null) {
      expDateIso = _selectedDate!.toIso8601String();
    } else {
      // Try to parse the current text if it matches dd/MM/yyyy
      try {
        final parts = _expDateController.text.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          expDateIso = DateTime(year, month, day).toIso8601String();
        }
      } catch (_) {}
    }

    try {
      // 1. Try updating all columns including weight_gr and image_url
      await supabase.from('inventories').update({
        'name': name,
        'qty_available': _quantity,
        'selling_price': price,
        'weight_gr': weight,
        'image_url': _imageUrl,
        'exp_date': expDateIso,
      }).eq('id', widget.product.id);
      
      _onSaveSuccess();
    } catch (e) {
      debugPrint('[SiKulak] Full inventories update failed, retrying with standard columns... error: $e');
      
      // 2. Fallback: Update only standard columns if new columns do not exist in DB yet
      try {
        await supabase.from('inventories').update({
          'name': name,
          'qty_available': _quantity,
          'selling_price': price,
          'exp_date': expDateIso,
        }).eq('id', widget.product.id);
        
        _onSaveSuccess();
      } catch (err) {
        debugPrint('[SiKulak] Fallback update failed: $err');
        _onSaveFailure(err.toString());
      }
    }
  }

  void _onSaveSuccess() {
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Barang berhasil diperbarui!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade900.withValues(alpha: 0.8),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.only(bottom: 50, left: 40, right: 40),
        duration: const Duration(seconds: 2),
      ),
    );
    widget.onSaved();
    Navigator.pop(context);
  }

  void _onSaveFailure(String error) {
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Gagal memperbarui barang: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        backgroundColor: Colors.red.shade900.withValues(alpha: 0.8),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.only(bottom: 50, left: 40, right: 40),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─────────── EDIT ITEM APP BAR (Gambar 2) ───────────
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            toolbarHeight: 90,
            automaticallyImplyLeading: false,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2979FF), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Edit Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─────────── FORM CONTAINER CARD (Gambar 2) ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text(
                        'Item Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mohon masukan detail produk',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── PHOTO UPLOAD SECTION (Gambar 2) ──
                      const Text(
                        'Photo',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          // Allow mock input of image url for demonstration
                          _showMockImageInputDialog();
                        },
                        child: Container(
                          height: 110,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF3B82F6),
                              width: 1.5,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _imageUrl != null && _imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(_imageUrl!, fit: BoxFit.cover),
                                      Container(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        child: const Center(
                                          child: Icon(Icons.edit, color: Colors.white, size: 28),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle, color: Color(0xFF2979FF), size: 28),
                                    SizedBox(height: 8),
                                    Text(
                                      'Tambahkan Foto',
                                      style: TextStyle(
                                        color: Color(0xFF2979FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ukuran max. 10 MB',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500),
                      ),
                      const Divider(height: 36),

                      // ── ITEM INFO SECTION (Gambar 2) ──
                      const Text(
                        'Item Info',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── ITEM NAME ──
                      _buildLabel('Item Name'),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        decoration: _inputDecoration(hint: 'Masukkan nama item'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // ── QTY COUNTER (Gambar 2) ──
                      _buildLabel('Qty'),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2979FF), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                // Minus
                                IconButton(
                                  onPressed: () {
                                    if (_quantity > 0) {
                                      setState(() {
                                        _quantity--;
                                        _recalculateTotalValue();
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.remove, color: Colors.black54, size: 20),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  padding: EdgeInsets.zero,
                                ),
                                // Value
                                Container(
                                  width: 50,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$_quantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                // Plus
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2979FF),
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _quantity++;
                                        _recalculateTotalValue();
                                      });
                                    },
                                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // ── PRICE & TOTAL VALUE (Gambar 2 side-by-side) ──
                      Row(
                        children: [
                          // Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Price'),
                                TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  decoration: _inputDecoration(hint: 'Rp. 0'),
                                  onChanged: (_) => _recalculateTotalValue(),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Harga kosong';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Total Value (Read-Only)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Total Value'),
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    CartManager.formatPrice(_totalValue),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // ── WEIGHT ──
                      _buildLabel('Weight'),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        decoration: _inputDecoration(
                          hint: 'Masukkan berat',
                          suffix: Container(
                            padding: const EdgeInsets.only(left: 8),
                            child: const Text(
                              'Gr',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Berat kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // ── EXP DATE ──
                      _buildLabel('Exp Date'),
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _expDateController,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            decoration: _inputDecoration(
                              hint: 'dd/mm/yyyy',
                              suffix: const Icon(Icons.calendar_month, color: Colors.grey, size: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                  return 'Exp date kosong';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── SAVE BUTTON ──
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2979FF),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF2979FF).withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text(
                                  'SIMPAN PERUBAHAN',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2979FF), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2979FF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  void _showMockImageInputDialog() {
    final textController = TextEditingController(text: _imageUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan URL Foto'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _imageUrl = textController.text.trim();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
