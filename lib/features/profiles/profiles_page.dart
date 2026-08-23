import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/profile.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/profiles_provider.dart';
import '../../core/utils/byte_formatter.dart';
import '../../shared/widgets/double_bezel_card.dart';

class ProfilesPage extends ConsumerStatefulWidget {
  const ProfilesPage({super.key});

  @override
  ConsumerState<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends ConsumerState<ProfilesPage> {
  @override
  Widget build(BuildContext context) {
    final profilesState = ref.watch(profilesProvider);
    final coreState = ref.watch(coreProvider);
    final profiles = profilesState.profiles;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & "Add Profile" button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SUBSCRIPTIONS & PROFILES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage remote subscription sources and local sing-box JSON schemas',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddProfileDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Profile'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Profiles List
          Expanded(
            child: profiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 64, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No Profiles Configured',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Import a subscription link or local config to begin routing',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddProfileDialog(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Import Subscription'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      final isActive = profile.id == profilesState.activeProfileId;

                      return _buildProfileCard(
                        context,
                        profile: profile,
                        isActive: isActive,
                        onSelect: () async {
                          await ref.read(profilesProvider.notifier).setActiveProfile(profile.id);
                          if (coreState.isRunning) {
                            ref.read(coreProvider.notifier).restartCore();
                          }
                        },
                        onRefresh: () async {
                          await ref.read(profilesProvider.notifier).refreshProfile(profile.id);
                          if (isActive && coreState.isRunning) {
                            ref.read(coreProvider.notifier).restartCore();
                          }
                        },
                        onEdit: () => _showEditProfileDialog(context, profile),
                        onDelete: () => _confirmDeleteProfile(context, profile),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required Profile profile,
    required bool isActive,
    required VoidCallback onSelect,
    required VoidCallback onRefresh,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    // Calculate traffic percentage if provided
    double? trafficPercent;
    if (profile.totalTraffic != null && profile.totalTraffic! > 0) {
      final used = (profile.uploadTraffic ?? 0) + (profile.downloadTraffic ?? 0);
      trafficPercent = (used / profile.totalTraffic!).clamp(0.0, 1.0);
    }

    return DoubleBezelCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      isSelected: isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon, Name, Type, Active Badge & Action Buttons
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  profile.type == ProfileType.remote
                      ? Icons.cloud_sync_rounded
                      : Icons.description_outlined,
                  color: isActive ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isActive ? const Color(0xFF818CF8) : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.url ?? profile.filePath ?? 'Manual Raw Configuration',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action Toolbar
              Row(
                children: [
                  if (profile.type == ProfileType.remote)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Update Subscription',
                      onPressed: onRefresh,
                    ),
                  IconButton(
                    icon: const Icon(Icons.code_rounded, size: 20),
                    tooltip: 'Edit Config',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    tooltip: 'Delete',
                    hoverColor: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                    onPressed: onDelete,
                  ),
                  const SizedBox(width: 8),
                  if (!isActive)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        backgroundColor: const Color(0xFF151E33),
                        foregroundColor: const Color(0xFFE2E8F0),
                      ),
                      onPressed: onSelect,
                      child: const Text('Use', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),

          // Traffic progress bar (if quota available)
          if (trafficPercent != null) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TRAFFIC USAGE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '${ByteFormatter.formatBytes((profile.uploadTraffic ?? 0) + (profile.downloadTraffic ?? 0))} / ${ByteFormatter.formatBytes(profile.totalTraffic!)} (${(trafficPercent * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: trafficPercent,
                    minHeight: 5,
                    backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      trafficPercent > 0.85 ? const Color(0xFFF43F5E) : const Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          const SizedBox(height: 12),

          // Metadata footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildMetaChip(Icons.hub_rounded, '${profile.nodeCount} nodes'),
                  const SizedBox(width: 16),
                  _buildMetaChip(Icons.access_time_rounded, 'Updated: ${ByteFormatter.formatDate(profile.updatedAt)}'),
                ],
              ),
              if (profile.expireDate != null)
                _buildMetaChip(
                  Icons.event_outlined,
                  'Expires: ${ByteFormatter.formatDate(profile.expireDate)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ],
    );
  }

  void _showAddProfileDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final rawCtrl = TextEditingController();
    int tabIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Profile / Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Remote URL')),
                      ButtonSegment(value: 1, label: Text('Raw Config / URI')),
                    ],
                    selected: {tabIndex},
                    onSelectionChanged: (set) {
                      setDialogState(() => tabIndex = set.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Profile Alias', hintText: 'e.g. My Provider'),
                  ),
                  const SizedBox(height: 16),
                  if (tabIndex == 0)
                    TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subscription URL',
                        hintText: 'https://...',
                      ),
                    )
                  else
                    TextField(
                      controller: rawCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Configuration Payload',
                        hintText: 'Paste sing-box JSON, Clash YAML, or Shadowsocks/Vmess/Vless/Trojan/Hy2 URLs',
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (tabIndex == 0) {
                    final url = urlCtrl.text.trim();
                    if (url.isNotEmpty) {
                      Navigator.pop(ctx);
                      final success = await ref.read(profilesProvider.notifier).addProfileFromUrl(name: name, url: url);
                      if (context.mounted && !success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to download subscription URL')),
                        );
                      }
                    }
                  } else {
                    final raw = rawCtrl.text.trim();
                    if (raw.isNotEmpty) {
                      Navigator.pop(ctx);
                      await ref.read(profilesProvider.notifier).addProfileFromRawText(name: name, rawContent: raw);
                    }
                  }
                },
                child: const Text('Import'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, Profile profile) {
    final ctrl = TextEditingController(text: profile.rawConfig);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Profile: ${profile.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 720,
          height: 480,
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(14),
              hintText: 'Configuration content...',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profilesProvider.notifier).updateProfileContent(profile.id, ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProfile(BuildContext context, Profile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete "${profile.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () async {
              await ref.read(profilesProvider.notifier).deleteProfile(profile.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
