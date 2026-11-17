import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scale_button.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../data/models/song_model.dart';
import '../player/player_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedSource = 'all';
  List<SongModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }
    // Skip single-char queries — not useful and causes excessive API calls
    if (query.trim().length < 2) return;

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final repo = ref.read(musicRepositoryProvider);
    final songs = await repo.search(
      query: query,
      source: _selectedSource,
      limit: 30,
    );

    if (mounted) {
      setState(() {
        _results = songs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(playerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'What do you want to listen to?',
                hintStyle: const TextStyle(color: Color(0xFF757575), fontWeight: FontWeight.normal),
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.black),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Source Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ['all', 'deezer', 'itunes', 'local', 'audius', 'jamendo'].map((source) {
                final isSelected = _selectedSource == source;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      source == 'all' ? 'All Sources' : source.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryRed,
                    backgroundColor: AppTheme.surfaceElevated,
                    onSelected: (val) {
                      setState(() => _selectedSource = source);
                      if (_searchController.text.isNotEmpty) {
                        _executeSearch(_searchController.text);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Results Section
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: 6,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ShimmerBox(width: 48, height: 48, borderRadius: 4),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShimmerBox(width: 180, height: 14, borderRadius: 3),
                                SizedBox(height: 6),
                                ShimmerBox(width: 110, height: 11, borderRadius: 3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _results.isNotEmpty
                    ? ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, idx) {
                          final song = _results[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: 48,
                                height: 48,
                                color: AppTheme.surfaceDark,
                                child: song.artworkUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: song.artworkUrl!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 96,
                                        memCacheHeight: 96,
                                        fadeInDuration: const Duration(milliseconds: 250),
                                        fadeOutDuration: const Duration(milliseconds: 250),
                                        errorWidget: (_, __, ___) => const Icon(
                                          Icons.music_note,
                                          color: AppTheme.textSecondary,
                                        ),
                                      )
                                    : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                              ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            subtitle: Row(
                              children: [
                                if (!song.isFull || song.isPreview) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade900.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: Colors.amberAccent.withValues(alpha: 0.6),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: const Text(
                                      'PREVIEW',
                                      style: TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade900.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: Colors.greenAccent.withValues(alpha: 0.6),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: const Text(
                                      'FULL',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    '${song.artist} • ${song.source.toUpperCase()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            trailing: ScaleButton(
                              onPressed: () => controller.playSong(song, queue: _results),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.play_circle_fill, color: AppTheme.primaryRed, size: 28),
                              ),
                            ),
                            onTap: () => controller.playSong(song, queue: _results),
                          );
                        },
                      )
                    : _hasSearched
                        ? const Center(
                            child: Text(
                              'No tracks found. Try another query.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, size: 64, color: AppTheme.surfaceElevated),
                                SizedBox(height: 12),
                                Text(
                                  'Search for your favorite songs, artists, or genres',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
