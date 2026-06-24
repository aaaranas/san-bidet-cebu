import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../services/location_service.dart';
import 'bidet_model.dart';

class BidetAddScreen extends StatefulWidget {
  const BidetAddScreen({super.key});

  @override
  State<BidetAddScreen> createState() => _BidetAddScreenState();
}

class _BidetAddScreenState extends State<BidetAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _floorController = TextEditingController();
  String _selectedType = 'spray_hose';
  bool _isSubmitting = false;
  Position? _currentPosition;
  XFile? _selectedImage;
  Uint8List? _imageBytes;

  final _supabaseService = SupabaseService();
  final _locationService = LocationService();
  final _imagePicker = ImagePicker();

  static const _green = Color(0xFF0F172A);

  final _types = [
    ('spray_hose', 'Spray hose'),
    ('bidet_seat', 'Bidet seat'),
    ('tabo', 'Tabo'),
  ];

  @override
  void dispose() {
    _placeController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      setState(() => _currentPosition = pos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location captured!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location.')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture your location first.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final bidet = Bidet(
      id: '',
      placeName: _placeController.text.trim(),
      floor: _floorController.text.trim(),
      type: _selectedType,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      rating: 0,
      ratingCount: 0,
      createdAt: DateTime.now(),
    );

    final bidetId = await _supabaseService.addBidet(bidet);

    if (_imageBytes != null && _selectedImage != null) {
      final parts = _selectedImage!.path.split('.');
      final ext = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
      final imageUrl = await _supabaseService.uploadBidetImage(
          _imageBytes!, bidetId, ext);
      if (imageUrl != null) {
        await _supabaseService.updateBidetImage(bidetId, imageUrl);
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bidet submitted for review!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a bidet',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Place name',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _placeController,
              decoration: _inputDecoration('e.g. SM City Cebu'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter a place name' : null,
            ),
            const SizedBox(height: 16),
            const Text('Floor / specific location',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _floorController,
              decoration:
                  _inputDecoration('e.g. 3rd floor, near cinemas'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter the location' : null,
            ),
            const SizedBox(height: 16),
            const Text('Bidet type',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: _types.map((t) {
                final selected = _selectedType == t.$1;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = t.$1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? _green.withValues(alpha: 0.1)
                            : Colors.transparent,
                        border: Border.all(
                          color:
                              selected ? _green : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected ? _green : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Your location',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _getLocation,
              icon: const Icon(Icons.my_location, size: 16),
              label: Text(_currentPosition == null
                  ? 'Use my current location'
                  : 'Location captured ✓'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: BorderSide(
                  color: _currentPosition != null
                      ? _green
                      : Colors.grey.shade300,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Photo (optional)',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            if (_imageBytes != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedImage = null;
                        _imageBytes = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 4),
                      Text('Tap to add a photo',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit bidet location',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _green),
      ),
    );
  }
}
