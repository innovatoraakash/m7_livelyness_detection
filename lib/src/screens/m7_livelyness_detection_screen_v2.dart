import 'dart:async';
import 'package:collection/collection.dart';
import 'package:m7_livelyness_detection/index.dart';

class M7LivelynessDetectionPageV2 extends StatelessWidget {
  final M7DetectionConfig config;
  const M7LivelynessDetectionPageV2({
    required this.config,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: M7LivelynessDetectionScreenV2(
          config: config,
        ),
      ),
    );
  }
}

class M7LivelynessDetectionScreenV2 extends StatefulWidget {
  final M7DetectionConfig config;

  const M7LivelynessDetectionScreenV2({
    required this.config,
    super.key,
  });

  @override
  State<M7LivelynessDetectionScreenV2> createState() =>
      _M7LivelynessDetectionScreenAndroidState();
}

class _M7LivelynessDetectionScreenAndroidState
    extends State<M7LivelynessDetectionScreenV2> {
  //* MARK: - Private Variables
  //? =========================================================
  final _faceDetectionController = BehaviorSubject<FaceDetectionModel>();

  final options = FaceDetectorOptions(
    enableContours: false,
    enableClassification: true,
    enableTracking: false,
    enableLandmarks: true,
    performanceMode: FaceDetectorMode.accurate,
    minFaceSize: 0.2,
  );
  late final faceDetector = FaceDetector(options: options);
  bool _didCloseEyes = false;
  bool _isProcessingStep = false;
  Size? imageSize;
  M7BlinkDetectionThreshold blinkThreshold = M7BlinkDetectionThreshold();
  M7HeadTurnDetectionThreshold headTurnThreshold =
      M7HeadTurnDetectionThreshold();
  M7SmileDetectionThreshold smileThreshold = M7SmileDetectionThreshold();

  late final List<M7LivelynessStepItem> _steps;
  final GlobalKey<M7LivelynessDetectionStepOverlayState> _stepsKey =
      GlobalKey<M7LivelynessDetectionStepOverlayState>();

  CameraState? _cameraState;
  // Face? detectedFace;
  bool _isProcessing = false;
  late bool _isInfoStepCompleted;
  Timer? _timerToDetectFace;
  bool _isCaptureButtonVisible = false;
  bool _isCompleted = false;

  //* MARK: - Life Cycle Methods
  //? =========================================================
  @override
  void initState() {
    _preInitCallBack();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _postFrameCallBack(),
    );
  }

  @override
  void deactivate() {
    faceDetector.close();
    super.deactivate();
  }

  @override
  void dispose() {
    _faceDetectionController.close();
    _timerToDetectFace?.cancel();
    _timerToDetectFace = null;
    super.dispose();
  }

  //* MARK: - Private Methods for Business Logic
  //? =========================================================
  void _preInitCallBack() {
    _steps = widget.config.steps;
    _isInfoStepCompleted = !widget.config.startWithInfoScreen;
  }

  void _postFrameCallBack() {
    blinkThreshold =
        (M7LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
              (p0) => p0 is M7BlinkDetectionThreshold,
            ) as M7BlinkDetectionThreshold?) ??
            blinkThreshold;
    smileThreshold =
        (M7LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
              (p0) => p0 is M7SmileDetectionThreshold,
            ) as M7SmileDetectionThreshold?) ??
            smileThreshold;
    headTurnThreshold =
        (M7LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
              (p0) => p0 is M7HeadTurnDetectionThreshold,
            ) as M7HeadTurnDetectionThreshold?) ??
            headTurnThreshold;
    if (_isInfoStepCompleted) {
      _startTimer();
    }
  }

  Future<void> _processCameraImage(AnalysisImage img) async {
    if (_isProcessing) {
      return;
    }
    if (mounted) {
      setState(
        () => _isProcessing = true,
      );
    }
    final inputImage = img.toInputImage();

    try {
      final List<Face> detectedFaces =
          await faceDetector.processImage(inputImage);
      _faceDetectionController.add(
        FaceDetectionModel(
          faces: detectedFaces,
          absoluteImageSize: inputImage.metadata!.size,
          rotation: 0,
          imageRotation: img.inputImageRotation,
          croppedSize: img.croppedSize,
        ),
      );
      await _processImage(inputImage, detectedFaces);
      if (mounted) {
        setState(
          () => _isProcessing = false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _isProcessing = false,
        );
      }
      debugPrint("...sending image resulted error $error");
    }
  }

  Future<void> _processImage(InputImage img, List<Face> faces) async {
    try {
      if (faces.isEmpty) {
        _resetSteps();
        return;
      }
      final Face firstFace = _findMainFaceByCenter(faces);
      final landmarks = firstFace.landmarks;
      // Get landmark positions for relevant facial features
      final Point<int>? leftEye = landmarks[FaceLandmarkType.leftEye]?.position;
      final Point<int>? rightEye =
          landmarks[FaceLandmarkType.rightEye]?.position;
      final Point<int>? leftCheek =
          landmarks[FaceLandmarkType.leftCheek]?.position;
      final Point<int>? rightCheek =
          landmarks[FaceLandmarkType.rightCheek]?.position;
      final Point<int>? leftEar = landmarks[FaceLandmarkType.leftEar]?.position;
      final Point<int>? rightEar =
          landmarks[FaceLandmarkType.rightEar]?.position;
      final Point<int>? leftMouth =
          landmarks[FaceLandmarkType.leftMouth]?.position;
      final Point<int>? rightMouth =
          landmarks[FaceLandmarkType.rightMouth]?.position;
      // Calculate symmetry values based on corresponding landmark positions
      final Map<String, double> symmetry = {};
      final eyeSymmetry = calculateSymmetry(
        leftEye,
        rightEye,
      );
      symmetry['eyeSymmetry'] = eyeSymmetry;

      final cheekSymmetry = calculateSymmetry(
        leftCheek,
        rightCheek,
      );
      symmetry['cheekSymmetry'] = cheekSymmetry;

      final earSymmetry = calculateSymmetry(
        leftEar,
        rightEar,
      );
      symmetry['earSymmetry'] = earSymmetry;

      final mouthSymmetry = calculateSymmetry(
        leftMouth,
        rightMouth,
      );
      symmetry['mouthSymmetry'] = mouthSymmetry;
      double total = 0.0;
      symmetry.forEach((key, value) {
        total += value;
      });
      final double average = total / symmetry.length;
      print("Face Symmetry: $average");
      if (_isProcessingStep &&
          _steps[_stepsKey.currentState?.currentIndex ?? 0].step ==
              M7LivelynessStep.blink) {
        if (_didCloseEyes) {
          if ((faces.first.leftEyeOpenProbability ?? 1.0) < 0.75 &&
              (faces.first.rightEyeOpenProbability ?? 1.0) < 0.75) {
            await _completeStep(
              step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
            );
          }
        }
      }
      _detect(
        face: firstFace,
        step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
      );
      // detectedFace = _findWellPositionedFace(firstFace) ?? detectedFace;
    } catch (e) {
      _startProcessing();
    }
  }

  static Face _findMainFaceByCenter(List<Face> faces) {
    Face mainFace = faces.first;
    double minWidth = 0;

    for (final face in faces) {
      final distance = face.boundingBox.width;
      if (distance > minWidth) {
        minWidth = distance;
        mainFace = face;
      }
    }
    return mainFace;
  }

  Face? _findWellPositionedFace(Face face) {
    bool wellPositioned = true;

    // Head is rotated to the x degrees
    if (face.headEulerAngleX! > 10 || face.headEulerAngleX! < -10) {
      wellPositioned = false;
    }
    // Head is rotated to the right rotY degrees
    if (face.headEulerAngleY! > 10 || face.headEulerAngleY! < -10) {
      wellPositioned = false;
    }

    // Head is tilted sideways rotZ degrees
    if (face.headEulerAngleZ! > 10 || face.headEulerAngleZ! < -10) {
      wellPositioned = false;
    }

    // If landmark detection was enabled with FaceDetectorOptions (mouth, ears,
    // eyes, cheeks, and nose available):
    final FaceLandmark? leftEar = face.landmarks[FaceLandmarkType.leftEar];
    final FaceLandmark? rightEar = face.landmarks[FaceLandmarkType.rightEar];
    final FaceLandmark? bottomMouth =
        face.landmarks[FaceLandmarkType.bottomMouth];
    final FaceLandmark? rightMouth =
        face.landmarks[FaceLandmarkType.rightMouth];
    final FaceLandmark? leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
    final FaceLandmark? noseBase = face.landmarks[FaceLandmarkType.noseBase];
    if (leftEar == null ||
        rightEar == null ||
        bottomMouth == null ||
        rightMouth == null ||
        leftMouth == null ||
        noseBase == null) {
      wellPositioned = false;
    }

    if (face.leftEyeOpenProbability != null) {
      if (face.leftEyeOpenProbability! < 0.5) {
        wellPositioned = false;
      }
    }

    if (face.rightEyeOpenProbability != null) {
      if (face.rightEyeOpenProbability! < 0.5) {
        wellPositioned = false;
      }
    }
    if (wellPositioned) {
      return face;
    }
    return null;
  }

  Future<void> _completeStep({
    required M7LivelynessStep step,
  }) async {
    final int indexToUpdate = _steps.indexWhere(
      (p0) => p0.step == step,
    );

    _steps[indexToUpdate] = _steps[indexToUpdate].copyWith(
      isCompleted: true,
    );
    if (mounted) {
      setState(() {});
    }
    await _stepsKey.currentState?.nextPage();
    _stopProcessing();
    widget.config.onStepChange?.call(indexToUpdate, step);
  }

  void _detect({
    required Face face,
    required M7LivelynessStep step,
  }) async {
    switch (step) {
      case M7LivelynessStep.blink:
        if ((face.leftEyeOpenProbability ?? 1.0) <
                (blinkThreshold.leftEyeProbability) &&
            (face.rightEyeOpenProbability ?? 1.0) <
                (blinkThreshold.rightEyeProbability)) {
          _startProcessing();
          if (mounted) {
            setState(
              () => _didCloseEyes = true,
            );
          }
        }
        break;
      case M7LivelynessStep.turnLeft:
        if ((face.headEulerAngleY ?? 0) > (headTurnThreshold.rotationAngle)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case M7LivelynessStep.turnRight:
        if ((face.headEulerAngleY ?? 0) < (-headTurnThreshold.rotationAngle)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case M7LivelynessStep.smile:
        // const double smileThreshold = 0.75;
        if ((face.smilingProbability ?? 0) > (smileThreshold.probability)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case M7LivelynessStep.lookUp:
        debugPrint(face.toString());

        if ((face.headEulerAngleX ?? 0) > (headTurnThreshold.rotationAngle)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;

      case M7LivelynessStep.lookDown:
        debugPrint(face.toString());

        if ((face.headEulerAngleX ?? 0) < (-headTurnThreshold.rotationAngle)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
    }
  }

  void _startProcessing() {
    if (!mounted) {
      return;
    }
    setState(
      () => _isProcessingStep = true,
    );
  }

  void _stopProcessing() {
    if (!mounted) {
      return;
    }
    setState(
      () => _isProcessingStep = false,
    );
  }

  void _startTimer() {
    _timerToDetectFace = Timer(
      Duration(seconds: widget.config.maxSecToDetect),
      () {
        _timerToDetectFace?.cancel();
        _timerToDetectFace = null;
        if (widget.config.allowAfterMaxSec) {
          _isCaptureButtonVisible = true;
          if (mounted) {
            setState(() {});
          }
          return;
        }
        _onDetectionCompleted(
          imgToReturn: null,
        );
      },
    );
  }

  Future<void> _takePicture({
    required bool didCaptureAutomatically,
  }) async {
    if (_cameraState == null) {
      _onDetectionCompleted();
      return;
    }
    _cameraState?.when(
      onPhotoMode: (p0) => Future.delayed(
        const Duration(milliseconds: 100),
        () => p0.takePhoto().then(
          (value) {
            // if (detectedFace != null) {
            //   cropImage(File(value), detectedFace!.boundingBox);
            // }
            _onDetectionCompleted(
              imgToReturn: value.path,
              didCaptureAutomatically: didCaptureAutomatically,
            );
          },
        ),
      ),
    );
  }

  void _onDetectionCompleted({
    String? imgToReturn,
    bool? didCaptureAutomatically,
  }) {
    if (_isCompleted) {
      return;
    }
    setState(
      () => _isCompleted = true,
    );
    final String imgPath = imgToReturn ?? "";
    if (imgPath.isEmpty || didCaptureAutomatically == null) {
      Navigator.of(context).pop(null);
      return;
    }
    Navigator.of(context).pop(
      M7CapturedImage(
        imgPath: imgPath,
        didCaptureAutomatically: didCaptureAutomatically,
      ),
    );
  }

  void _resetSteps() async {
    for (var p0 in _steps) {
      final int index = _steps.indexWhere(
        (p1) => p1.step == p0.step,
      );
      _steps[index] = _steps[index].copyWith(
        isCompleted: false,
      );
    }
    _didCloseEyes = false;
    if (_stepsKey.currentState?.currentIndex != 0) {
      _stepsKey.currentState?.reset();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        _isInfoStepCompleted
            ? CameraAwesomeBuilder.custom(
                sensorConfig: SensorConfig.single(
                  flashMode: FlashMode.auto,
                  aspectRatio: CameraAspectRatios.ratio_16_9,
                  sensor: Sensor.position(SensorPosition.front),
                ),
                previewFit: CameraPreviewFit.cover,
                onImageForAnalysis: (img) => _processCameraImage(img),
                imageAnalysisConfig: AnalysisConfig(
                  autoStart: true,
                  androidOptions: const AndroidAnalysisOptions.nv21(
                    width: 250,
                  ),
                  maxFramesPerSecond: 30,
                ),
                builder: (state, preview) {
                  _cameraState = state;
                  final child = M7PreviewDecoratorWidget(
                    cameraState: state,
                    faceDetectionStream: _faceDetectionController,
                    previewSize: preview.previewSize,
                    previewRect: preview.rect,
                    detectionColor:
                        _steps[_stepsKey.currentState?.currentIndex ?? 0]
                            .detectionColor,
                  );
                  if (widget.config.wrapper != null) {
                    return widget.config.wrapper!(
                        child, _stepsKey.currentState?.currentIndex ?? 0);
                  }
                  return child;
                },
                saveConfig: SaveConfig.photo(
                  pathBuilder: (sensor) async {
                    final String fileName = "${M7Utils.generate()}.jpg";
                    final String path = await getTemporaryDirectory().then(
                      (value) => value.path,
                    );
                    return SingleCaptureRequest(
                        "$path/$fileName", sensor.first);
                  },
                ),
              )
            : M7LivelynessInfoWidget(
                onStartTap: () {
                  if (!mounted) {
                    return;
                  }
                  _startTimer();
                  setState(
                    () => _isInfoStepCompleted = true,
                  );
                },
              ),
        if (_isInfoStepCompleted)
          M7LivelynessDetectionStepOverlay(
            key: _stepsKey,
            config: widget.config,
            steps: _steps,
            onCompleted: () => _takePicture(
              didCaptureAutomatically: true,
            ),
          ),
        Visibility(
          visible: _isCaptureButtonVisible,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Spacer(
                flex: 20,
              ),
              MaterialButton(
                onPressed: () => _takePicture(
                  didCaptureAutomatically: false,
                ),
                color: widget.config.captureButtonColor ??
                    Theme.of(context).primaryColor,
                textColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: const CircleBorder(),
                child: const Icon(
                  Icons.camera_alt,
                  size: 24,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        if (widget.config.showCloseButton)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 10,
                top: 10,
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black,
                child: IconButton(
                  onPressed: () {
                    _onDetectionCompleted(
                      imgToReturn: null,
                      didCaptureAutomatically: null,
                    );
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double calculateSymmetry(
      Point<int>? leftPosition, Point<int>? rightPosition) {
    if (leftPosition != null && rightPosition != null) {
      final double dx = (rightPosition.x - leftPosition.x).abs().toDouble();
      final double dy = (rightPosition.y - leftPosition.y).abs().toDouble();
      final distance = Offset(dx, dy).distance;

      return distance;
    }

    return 0.0;
  }
}
