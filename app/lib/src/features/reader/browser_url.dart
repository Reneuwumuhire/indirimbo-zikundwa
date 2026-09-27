import 'browser_url_stub.dart'
    if (dart.library.html) 'browser_url_web.dart'
    as impl;

void showSongInAddressBar(String id, String title) =>
    impl.showSongInAddressBar(id, title);

void clearSongFromAddressBar(String id) => impl.clearSongFromAddressBar(id);
