import 'package:m7_livelyness_detection/index.dart';

class M7LivelynessDetectionStepOverlay extends StatefulWidget {
  final List<M7LivelynessStepItem> steps;
  final VoidCallback onCompleted;
  final M7DetectionConfig config;
  const M7LivelynessDetectionStepOverlay({
    super.key,
    required this.steps,
    required this.config,
    required this.onCompleted,
  });

  @override
  State<M7LivelynessDetectionStepOverlay> createState() =>
      M7LivelynessDetectionStepOverlayState();
}

class M7LivelynessDetectionStepOverlayState
    extends State<M7LivelynessDetectionStepOverlay> {
  //* MARK: - Public Variables
  //? =========================================================
  int get currentIndex {
    return _currentIndex;
  }

  bool _isLoading = false;

  //* MARK: - Private Variables
  //? =========================================================
  int _currentIndex = 0;

  late final PageController _pageController;

  //* MARK: - Life Cycle Methods
  //? =========================================================
  @override
  void initState() {
    _pageController = PageController(
      initialPage: 0,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          _buildBody(),
          Visibility(
            visible: _isLoading,
            child: const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
        ],
      ),
    );
  }

  //* MARK: - Public Methods for Business Logic
  //? =========================================================
  Future<void> nextPage() async {
    if (_isLoading) {
      return;
    }
    if ((_currentIndex + 1) <= (widget.steps.length - 1)) {
      //Move to next step
      _showLoader();

      await _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeIn,
      );

      _hideLoader();
      setState(() => _currentIndex++);
    } else {
      widget.onCompleted();
    }
  }

  void reset() {
    _pageController.jumpToPage(0);
    setState(() => _currentIndex = 0);
  }

  //* MARK: - Private Methods for Business Logic
  //? =========================================================
  void _showLoader() => setState(
        () => _isLoading = true,
      );

  void _hideLoader() => setState(
        () => _isLoading = false,
      );

  //* MARK: - Private Methods for UI Components
  //? =========================================================
  Widget _buildBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.config.showStepper
            ? SizedBox(
                height: 5,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      flex: _currentIndex + 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: widget.steps.length - (_currentIndex + 1),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: 16,
              ),
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: SizedBox(
            height: kToolbarHeight,
            child: AbsorbPointer(
              absorbing: true,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.steps.length,
                itemBuilder: (context, index) {
                  return _buildAnimatedWidget(
                    Container(
                      height: kToolbarHeight,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 5,
                            spreadRadius: 2.5,
                            color: Colors.black12,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        widget.steps[index].title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    isExiting: index != _currentIndex,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedWidget(
    Widget child, {
    required bool isExiting,
  }) {
    return isExiting
        ? ZoomOut(
            animate: true,
            child: FadeOutLeft(
              animate: true,
              delay: const Duration(milliseconds: 200),
              child: child,
            ),
          )
        : ZoomIn(
            animate: true,
            delay: const Duration(milliseconds: 500),
            child: FadeInRight(
              animate: true,
              delay: const Duration(milliseconds: 700),
              child: child,
            ),
          );
  }
}
