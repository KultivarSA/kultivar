import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/services/error_reporter.dart';

void main() {
  // Each test installs its own sink and restores the default in
  // teardown so cross-test contamination is impossible.
  late List<ErrorRecord> captured;

  setUp(() {
    captured = [];
    ErrorReporter.setSink(captured.add);
  });

  tearDown(ErrorReporter.resetSink);

  test('report forwards operation, error, stack and extras to sink', () {
    final stack = StackTrace.current;
    ErrorReporter.report(
      'TestClass.doThing',
      'boom',
      stack,
      {'plantId': 'abc', 'attempt': 2},
    );

    expect(captured, hasLength(1));
    final r = captured.single;
    expect(r.operation, 'TestClass.doThing');
    expect(r.error, 'boom');
    expect(r.stackTrace, same(stack));
    expect(r.extras, equals({'plantId': 'abc', 'attempt': 2}));
  });

  test('stackTrace and extras are optional', () {
    ErrorReporter.report('TestClass.simple', Exception('nope'));
    expect(captured, hasLength(1));
    final r = captured.single;
    expect(r.stackTrace, isNull);
    expect(r.extras, isNull);
  });

  test('setSink returns the previous sink so it can be restored', () {
    final calls = <ErrorRecord>[];
    final original = ErrorReporter.setSink(calls.add);
    // `original` should be the sink we installed in setUp.
    expect(original, isNotNull);
    ErrorReporter.report('A.x', 'one');
    expect(calls, hasLength(1));
    // Restoring the captured-list sink should route a second event to
    // it instead of the temporary list.
    ErrorReporter.setSink(original);
    ErrorReporter.report('A.y', 'two');
    expect(calls, hasLength(1)); // unchanged
    expect(captured.single.operation, 'A.y');
  });

  test('resetSink restores the default debug-only sink', () {
    ErrorReporter.resetSink();
    // After reset, the captured-list sink should be detached — invoking
    // `report` must NOT add to it.  The default sink prints to debugPrint
    // (in debug mode only); we just verify our capture is no longer hit.
    ErrorReporter.report('A.x', 'after-reset');
    expect(captured, isEmpty);
  });
}
