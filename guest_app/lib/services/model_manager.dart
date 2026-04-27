import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ModelManager {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  final ValueNotifier<double> downloadProgress = ValueNotifier(0.0);
  final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  final ValueNotifier<bool> isModelReady = ValueNotifier(false);

  // Gemma 3 270M IT — Q8 Quantized (optimized for mobile offline inference)
  static const String _modelUrl = 'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task';
  static const String _modelId = 'gemma3-270m-it-q8.task';

  /// Check if the model is already present on device and initialize it.
  Future<void> init() async {
    if (kIsWeb) return;
    
    // Initialize the FlutterGemma service registry
    await FlutterGemma.initialize(
      maxDownloadRetries: 3,
      huggingFaceToken: dotenv.env['HF_TOKEN'],
    );
    
    final isInstalled = await FlutterGemma.isModelInstalled(_modelId);
    if (isInstalled) {
      isModelReady.value = true;
      // Pre-load the active model spec so it's ready for inference
      try {
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
          fileType: ModelFileType.task,
        ).fromNetwork(_modelUrl).install(); // This will just set it as active if already installed
      } catch (e) {
        debugPrint('[ModelManager] Failed to set active model: $e');
      }
    }
  }

  /// High-fidelity sync using FlutterGemma's built-in installer
  Future<void> downloadModel() async {
    if (isDownloading.value || isModelReady.value) return;

    isDownloading.value = true;
    downloadProgress.value = 0.0;
    
    if (kIsWeb) {
      debugPrint('[ModelManager] Web environment detected. Offline Gemma requires native platform.');
      isDownloading.value = false;
      return;
    }

    try {
      debugPrint('[ModelManager] Starting high-fidelity sync from $_modelUrl...');
      
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      )
      .fromNetwork(_modelUrl)
      .withProgress((progress) {
        downloadProgress.value = (progress / 100.0).clamp(0.0, 1.0);
      })
      .install();

      isModelReady.value = true;
      debugPrint('[ModelManager] Sync complete! Gemma Core ready for inference.');
    } catch (e, stack) {
      debugPrint('[ModelManager] CRITICAL: Download failed!');
      debugPrint('[ModelManager] Error: $e');
      debugPrint('[ModelManager] Stack: $stack');
      isModelReady.value = false;
      downloadProgress.value = 0.0;
    } finally {
      isDownloading.value = false;
    }
  }

  Future<void> deleteModel() async {
    if (kIsWeb) {
      isModelReady.value = false;
      return;
    }
    try {
      await FlutterGemma.uninstallModel(_modelId);
      isModelReady.value = false;
      downloadProgress.value = 0.0;
    } catch (e) {
      debugPrint('[ModelManager] Uninstall failed: $e');
    }
  }
}
