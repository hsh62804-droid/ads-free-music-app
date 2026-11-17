import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/home_screen.dart';
import '../../player/player_controller.dart';
import '../library_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isRescanning = false;
  String? _rescanResult;

  Future<void> _handleRescan() async {
    setState(() {
      _isRescanning = true;
      _rescanResult = null;
    });

    final repo = ref.read(musicRepositoryProvider);
    final res = await repo.rescanLibrary();

    if (mounted) {
      setState(() {
        _isRescanning = false;
        _rescanResult = res['message'] ?? 'Rescan complete.';
      });

      // Refresh home and local library
      refreshAllHomeSections(ref);
      ref.invalidate(localSongsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_rescanResult!),
          backgroundColor: AppTheme.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = ref.watch(selectedLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Section: Music Language Preference
          const Text(
            'MUSIC LANGUAGE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  activeColor: AppTheme.primaryRed,
                  title: const Text('Both (Tamil & English)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Display trending and indie songs from both languages', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  value: 'both',
                  groupValue: currentLanguage,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(selectedLanguageProvider.notifier).state = val;
                      refreshAllHomeSections(ref);
                    }
                  },
                ),
                const Divider(color: AppTheme.dividerColor, height: 1),
                RadioListTile<String>(
                  activeColor: AppTheme.primaryRed,
                  title: const Text('Tamil Only', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Kollywood hits, Anirudh, Rahman, Sid Sriram, Tamil indie', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  value: 'tamil',
                  groupValue: currentLanguage,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(selectedLanguageProvider.notifier).state = val;
                      refreshAllHomeSections(ref);
                    }
                  },
                ),
                const Divider(color: AppTheme.dividerColor, height: 1),
                RadioListTile<String>(
                  activeColor: AppTheme.primaryRed,
                  title: const Text('English Only', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Global hits, The Weeknd, Dua Lipa, Taylor Swift, pop & indie', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  value: 'english',
                  groupValue: currentLanguage,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(selectedLanguageProvider.notifier).state = val;
                      refreshAllHomeSections(ref);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: My Music Folder & Rescan
          const Text(
            'LOCAL MUSIC FOLDER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_special_rounded, color: AppTheme.primaryRed, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('backend/music/', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Supported: MP3, M4A, FLAC, OGG, OPUS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Place your full Tamil and English song files inside backend/music/. When a chart song matches a local file, the app automatically plays your full file!',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isRescanning ? null : _handleRescan,
                    icon: _isRescanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _isRescanning ? 'Scanning backend/music/ ...' : 'Rescan my music',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_rescanResult != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _rescanResult!,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Playback Priority Order
          const Text(
            'PLAYBACK SOURCE PRIORITY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
            ),
            child: const Column(
              children: [
                _PriorityRow(
                  rank: '1',
                  sourceName: 'LocalSource (backend/music/)',
                  badgeText: 'FULL TRACK',
                  badgeColor: Colors.greenAccent,
                  desc: 'Plays your own high-fidelity local files with HTTP Range seek support.',
                ),
                Divider(color: AppTheme.dividerColor, height: 20),
                _PriorityRow(
                  rank: '2',
                  sourceName: 'Audius',
                  badgeText: 'FULL TRACK',
                  badgeColor: Colors.greenAccent,
                  desc: 'Decentralized legal full streams with tag search (tamil, kollywood, pop, lofi).',
                ),
                Divider(color: AppTheme.dividerColor, height: 20),
                _PriorityRow(
                  rank: '3',
                  sourceName: 'Jamendo',
                  badgeText: 'FULL TRACK',
                  badgeColor: Colors.greenAccent,
                  desc: 'Creative Commons full-length music catalog with indie tagging.',
                ),
                Divider(color: AppTheme.dividerColor, height: 20),
                _PriorityRow(
                  rank: '4',
                  sourceName: 'Deezer / iTunes',
                  badgeText: '30s PREVIEW ONLY',
                  badgeColor: Colors.amberAccent,
                  desc: 'Preview fallback if no full source exists. Clearly labeled with PREVIEW badge.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final String rank;
  final String sourceName;
  final String badgeText;
  final Color badgeColor;
  final String desc;

  const _PriorityRow({
    required this.rank,
    required this.sourceName,
    required this.badgeText,
    required this.badgeColor,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            rank,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sourceName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 0.6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
