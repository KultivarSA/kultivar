import 'package:flutter/foundation.dart';

/// Holds the last-used Search query + filter so the user returns to where
/// they left off when re-opening the Search tab.
///
/// Previously these lived as `static` fields on `_SearchScreenState`, which
/// (a) was a class-private detail that the rest of the app could never
/// reset, and (b) would persist across user/account changes if auth is
/// added later.  Wrapping them in a Provider-scoped service makes the
/// lifetime explicit: it's cleared whenever the app's data is cleared
/// (see `GrowRepository.clearAllData`), and would be re-instantiated per
/// account if a profile-scoped Provider tree is introduced.
class SearchStateService extends ChangeNotifier {
  String _query = '';
  String _filter = 'all'; // all | plants | notes | strains | spaces

  String get query => _query;
  String get filter => _filter;

  /// Updates the query without notifying listeners.  Search results are
  /// derived from the [TextField]'s onChange, not from listening to this
  /// service — we only need it to remember state across pop/push.  No
  /// rebuild storms when the user types fast.
  void setQuery(String value) {
    _query = value;
  }

  void setFilter(String value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// Reset both fields.  Called by [GrowRepository.clearAllData] so a
  /// "wipe data" or "switch account" leaves no breadcrumbs in Search.
  void reset() {
    _query = '';
    _filter = 'all';
    notifyListeners();
  }
}
