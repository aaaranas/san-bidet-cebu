import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/models/bidet.dart';
import '../../widgets/app_widgets.dart';

class BidetAddScreen extends StatefulWidget {
  const BidetAddScreen({super.key});

  @override
  State<BidetAddScreen> createState() => _BidetAddScreenState();
}

class _BidetAddScreenState extends State<BidetAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _floorController = TextEditingController();
  final _imagePicker = ImagePicker();

  BidetType _type = BidetType.sprayHose;
  Position? _position;
  XFile? _image;
  Uint8List? _imageBytes;

  bool _submitting = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _placeController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    final result = await context.location.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.ok) {
        _position = result.position;
        _error = null;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = image;
        _imageBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not open that image. Try another one.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null) {
      setState(() => _error = 'Capture your location before submitting.');
      return;
    }

    final repo = context.bidets;
    final userId = context.session.user?.id;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final created = await repo.add(
        Bidet(
          id: '',
          placeName: _placeController.text.trim(),
          floor: _floorController.text.trim(),
          type: _type,
          latitude: _position!.latitude,
          longitude: _position!.longitude,
          createdAt: DateTime.now(),
        ),
        userId: userId,
      );

      // A failed photo upload must not lose the submission itself, so it is
      // reported separately rather than aborting.
      var photoFailed = false;
      if (_imageBytes != null && _image != null) {
        try {
          final url = await repo.uploadImage(
            _imageBytes!,
            created.id,
            // XFile.name, not .path: on web the path is a blob: URL and the
            // old extension-parsing produced a corrupt content type.
            _image!.name,
          );
          if (url != null) await repo.setImageUrl(created.id, url);
        } catch (_) {
          photoFailed = true;
        }
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            photoFailed
                ? 'Bidet submitted for review — but the photo failed to upload.'
                : 'Bidet submitted for review!',
          ),
        ),
      );
      router.canPop() ? router.pop() : router.go(Routes.map);
    } catch (e) {
      // Previously any failure here left the button spinning forever with no
      // message at all.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit this bidet. Check your connection '
            'and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.shad;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a bidet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.map),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Insets.xl),
          children: [
            CenteredBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Place name',
                    controller: _placeController,
                    hint: 'e.g. SM City Cebu',
                    textInputAction: TextInputAction.next,
                    enabled: !_submitting,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Enter a place name'
                        : null,
                  ),
                  const SizedBox(height: Insets.lg),
                  AppTextField(
                    label: 'Floor / specific location',
                    controller: _floorController,
                    hint: 'e.g. 3rd floor, near cinemas',
                    textInputAction: TextInputAction.done,
                    enabled: !_submitting,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Describe where to find it'
                        : null,
                  ),
                  const SizedBox(height: Insets.xl),
                  Text('Bidet type', style: context.texts.bodyMedium),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: BidetType.values.map((t) {
                      final selected = _type == t;
                      return ChoiceChip(
                        label: Text(t.label),
                        selected: selected,
                        onSelected: _submitting
                            ? null
                            : (_) => setState(() => _type = t),
                        showCheckmark: false,
                        selectedColor: p.primary.withValues(alpha: 0.12),
                        side: BorderSide(
                          color: selected ? p.primary : p.border,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? p.primary : p.mutedForeground,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: Insets.xl),
                  Text('Your location', style: context.texts.bodyMedium),
                  const SizedBox(height: Insets.sm),
                  OutlinedButton.icon(
                    onPressed: _submitting || _locating ? null : _getLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _position == null
                                ? Icons.my_location
                                : Icons.check_circle,
                            size: 16,
                          ),
                    label: Text(
                      _position == null
                          ? 'Use my current location'
                          : 'Location captured '
                              '(${_position!.latitude.toStringAsFixed(5)}, '
                              '${_position!.longitude.toStringAsFixed(5)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _position != null ? p.primary : p.border,
                        width: _position != null ? 1.5 : 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  Text('Photo (optional)', style: context.texts.bodyMedium),
                  const SizedBox(height: Insets.sm),
                  _photoField(context),
                  if (_error != null) ...[
                    const SizedBox(height: Insets.lg),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: Insets.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit bidet location'),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'Submissions are reviewed by a moderator before they '
                    'appear on the map.',
                    style: context.texts.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoField(BuildContext context) {
    final p = context.shad;

    if (_imageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: Image.memory(
              _imageBytes!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: Insets.sm,
            right: Insets.sm,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Remove photo',
                iconSize: 16,
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _image = null;
                          _imageBytes = null;
                        }),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _submitting ? null : _pickImage,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: p.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: p.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: p.mutedForeground,
            ),
            const SizedBox(height: Insets.xs),
            Text('Tap to add a photo', style: context.texts.bodySmall),
          ],
        ),
      ),
    );
  }
}
