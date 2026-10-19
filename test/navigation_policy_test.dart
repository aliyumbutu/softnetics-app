import 'package:flutter_test/flutter_test.dart';
import 'package:softnetics/services/navigation_policy.dart';

void main() {
  NavAction d(String u) => decide(Uri.parse(u));
  test('url rules', () {
    expect(d('https://scsap.softnetics.ng/app'), NavAction.webview);
    expect(d('https://checkout.paystack.com/abc'), NavAction.paystack);
    expect(d('https://room.daily.co/x'), NavAction.webview);
    expect(d('tel:*123#'), NavAction.phone);
    expect(d('https://wa.me/234'), NavAction.phone);
    expect(d('https://softnetics.ng'), NavAction.inAppBrowser);
    expect(d('https://example.com'), NavAction.inAppBrowser);
    expect(d('blob:https://scsap.softnetics.ng/1'), NavAction.download);
  });
  test('root paths', () {
    expect(isRootPath('/app/'), true);
    expect(isRootPath('/app/wallet'), false);
  });
}
