import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class AddItemPage extends StatefulWidget {
  final VoidCallback onSaved;

  const AddItemPage({
    super.key,
    required this.onSaved,
  });

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController(); // Harga Jual
  final TextEditingController _capitalPriceController = TextEditingController(); // Harga Beli
  final TextEditingController _expDateController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(); // New controller for quantity
  final TextEditingController _leadTimeController = TextEditingController(text: '0');
  
  int _quantity = 1;
  String _satuan = 'pcs';
  final List<String> _satuanOptions = ['pcs', 'sachet', 'butir', 'kg', 'botol'];
  String? _imageUrl;
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _quantityController.text = _quantity.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    _capitalPriceController.dispose();
    _expDateController.dispose();
    _quantityController.dispose();
    _leadTimeController.dispose();
    super.dispose();
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

  void _updateQuantity(int newQuantity) {
    if (newQuantity < 0) newQuantity = 0;
    setState(() {
      _quantity = newQuantity;
      _quantityController.text = _quantity.toString();
    });
  }

  void _onQuantityChanged(String value) {
    if (value.isEmpty) {
      _updateQuantity(0);
      return;
    }
    
    final int? parsedValue = int.tryParse(value);
    if (parsedValue != null && parsedValue >= 0) {
      _updateQuantity(parsedValue);
    } else {
      // If invalid input, revert to current quantity
      _quantityController.text = _quantity.toString();
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _isUploadingImage = true;
        });
        
        final bytes = await image.readAsBytes();
        final imageUrl = await _uploadImageToStorage(bytes);

        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _imageUrl = imageUrl;
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto berhasil diupload'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _uploadImageToStorage(Uint8List imageBytes) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'product_${userId}_$timestamp.jpg';
      final filePath = 'products/$userId/$fileName';
      
      await supabase.storage.from('product_image').uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      
      final publicUrl = supabase.storage.from('product_image').getPublicUrl(filePath);
      
      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);
    
    final name = _nameController.text.trim();
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;
    final capitalPrice = double.tryParse(_capitalPriceController.text) ?? 0.0;
    final leadTime = int.tryParse(_leadTimeController.text) ?? 0;
    
    String? expDateIso;
    if (_selectedDate != null) {
      expDateIso = _selectedDate!.toIso8601String();
    }

    try {
      // Prepare data for insertion, excluding null values
      final Map<String, dynamic> insertData = {
        'user_id': userId,
        'name': name,
        'qty_available': _quantity,
        'satuan': _satuan,
        'selling_price': sellingPrice, // Harga Jual
        'capital_price': capitalPrice, // Harga Beli
        'lead_time': leadTime,
      };
      
      // Only add image_url if image was uploaded
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        insertData['image_url'] = _imageUrl;
      }
      
      // Only add exp_date if selected
      if (expDateIso != null) {
        insertData['exp_date'] = expDateIso;
      }
      
      await supabase.from('inventories').insert(insertData);
      
      _onSaveSuccess();
    } catch (e) {
      debugPrint('[SiKulak] Add item failed: $e');
      _onSaveFailure(e.toString());
    }
  }

  void _onSaveSuccess() {
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Barang berhasil ditambahkan!',
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
          'Gagal menambahkan barang: $error',
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
                    'Tambahkan Produk Baru',
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
                        'Detail Produk',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mohon masukan detail produk baru',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Foto Produk',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _isUploadingImage ? null : _pickImage,
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
                          child: _isUploadingImage
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF2979FF),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Uploading...',
                                        style: TextStyle(
                                          color: Color(0xFF2979FF),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _selectedImageBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
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
                        'Pilih foto dari galeri (Opsional, max 10 MB)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500),
                      ),
                      const Divider(height: 36),

                      const Text(
                        'Info Produk',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildLabel('Nama Produk *'),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        decoration: _inputDecoration(hint: 'Masukkan nama produk'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      _buildLabel('Jumlah Stok *'),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2979FF), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                // Minus button
                                IconButton(
                                  onPressed: () {
                                    if (_quantity > 0) {
                                      _updateQuantity(_quantity - 1);
                                    }
                                  },
                                  icon: const Icon(Icons.remove, color: Colors.black54, size: 20),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  padding: EdgeInsets.zero,
                                ),
                                // Editable text field
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    onChanged: _onQuantityChanged,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Stok tidak boleh kosong';
                                      }
                                      final int? quantity = int.tryParse(value);
                                      if (quantity == null || quantity < 0) {
                                        return 'Stok harus berupa angka positif';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                // Plus button
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
                                      _updateQuantity(_quantity + 1);
                                    },
                                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _satuan,
                              decoration: _inputDecoration(hint: 'Satuan'),
                              items: _satuanOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _satuan = newValue!;
                                });
                              },
                              validator: (value) => value == null ? 'Pilih satuan' : null,
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

                      _buildLabel('Tanggal Kadaluarsa (Exp)'),
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
                      const SizedBox(height: 18),

                      _buildLabel('Lead Time (Hari Pengiriman) *'),
                      TextFormField(
                        controller: _leadTimeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        decoration: _inputDecoration(hint: '3 (default)'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lead time tidak boleh kosong';
                          }
                          final int? val = int.tryParse(value);
                          if (val == null || val < 0) {
                            return 'Harus berupa angka positif';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isSaving || _isUploadingImage) ? null : _handleSave,
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
                                  'TAMBAHKAN BARANG',
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
}