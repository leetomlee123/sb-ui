import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/profile.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/profiles_provider.dart';
import '../../core/utils/byte_formatter.dart';

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
                    'Profiles & Subscriptions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your remote subscriptions and local sing-box configs',
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
                        Icon(Icons.folder_open_rounded, size: 64, color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No Profiles Found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add a remote subscription URL or import a config file to get started',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddProfileDialog(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Your First Profile'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive ? const Color(0xFF6366F1) : Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Name, Type Badge, Active indicator & Actions
            Row(
              children: [
                Icon(
                  profile.type == ProfileType.remote
                      ? Icons.cloud_queue_rounded
                      : Icons.description_outlined,
                  color: isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                  size: 24,
                ),
                const SizedBox(width: 12),
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
                                fontSize: 16,
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
                                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF818CF8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.url ?? profile.filePath ?? 'Manual Raw JSON/YAML',
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
                // Actions
                if (profile.type == ProfileType.remote)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Update Subscription',
                    onPressed: onRefresh,
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 22),
                  tooltip: 'Edit Config',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: 'Delete',
                  hoverColor: Colors.red.withValues(alpha: 0.15),
                  onPressed: onDelete,
                ),
                const SizedBox(width: 8),
                if (!isActive)
                  OutlinedButton(
                    onPressed: onSelect,
                    child: const Text('Use', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Metadata footer (Nodes count, Traffic, Expire, Updated at)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildMetaChip(Icons.device_hub_rounded, '${profile.nodeCount} nodes'),
                    const SizedBox(width: 16),
                    _buildMetaChip(Icons.access_time_rounded, 'Updated: ${ByteFormatter.formatDate(profile.updatedAt)}'),
                  ],
                ),
                if (profile.totalTraffic != null)
                  _buildMetaChip(
                    Icons.data_usage_rounded,
                    '${ByteFormatter.formatBytes((profile.uploadTraffic ?? 0) + (profile.downloadTraffic ?? 0))} / ${ByteFormatter.formatBytes(profile.totalTraffic!)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
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
            title: const Text('Add Profile'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Subscription URL')),
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
                    decoration: const InputDecoration(labelText: 'Profile Name', hintText: 'e.g. My Proxy Provider'),
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
                        labelText: 'Config Content',
                        hintText: 'Paste sing-box JSON, Clash YAML, or Shadowsocks/Vmess/Vless/Trojan URLs here',
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
        title: Text('Edit Profile: ${profile.name}'),
        content: SizedBox(
          width: 700,
          height: 450,
          child: Column(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(12),
                    hintText: 'Configuration content...',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profilesProvider.notifier).updateProfileContent(profile.id, ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
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
