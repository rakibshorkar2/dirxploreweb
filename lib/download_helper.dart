import 'download_helper_unsupported.dart'
    if (dart.library.html) 'download_helper_web.dart';

void triggerDeviceDownload(String url, String name) {
  downloadFile(url, name);
}
