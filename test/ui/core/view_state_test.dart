import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/ui/core/view_state.dart';

void main() {
  test('ViewState 表达加载、数据和错误状态', () {
    const loading = ViewLoading<int>();
    const data = ViewData(value: 3);
    final error = ViewError<int>(error: StateError('加载失败'), retry: () {});

    expect(loading, isA<ViewState<int>>());
    expect(data.value, 3);
    expect(error.error, isA<StateError>());
    expect(error.retry, isNotNull);
  });
}
