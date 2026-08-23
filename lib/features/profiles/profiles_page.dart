import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
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
    final tr = ref.watch(translationsProvider);
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
                  Text(
                    tr.subAndProfiles,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr.subDesc,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddProfileDialog(context, tr),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(tr.addProfile),
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
                        Text(
                          tr.noProfilesTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr.noProfilesHint,
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddProfileDialog(context, tr),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(tr.importSubscription),
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
                        tr: tr,
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
                        onEdit: () => _showEditProfileDialog(context, profile, tr),
                        onDelete: () => _confirmDeleteProfile(context, profile, tr),
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
    required Translations tr,
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  tr.activeBadge,
                                  style: const TextStyle(
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
                      profile.url ?? profile.filePath ?? (tr.isZh ? '手动本地配置' : 'Manual Raw Configuration'),
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
                      tooltip: tr.updateSub,
                      onPressed: onRefresh,
                    ),
                  IconButton(
                    icon: const Icon(Icons.code_rounded, size: 20),
                    tooltip: tr.editConfig,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    tooltip: tr.deleteProfile,
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
                      child: Text(tr.useProfile, style: const TextStyle(fontSize: 12)),
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
                      tr.trafficUsage,
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
                  _buildMetaChip(Icons.hub_rounded, '${profile.nodeCount} ${tr.nodesCount}'),
                  const SizedBox(width: 16),
                  _buildMetaChip(Icons.access_time_rounded, '${tr.updatedPrefix}${ByteFormatter.formatDate(profile.updatedAt)}'),
                ],
              ),
              if (profile.expireDate != null)
                _buildMetaChip(
                  Icons.event_outlined,
                  '${tr.expiresPrefix}${ByteFormatter.formatDate(profile.expireDate)}',
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

  void _showAddProfileDialog(BuildContext context, Translations tr) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final rawCtrl = TextEditingController();
    int tabIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(tr.addProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(tr.tabRemoteUrl)),
                      ButtonSegment(value: 1, label: Text(tr.tabRawConfig)),
                    ],
                    selected: {tabIndex},
                    onSelectionChanged: (set) {
                      setDialogState(() => tabIndex = set.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: tr.profileAlias, hintText: tr.isZh ? '例如：我的订阅服务' : 'e.g. My Provider'),
                  ),
                  const SizedBox(height: 16),
                  if (tabIndex == 0)
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: tr.subUrl,
                        hintText: 'https://...',
                      ),
                    )
                  else
                    TextField(
                      controller: rawCtrl,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: tr.configPayload,
                        hintText: tr.configPayloadHint,
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.cancel)),
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
                          SnackBar(content: Text(tr.downloadSubFailed)),
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
                child: Text(tr.importSubscription),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, Profile profile, Translations tr) {
    final ctrl = TextEditingController(text: profile.rawConfig);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${tr.editConfig}: ${profile.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.cancel)),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profilesProvider.notifier).updateProfileContent(profile.id, ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(tr.saveChanges),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProfile(BuildContext context, Profile profile, Translations tr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.deleteProfile),
        content: Text('${tr.confirmDelete} ("${profile.name}")'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () async {
              await ref.read(profilesProvider.notifier).deleteProfile(profile.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(tr.delete),
          ),
        ],
      ),
    );
  }
}
