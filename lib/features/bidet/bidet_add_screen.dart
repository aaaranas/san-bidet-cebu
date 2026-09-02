import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/bidet_repository.dart';
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
  AccessType _access = AccessType.public;
  final _hoursController = TextEditingController();
  final _feeController = TextEditingController();
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
    _hoursController.dispose();
    _feeController.dispose();
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

  /// Shown when something already exists within ~120m. Returns true if the
  /// user says it is genuinely a different bidet.
  Future<bool> _confirmNotDuplicate(List<NearbyBidet> nearby) async {
    final theme = ShadTheme.of(context);
    final proceed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Already mapped?'),
        description: Text(
          nearby.length == 1
              ? 'There is already a bidet very close to here.'
              : 'There are already ${nearby.length} bidets close to here.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Never mind'),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mine is different'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in nearby)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.floor.isEmpty
                              ? n.placeName
                              : '${n.placeName} — ${n.floor}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        '${n.distanceMeters.round()}m',
                        style: theme.textTheme.muted,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return proceed ?? false;
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
      // Two people can easily add the same mall restroom. Catch it before the
      // row exists, rather than leaving a mess to clean up afterwards.
      final nearby = await repo.findNearby(
        _position!.latitude,
        _position!.longitude,
      );
      if (nearby.isNotEmpty && mounted) {
        final proceed = await _confirmNotDuplicate(nearby);
        if (!proceed) {
          if (mounted) setState(() => _submitting = false);
          return;
        }
      }
      if (!mounted) return;

      final created = await repo.add(
        Bidet(
          id: '',
          placeName: _placeController.text.trim(),
          floor: _floorController.text.trim(),
          type: _type,
          latitude: _position!.latitude,
          longitude: _position!.longitude,
          createdAt: DateTime.now(),
          accessType: _access,
          hoursNote: _hoursController.text.trim(),
          feeNote: _feeController.text.trim(),
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
    } on BidetFailure catch (e) {
      // Show the real reason. A generic "check your connection" sent people
      // looking at their wifi when the database was rejecting the row.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
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
                  ShadSelectFormField<BidetType>(
                    initialValue: _type,
                    enabled: !_submitting,
                    minWidth: double.infinity,
                    placeholder: const Text('Choose a type'),
                    options: [
                      for (final t in BidetType.values)
                        ShadOption(value: t, child: Text(t.label)),
                    ],
                    selectedOptionBuilder: (context, value) =>
                        Text(value.label),
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                  const SizedBox(height: Insets.xl),

                  // Access reality. "3rd floor near the cinemas" does not say
                  // whether you can actually walk in, which is usually what
                  // decides whether the trip is worth it.
                  Text('Who can use it', style: context.texts.bodyMedium),
                  const SizedBox(height: Insets.sm),
                  ShadSelectFormField<AccessType>(
                    initialValue: _access,
                    enabled: !_submitting,
                    minWidth: double.infinity,
                    placeholder: const Text('Choose access'),
                    options: [
                      for (final a in AccessType.values)
                        ShadOption(value: a, child: Text(a.label)),
                    ],
                    selectedOptionBuilder: (context, value) =>
                        Text(value.label),
                    onChanged: (v) {
                      if (v != null) setState(() => _access = v);
                    },
                  ),
                  const SizedBox(height: Insets.lg),
                  AppTextField(
                    label: 'When is it open (optional)',
                    controller: _hoursController,
                    hint: 'e.g. Mall hours, 10am–9pm',
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: Insets.lg),
                  AppTextField(
                    label: 'Any cost (optional)',
                    controller: _feeController,
                    hint: 'Leave blank if free',
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
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
                    child: ShadButton(
                      width: double.infinity,
                      size: ShadButtonSize.lg,
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 17,
                              width: 17,
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
