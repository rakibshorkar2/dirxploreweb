import 'preview_helper_unsupported.dart'
    if (dart.library.html) 'preview_helper_web.dart' as impl;

void triggerRegisterVideoView(String viewType, String url) {
  impl.registerVideoView(viewType, url);
}

void triggerRegisterAudioView(String viewType, String url) {
  impl.registerAudioView(viewType, url);
}

void triggerRegisterIframeView(String viewType, String url) {
  impl.registerIframeView(viewType, url);
}
