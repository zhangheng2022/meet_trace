/// ViewModel 向 View 暴露的统一状态。
sealed class ViewState<T> {
  const ViewState();
}

/// 数据正在加载。
final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

/// 数据加载完成。
final class ViewData<T> extends ViewState<T> {
  const ViewData({required this.value});

  final T value;
}

/// 数据加载失败，并可选择提供重试操作。
final class ViewError<T> extends ViewState<T> {
  const ViewError({required this.error, this.retry});

  final Object error;
  final void Function()? retry;
}
