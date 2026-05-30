import 'package:flutter/material.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';

class EditItemPage extends StatefulWidget {
  final Product product;
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
  late TextEditingController _sellingPriceController; // Harga Jual
  late TextEditingController _capitalPriceController; // Harga Beli
  late TextEditingController _weightController;
  late TextEditingController _expDateController;
  
  int _quantity = 1;
  String? _imageUrl;
  bool _isSaving = false;
  bool _isDeleting = false;
  
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _sellingPriceController = TextEditingController(text: widget.product.price.toStringAsFixed(0));
    _capitalPriceController = TextEditingController(text: '0');
    _quantity = widget.product.stock > 0 ? widget.product.stock : 1;
    _imageUrl = widget.product.imageUrl;
    _weightController = TextEditingController(text: '');
    _expDateController = TextEditingController(text: '');
    
    _loadInventoryDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    _capitalPriceController.dispose();
    _weightController.dispose();
    _expDateController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryDetails() async {
    try {
      final response = await supabase
          .from('inventories')
          .select()
          .eq('id', widget.product.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _quantity = (response['qty_available'] as num?)?.toInt() ?? _quantity;
          _sellingPriceController.text = ((response['selling_price'] as num?)?.toDouble() ?? widget.product.price).toStringAsFixed(0);
          _capitalPriceController.text = ((response['capital_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
          _nameController.text = (response['name'] ?? widget.product.name) as String;
          _imageUrl = response['image_url'] as String? ?? widget.product.imageUrl;
          
          
          if (response['exp_date'] != null) {
            final parsedDate = DateTime.tryParse(response['exp_date'].toString());
            if (parsedDate != null) {
              _selectedDate = parsedDate;
              _expDateController.text = _formatDate(parsedDate);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[SiKulak] Error loading detailed inventory data: $e');
    }
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

  Future<void> _handleDelete() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus produk ini?',
          style: TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'BATAL',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await supabase
          .from('inventories')
          .delete()
          .eq('id', widget.product.id);
      
      _onDeleteSuccess();
    } catch (e) {
      debugPrint('[SiKulak] Delete failed: $e');
      _onDeleteFailure(e.toString());
    }
  }

  void _onDeleteSuccess() {
    setState(() => _isDeleting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Produk berhasil dihapus!',
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

  void _onDeleteFailure(String error) {
    setState(() => _isDeleting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Gagal menghapus produk: $error',
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    final name = _nameController.text.trim();
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? widget.product.price;
    final capitalPrice = double.tryParse(_capitalPriceController.text) ?? 0;
    
    String? expDateIso;
    if (_selectedDate != null) {
      expDateIso = _selectedDate!.toIso8601String();
    } else if (_expDateController.text.isNotEmpty) {
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
      // Prepare update data
      final Map<String, dynamic> updateData = {
        'name': name,
        'qty_available': _quantity,
        'selling_price': sellingPrice,
        'capital_price': capitalPrice,
      };
      
      // Only add optional fields if they have values
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        updateData['image_url'] = _imageUrl;
      }
      
      if (expDateIso != null) {
        updateData['exp_date'] = expDateIso;
      }
      
      await supabase.from('inventories').update(updateData).eq('id', widget.product.id);
      
      _onSaveSuccess();
    } catch (e) {
      debugPrint('[SiKulak] Update failed: $e');
      _onSaveFailure(e.toString());
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

                      const Text(
                        'Photo (Optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showMockImageInputDialog,
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
                        'Ukuran max. 10 MB (Opsional)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500),
                      ),
                      const Divider(height: 36),

                      const Text(
                        'Item Info',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildLabel('Item Name *'),
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

                      _buildLabel('Qty *'),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2979FF), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (_quantity > 0) {
                                      setState(() {
                                        _quantity--;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.remove, color: Colors.black54, size: 20),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  padding: EdgeInsets.zero,
                                ),
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

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Harga Jual *'),
                                TextFormField(
                                  controller: _sellingPriceController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  decoration: _inputDecoration(hint: 'Rp. 0'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Harga jual kosong';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Harga Beli *'),
                                TextFormField(
                                  controller: _capitalPriceController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  decoration: _inputDecoration(hint: 'Rp. 0'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Harga beli kosong';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      _buildLabel('Exp Date (Optional)'),
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _expDateController,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            decoration: _inputDecoration(
                              hint: 'dd/mm/yyyy (opsional)',
                              suffix: const Icon(Icons.calendar_month, color: Colors.grey, size: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isSaving || _isDeleting) ? null : _handleSave,
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
                      
                      const SizedBox(height: 16),
                      
                      // Delete Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: (_isSaving || _isDeleting) ? null : _handleDelete,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isDeleting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.red),
                                )
                              : const Text(
                                  'HAPUS PRODUK',
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
            hintText: 'https://example.com/image.jpg (opsional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _imageUrl = textController.text.trim();
                if (_imageUrl?.isEmpty ?? true) {
                  _imageUrl = null;
                }
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