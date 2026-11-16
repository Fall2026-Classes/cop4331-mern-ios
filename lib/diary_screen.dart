import 'package:flutter/material.dart';

import 'api.dart';
import 'auth_screens.dart';
import 'catalog.dart';
import 'widgets.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDay(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

final Map<String, (String, int Function(Entry, Entry))> _sorts = {
  'recent': ('Recently added', (a, b) => b.createdAt.compareTo(a.createdAt)),
  'ratingHigh': ('Highest rated', (a, b) => b.rating.compareTo(a.rating)),
  'ratingLow': (
    'Lowest rated',
    (a, b) => (a.rating == 0 ? 99.0 : a.rating).compareTo(b.rating == 0 ? 99.0 : b.rating)
  ),
  'title': ('Title A-Z', (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
  'yearNew': ('Release year (newest)', (a, b) => (b.year ?? 0).compareTo(a.year ?? 0)),
};

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<Entry> _entries = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  String _search = '';
  String _sort = 'recent';

  @override
  void initState() {
    super.initState();
    _load();
    Catalog.load().then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
  }

  Future<void> _load() async {
    try {
      final list = await Api.listReviews();
      if (!mounted) return;
      setState(() {
        _entries = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      _handleError(e);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await Api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _handleError(Object e) {
    if (e is ApiException && e.status == 401) {
      _logout();
      return;
    }
    if (mounted) setState(() => _error = '$e');
  }

  Future<void> _openForm([Entry? entry]) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => EntryFormScreen(entry: entry)),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result is Entry) {
        final i = _entries.indexWhere((x) => x.id == result.id);
        if (i >= 0) {
          _entries[i] = result;
        } else {
          _entries.insert(0, result);
        }
      } else if (result is String) {
        _entries.removeWhere((x) => x.id == result); // deleted
      } else if (result is ApiException && result.status == 401) {
        _logout();
      }
    });
  }

  Future<void> _delete(Entry e) async {
    final ok = await confirmDelete(context, e.title);
    if (!ok) return;
    try {
      await Api.deleteReview(e.id!);
      if (mounted) setState(() => _entries.removeWhere((x) => x.id == e.id));
    } catch (err) {
      _handleError(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final shown = _entries
        .where((e) => _filter == 'all' || e.type == _filter)
        .where((e) => q.isEmpty || e.title.toLowerCase().contains(q) || e.review.toLowerCase().contains(q))
        .toList()
      ..sort(_sorts[_sort]!.$2);
    final rated = _entries.where((e) => e.rating > 0).toList();
    final avg = rated.isEmpty ? '-' : (rated.fold<double>(0, (s, e) => s + e.rating) / rated.length).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Brand(),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) => v == 'logout' ? _logout() : null,
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(Api.displayName)),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Log'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          children: [
            Row(children: [
              _Stat('${_entries.length}', 'Logged'),
              _Stat('${_entries.where((e) => e.type == 'movie').length}', 'Movies'),
              _Stat('${_entries.where((e) => e.type == 'show').length}', 'Shows'),
              _Stat(avg, 'Avg rating'),
            ]),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: kDanger)),
              ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'movie', label: Text('Movies')),
                ButtonSegment(value: 'show', label: Text('Shows')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search titles and reviews',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Sort by',
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => [
                  for (final s in _sorts.entries) PopupMenuItem(value: s.key, child: Text(s.value.$1)),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (_entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Column(children: [
                  Text('Your diary is empty.', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Log the last thing you watched to get started.', style: TextStyle(color: kMuted)),
                ]),
              )
            else if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nothing matches that filter.', style: TextStyle(color: kMuted)),
              )
            else
              for (final e in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EntryCard(entry: e, onEdit: () => _openForm(e), onDelete: () => _delete(e)),
                ),
            const SizedBox(height: 10),
            const Text(
              'Posters and title data from TMDB. This product uses the TMDB API but is not endorsed or certified by TMDB.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onEdit, required this.onDelete});
  final Entry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: kBorder)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Poster(title: e.title, type: e.type, url: Catalog.findPoster(e.title, e.type, e.year)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (e.year != null) ...[
                        Text('${e.year}', style: const TextStyle(color: kMuted)),
                        const SizedBox(width: 8),
                      ],
                      TypeBadge(e.type),
                    ]),
                    const SizedBox(height: 6),
                    e.rating > 0
                        ? StarRating(value: e.rating, size: 18)
                        : const Text('Not rated', style: TextStyle(color: kMuted, fontSize: 12)),
                    if (e.review.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(e.review, maxLines: 4, overflow: TextOverflow.ellipsis),
                    ],
                    if (e.watchedOn != null) ...[
                      const SizedBox(height: 4),
                      Text('Watched ${formatDay(e.watchedOn!)}', style: const TextStyle(color: kMuted, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: kDanger),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context, String title) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete entry'),
          content: Text('Remove "$title" from your diary?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: kDanger)),
            ),
          ],
        ),
      ) ??
      false;
}

