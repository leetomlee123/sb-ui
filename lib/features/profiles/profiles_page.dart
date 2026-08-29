import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/engine/default_config_template.dart';
import '../../core/engine/profile_parser.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/profile.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/profiles_provider.dart';
import '../../core/utils/byte_formatter.dart';
import '../../core/utils/native_file_dialog.dart';
import '../../shared/widgets/double_bezel_card.dart';
import 'widgets/config_editor_dialog.dart';
import 'widgets/manual_node_form_dialog.dart';

class ProfilesPage extends ConsumerStatefulWidget {
  const ProfilesPage({super.key});

  @override
  ConsumerState<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends ConsumerState<ProfilesPage> with WidgetsBindingObserver {
  String? _detectedClipboardContent;
  bool _dismissedClipboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  void _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && !_dismissedClipboard) {
        final isUrl = text.startsWith('http://') || text.startsWith('https://');
        final isNodeUri = text.startsWith('vmess://') ||
            text.startsWith('vless://') ||
            text.startsWith('hy2://') ||
            text.startsWith('hysteria2://') ||
            text.startsWith('ss://') ||
            text.startsWith('trojan://') ||
            text.startsWith('tuic://') ||
            text.startsWith('wireguard://') ||
            text.startsWith('clash://');
        final isJsonOrYaml = text.startsWith('{') || text.startsWith('proxies:') || text.startsWith('outbounds:');

        if (isUrl || isNodeUri || isJsonOrYaml) {
          final existing = ref.read(profilesProvider).profiles.any((p) => p.url == text || p.rawConfig.trim() == text);
          if (!existing && mounted && _detectedClipboardContent != text) {
            setState(() {
              _detectedClipboardContent = text;
            });
          }
        }
      }
    } catch (_) {}
  }

  void _showManualNodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const ManualNodeFormDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profilesState = ref.watch(profilesProvider);
    final coreIsRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final tr = ref.watch(translationsProvider);
    final profiles = profilesState.profiles;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Action buttons
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
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      final activeProfile = profilesState.activeProfile;
                      if (activeProfile != null) {
                        showDialog(
                          context: context,
                          builder: (ctx) => ConfigEditorDialog(profile: activeProfile),
                        );
                      } else {
                        showDialog(
                          context: context,
                          builder: (ctx) => ConfigEditorDialog(
                            title: tr.isZh ? '本地主配置 (config.json)' : 'Local config.json',
                            initialContent: DefaultConfigTemplate.getStandardConfigJson(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: Text(tr.isZh ? '编辑 config.json' : 'Edit config.json'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showManualNodeDialog(context),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(tr.tabManualForm),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProfileDialog(context, tr),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(tr.addProfile),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Clipboard Detected One-Click Import Banner
          if (_detectedClipboardContent != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.content_paste_go_rounded, size: 18, color: Color(0xFF818CF8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.isZh ? '检测到剪贴板中的订阅/节点链接' : 'Detected configuration in clipboard',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _detectedClipboardContent!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dismissedClipboard = true;
                        _detectedClipboardContent = null;
                      });
                    },
                    child: Text(tr.cancel, style: const TextStyle(fontSize: 11)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final content = _detectedClipboardContent!;
                      setState(() {
                        _dismissedClipboard = true;
                        _detectedClipboardContent = null;
                      });
                      _showAddProfileDialog(context, tr, initialContent: content);
                    },
                    icon: const Icon(Icons.file_download_rounded, size: 14),
                    label: Text(tr.isZh ? '一键导入' : 'Import Now', style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),

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
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showAddProfileDialog(context, tr, initialTab: 0),
                              icon: const Icon(Icons.link_rounded, size: 16),
                              label: Text(tr.importSubscription),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showAddProfileDialog(context, tr, initialTab: 1),
                              icon: const Icon(Icons.file_present_rounded, size: 16),
                              label: Text(tr.importLocalConfig),
                            ),
                          ],
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
                          if (coreIsRunning) {
                            ref.read(coreProvider.notifier).restartCore();
                          }
                        },
                        onRefresh: () async {
                          await ref.read(profilesProvider.notifier).refreshProfile(profile.id);
                          if (isActive && coreIsRunning) {
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
                      : (profile.type == ProfileType.local
                          ? Icons.file_present_rounded
                          : Icons.description_outlined),
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
                        if (profile.type == ProfileType.local) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder_shared_rounded, size: 10, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 3),
                                Text(
                                  tr.localFileBadge,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
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
                    InkWell(
                      onTap: () {
                        final content = profile.url ?? profile.rawConfig;
                        if (content.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(profile.url != null ? tr.copiedSubSuccess : tr.copiedSubSuccess)),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.url ?? profile.filePath ?? (tr.isZh ? '手动本地配置' : 'Manual Raw Configuration'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Toolbar
              Row(
                children: [
                  if (profile.type == ProfileType.remote ||
                      (profile.type == ProfileType.local && profile.filePath != null))
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: profile.type == ProfileType.remote ? tr.updateSub : tr.reloadFromFile,
                      onPressed: onRefresh,
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 19),
                    tooltip: profile.type == ProfileType.remote ? tr.copySubUrl : tr.copyConfigPayload,
                    onPressed: () {
                      final content = profile.url ?? profile.rawConfig;
                      if (content.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(profile.url != null ? tr.copiedSubSuccess : tr.copiedSubSuccess)),
                        );
                      }
                    },
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

  void _showAddProfileDialog(
    BuildContext context,
    Translations tr, {
    String? initialContent,
    int initialTab = 0,
  }) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final rawCtrl = TextEditingController();
    final filePathCtrl = TextEditingController();

    int tabIndex = initialTab;
    bool syncLocalFile = true;
    bool localFileExists = false;
    String localFileStats = '';
    String localFilePreview = '';

    void inspectLocalFile(String path, void Function(void Function()) setDialogState) {
      final trimmed = path.trim();
      if (trimmed.isEmpty) {
        setDialogState(() {
          localFileExists = false;
          localFileStats = '';
          localFilePreview = '';
        });
        return;
      }

      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final sizeKb = (content.length / 1024).toStringAsFixed(1);
          final parseResult = ProfileParser.parse(content);
          final lines = content.split('\n');
          final previewLines = lines.take(6).join('\n');

          setDialogState(() {
            localFileExists = true;
            localFileStats = '$sizeKb KB | 解析出 ${parseResult.count} 个节点 (${parseResult.format})';
            localFilePreview = previewLines;
            if (nameCtrl.text.trim().isEmpty) {
              nameCtrl.text = p.basename(file.path);
            }
          });
        } else {
          setDialogState(() {
            localFileExists = false;
            localFileStats = tr.fileNotFound;
            localFilePreview = '';
          });
        }
      } catch (e) {
        setDialogState(() {
          localFileExists = false;
          localFileStats = '读取失败: $e';
          localFilePreview = '';
        });
      }
    }

    if (initialContent != null && initialContent.isNotEmpty) {
      final isUrl = initialContent.startsWith('http://') || initialContent.startsWith('https://');
      if (isUrl) {
        tabIndex = 0;
        urlCtrl.text = initialContent;
        nameCtrl.text = tr.isZh ? '我的订阅' : 'My Subscription';
      } else {
        tabIndex = 2;
        rawCtrl.text = initialContent;
        nameCtrl.text = tr.isZh ? '导入的配置' : 'Imported Config';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(tr.addProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 580,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.link_rounded, size: 14),
                        label: Text(tr.tabRemoteUrl, style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.file_present_rounded, size: 14),
                        label: Text(tr.tabLocalConfig, style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: const Icon(Icons.description_outlined, size: 14),
                        label: Text(tr.tabRawConfig, style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 3,
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: Text(tr.tabManualForm, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {tabIndex},
                    onSelectionChanged: (set) {
                      if (set.first == 3) {
                        Navigator.pop(ctx);
                        _showManualNodeDialog(context);
                      } else {
                        setDialogState(() => tabIndex = set.first);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Profile Name / Alias
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: tr.profileAlias,
                      hintText: tabIndex == 1
                          ? (tr.isZh ? '例如：本地主配置 (config.json)' : 'e.g. Local config.json')
                          : (tr.isZh ? '例如：我的订阅服务' : 'e.g. My Provider'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tab 0: Remote URL
                  if (tabIndex == 0) ...[
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: tr.subUrl,
                        hintText: 'https://...',
                      ),
                    ),
                  ],

                  // Tab 1: Local config.json
                  if (tabIndex == 1) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: filePathCtrl,
                            decoration: InputDecoration(
                              labelText: tr.localConfigPath,
                              hintText: tr.isZh ? '例如：C:\\path\\to\\config.json' : 'e.g. /path/to/config.json',
                            ),
                            onChanged: (path) => inspectLocalFile(path, setDialogState),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final pickedPath = await NativeFileDialog.pickConfigFile();
                            if (pickedPath != null && pickedPath.isNotEmpty) {
                              filePathCtrl.text = pickedPath;
                              inspectLocalFile(pickedPath, setDialogState);
                            }
                          },
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: Text(tr.browseFile),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Quick load template action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final file = await DefaultConfigTemplate.createLocalConfigFile();
                              filePathCtrl.text = file.path;
                              inspectLocalFile(file.path, setDialogState);
                              if (nameCtrl.text.trim().isEmpty) {
                                nameCtrl.text = tr.isZh ? '本地 config.json' : 'Local config.json';
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('创建模板失败: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                          label: Text(tr.loadTemplate, style: const TextStyle(fontSize: 12)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: syncLocalFile,
                              activeColor: const Color(0xFF6366F1),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) => setDialogState(() => syncLocalFile = v ?? true),
                            ),
                            Text(
                              tr.syncWithLocalFile,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // File inspection summary & preview
                    if (filePathCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: localFileExists
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : const Color(0xFFF43F5E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: localFileExists
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : const Color(0xFFF43F5E).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  localFileExists ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                                  size: 16,
                                  color: localFileExists ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    localFileStats,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: localFileExists ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (localFilePreview.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF080C16),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF1E293B)),
                                ),
                                child: Text(
                                  '$localFilePreview\n...',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],

                  // Tab 2: Raw Text / URI
                  if (tabIndex == 2) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            showDialog(
                              context: context,
                              builder: (editorCtx) => ConfigEditorDialog(
                                title: nameCtrl.text.trim().isNotEmpty
                                    ? nameCtrl.text.trim()
                                    : (tr.isZh ? '新建本地配置 (config.json)' : 'New config.json'),
                                initialContent: rawCtrl.text.isNotEmpty
                                    ? rawCtrl.text
                                    : DefaultConfigTemplate.getStandardConfigJson(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: Text(tr.isZh ? '打开高级编辑器' : 'Open in Code Editor', style: const TextStyle(fontSize: 11)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            try {
                              final decoded = jsonDecode(rawCtrl.text);
                              rawCtrl.text = const JsonEncoder.withIndent('  ').convert(decoded);
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.format_indent_increase_rounded, size: 14),
                          label: Text(tr.formatJson, style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF080C16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: TextField(
                        controller: rawCtrl,
                        maxLines: 7,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFFF8FAFC),
                        ),
                        cursorColor: const Color(0xFF818CF8),
                        decoration: InputDecoration(
                          hintText: tr.configPayloadHint,
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
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
                  } else if (tabIndex == 1) {
                    final filePath = filePathCtrl.text.trim();
                    if (filePath.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr.fileNotFound)),
                      );
                      return;
                    }
                    final file = File(filePath);
                    if (!file.existsSync()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr.fileNotFound)),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    if (syncLocalFile) {
                      await ref.read(profilesProvider.notifier).addProfileFromLocalFile(
                            name: name.isEmpty ? p.basename(filePath) : name,
                            filePath: filePath,
                          );
                    } else {
                      final content = await file.readAsString();
                      await ref.read(profilesProvider.notifier).addProfileFromRawText(
                            name: name.isEmpty ? p.basename(filePath) : name,
                            rawContent: content,
                          );
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfigEditorDialog(profile: profile),
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
