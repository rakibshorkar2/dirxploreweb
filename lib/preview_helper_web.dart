import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerVideoView(String viewType, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final video = web.document.createElement('video') as web.HTMLVideoElement;
      video.src = url;
      video.controls = true;
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.border = 'none';
      video.style.backgroundColor = 'black';
      video.setAttribute('playsinline', 'true');
      video.setAttribute('webkit-playsinline', 'true');
      return video;
    },
  );
}

void registerAudioView(String viewType, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final audio = web.document.createElement('audio') as web.HTMLAudioElement;
      audio.src = url;
      audio.controls = true;
      audio.style.width = '100%';
      audio.style.height = '54px';
      audio.style.border = 'none';
      audio.style.backgroundColor = 'transparent';
      return audio;
    },
  );
}

void registerIframeView(String viewType, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = url;
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.style.border = 'none';
      return iframe;
    },
  );
}