/// Add or edit a diary entry. Pops with the saved [Entry], the deleted entry's id,
/// or an [ApiException] when the session expired.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key, this.entry});
  final Entry? entry;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _form = GlobalKey<FormState>();
  late String _type = widget.entry?.type ?? 'movie';
  late final _title = TextEditingController(text: widget.entry?.title ?? '');
  late final _year = TextEditingController(text: widget.entry?.year?.toString() ?? '');
  late final _review = TextEditingController(text: widget.entry?.review ?? '');
  late double _rating = widget.entry?.rating ?? 0;
  late DateTime? _watchedOn = widget.entry?.watchedOn;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.entry?.id != null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final entry = Entry(
      id: widget.entry?.id,
      title: _title.text,
      type: _type,
      year: int.tryParse(_year.text.trim()),
      rating: _rating,
      review: _review.text,
      watchedOn: _watchedOn,
    );
    try {
      final saved = _editing ? await Api.updateReview(entry) : await Api.createReview(entry);
      if (mounted) Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        Navigator.pop(context, e);
        return;
      }
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _delete() async {
    final e = widget.entry!;
    if (!await confirmDelete(context, e.title)) return;
    try {
      await Api.deleteReview(e.id!);
      if (mounted) Navigator.pop(context, e.id);
    } on ApiException catch (err) {
      if (mounted) showError(context, err);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _watchedOn == null
        ? now
        : DateTime(_watchedOn!.year, _watchedOn!.month, _watchedOn!.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _watchedOn = DateTime.utc(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit entry' : 'Log a movie or show'),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, color: kDanger), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: kDanger)),
              ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'movie', label: Text('Movie')),
                ButtonSegment(value: 'show', label: Text('TV show')),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 14),
            _TitleField(
              controller: _title,
              type: _type,
              onPick: (t) => setState(() {
                _title.text = t.title;
                _type = t.type;
                _year.text = t.year?.toString() ?? '';
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _year,
              decoration: const InputDecoration(labelText: 'Year', hintText: '2001'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final n = int.tryParse(s);
                return n == null || n < 1870 || n > 2100 ? 'Year looks wrong' : null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Your rating', style: TextStyle(color: kMuted)),
            const SizedBox(height: 6),
            Row(children: [
              StarRating(value: _rating, size: 36, onChanged: (v) => setState(() => _rating = v)),
              const SizedBox(width: 10),
              Text(_rating > 0 ? '$_rating / 5' : 'Tap a star (left half = ½)',
                  style: const TextStyle(color: kMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_watchedOn == null ? 'Watched on (optional)' : 'Watched ${formatDay(_watchedOn!)}'),
            ),
            if (_watchedOn != null)
              TextButton(onPressed: () => setState(() => _watchedOn = null), child: const Text('Clear date')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _review,
              decoration: const InputDecoration(labelText: 'Review', hintText: 'What did you think?', alignLabelWithHint: true),
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Write a short review' : null,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_busy ? 'Saving...' : (_editing ? 'Save changes' : 'Add to diary')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title box that suggests matching titles from the catalog.
class _TitleField extends StatefulWidget {
  const _TitleField({required this.controller, required this.type, required this.onPick});
  final TextEditingController controller;
  final String type;
  final ValueChanged<CatalogTitle> onPick;

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<CatalogTitle>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (t) => t.title,
      optionsBuilder: (v) => v.text.trim().length < 2 ? const [] : Catalog.search(v.text, preferType: widget.type),
      onSelected: widget.onPick,
      fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextFormField(
        controller: ctrl,
        focusNode: focus,
        decoration: const InputDecoration(labelText: 'Title', hintText: 'Start typing, e.g. Spirited Away'),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: kSurface2,
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 320, maxWidth: MediaQuery.of(context).size.width - 32),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final t in options)
                  ListTile(
                    dense: true,
                    leading: Poster(title: t.title, type: t.type, url: t.posterUrl, width: 28),
                    title: Text(t.title),
                    subtitle: Text('${t.year ?? ''} · ${t.type == 'show' ? 'TV' : 'Movie'} · #${t.rank}'),
                    onTap: () => onSelected(t),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
