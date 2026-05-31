enum TimeWindow {
  all,
  last30,
  last60,
  last90,
}

extension TimeWindowX on TimeWindow {
  String get label {
    switch (this) {
      case TimeWindow.all:
        return 'All';
      case TimeWindow.last30:
        return '30d';
      case TimeWindow.last60:
        return '60d';
      case TimeWindow.last90:
        return '90d';
    }
  }

  int? get days {
    switch (this) {
      case TimeWindow.all:
        return null;
      case TimeWindow.last30:
        return 30;
      case TimeWindow.last60:
        return 60;
      case TimeWindow.last90:
        return 90;
    }
  }
}
