import 'dart:io';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/local_database_service.dart';

class ProfilePhotoService {
  ProfilePhotoService({
    LocalDatabaseService? localDatabase,
    ImagePicker? imagePicker,
    ImageCropper? imageCropper,
  }) : _localDatabase = localDatabase ?? LocalDatabaseService(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _imageCropper = imageCropper ?? ImageCropper();

  static const _savedPhotoPathKey = 'profile_photo_path';
  static const _photoDirectoryName = 'profile_photos';

  final LocalDatabaseService _localDatabase;
  final ImagePicker _imagePicker;
  final ImageCropper _imageCropper;

  Future<String?> loadSavedPhotoPath() async {
    final savedPath = await _localDatabase.getPref(_savedPhotoPathKey);
    if (savedPath == null || savedPath.isEmpty) return null;

    if (!await File(savedPath).exists()) {
      await _localDatabase.deletePref(_savedPhotoPathKey);
      return null;
    }

    return savedPath;
  }

  Future<CroppedFile?> pickAndCrop(ImageSource source) async {
    final selectedImage = await _imagePicker.pickImage(source: source);
    if (selectedImage == null) return null;
    return cropImage(selectedImage.path);
  }

  Future<CroppedFile?> cropImage(String sourcePath) {
    return _imageCropper.cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Foto',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: AppColors.white,
          activeControlsWidgetColor: AppColors.primary,
          lockAspectRatio: true,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: 'Crop Foto',
          cancelButtonTitle: 'Batal',
          doneButtonTitle: 'Simpan',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
      ],
    );
  }

  Future<String> saveCroppedPhoto(CroppedFile croppedPhoto) async {
    final bytes = await File(croppedPhoto.path).readAsBytes();
    if (bytes.isEmpty) {
      throw const FileSystemException('Hasil crop foto kosong.');
    }

    final appDirectory = await getApplicationSupportDirectory();
    final photoDirectory = Directory(
      path.join(appDirectory.path, _photoDirectoryName),
    );
    await photoDirectory.create(recursive: true);

    final destinationPath = path.join(
      photoDirectory.path,
      'profile-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await File(destinationPath).writeAsBytes(bytes, flush: true);
    await _localDatabase.setPref(_savedPhotoPathKey, destinationPath);

    return destinationPath;
  }
}
