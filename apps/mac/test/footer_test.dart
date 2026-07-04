import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakieai/widgets/footer.dart';

void main() {
  test('the bar stays up until the LAST overlapping op finishes', () {
    fakeAsync((async) {
      final c = FooterController();
      final scan = c.start('Refreshing accounts…');
      final update = c.start('Refreshing Claude 2…');

      // First op done: message surfaces, but no green 100% + hide — the
      // other op still owns the bar.
      c.finish('Claude 2 refreshed', op: update);
      expect(c.running, isTrue);
      expect(c.done, isFalse);
      expect(c.label, 'Claude 2 refreshed');

      // Last op done: the real full finish.
      c.finish('All accounts up to date', op: scan);
      expect(c.done, isTrue);
      expect(c.fill, 100);
      async.elapse(const Duration(seconds: 2));
      expect(c.running, isFalse);
      c.dispose();
    });
  });

  test('an instant result during other work updates the label, not the bar',
      () {
    fakeAsync((async) {
      final c = FooterController();
      final scan = c.start('Refreshing accounts…');

      c.finish('Daily wake set to 8:00am'); // no op — instant result
      expect(c.running, isTrue);
      expect(c.done, isFalse); // never looks finished while the scan runs

      c.finish('All accounts up to date', op: scan);
      expect(c.done, isTrue);
      async.elapse(const Duration(seconds: 2));
      c.dispose();
    });
  });

  test('a failure mid-work shows red, then hands the bar back', () {
    fakeAsync((async) {
      final c = FooterController();
      final scan = c.start('Refreshing accounts…');

      c.fail('Claude 2: couldn\'t read usage — try Update',
          op: c.start('Refreshing Claude 2…'));
      expect(c.failed, isTrue);
      expect(c.running, isTrue);

      async.elapse(const Duration(seconds: 3));
      expect(c.failed, isFalse); // reverted — the scan still owns the bar
      expect(c.running, isTrue);

      c.finish('All accounts up to date', op: scan);
      async.elapse(const Duration(seconds: 2));
      expect(c.running, isFalse);
      c.dispose();
    });
  });

  test('a new op after a full finish restarts the bar fresh', () {
    fakeAsync((async) {
      final c = FooterController();
      c.finish('Claude 2 signed in'); // instant, idle → full green
      expect(c.done, isTrue);
      expect(c.fill, 100);

      c.start('Refreshing Claude 2…');
      expect(c.done, isFalse);
      expect(c.fill, 6); // fresh bar for genuinely new work
      expect(c.running, isTrue);
      c.dispose();
    });
  });
}
