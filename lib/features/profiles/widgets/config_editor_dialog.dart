import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/engine/default_config_template.dart';
import '../../../core/engine/profile_parser.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/models/profile.dart';
import '../../../core/providers/profiles_provider.dart';
import 'visual_config_editor.dart';

/// Lightweight syntax highlighting controller for sing-box JSON and YAML configs.
class JsonCodeSyntaxController extends TextEditingController {
  JsonCodeSyntaxController({super.text});

  static final RegExp _tokenizer = RegExp(
    r'(?<key>"[^"\\]*(?:\\.[^"\\]*)*")\s*(?=:)|'
    r'(?<string>"[^"\\]*(?:\\.[^"\\]*)*")|'
    r'(?<number>-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)|'
    r'(?<keyword>\b(?:true|false|null)\b)|'
    r'(?<comment>\/\/[^\r\n]*|\/\*[\s\S]*?\*\/)',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final punctuationColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final keyColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final stringColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final numberColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final keywordColor = isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED);
    final commentColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final baseStyle = style ??
        TextStyle(
          fontFamily: 'monospace',
          fontSize: 13.0,
          height: 1.5,
          color: defaultTextColor,
        );

    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    // Skip tokenizer on huge payload (>150KB) to ensure instant, non-blocking typing
    if (text.length > 150000) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in _tokenizer.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle.copyWith(color: punctuationColor), // Punctuation & symbols
        ));
      }

      final key = match.namedGroup('key');
      final string = match.namedGroup('string');
      final number = match.namedGroup('number');
      final keyword = match.namedGroup('keyword');
      final comment = match.namedGroup('comment');

      if (key != null) {
        spans.add(TextSpan(
          text: key,
          style: baseStyle.copyWith(
            color: keyColor, // Cyan / Sky blue for keys
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (string != null) {
        spans.add(TextSpan(
          text: string,
          style: baseStyle.copyWith(
            color: stringColor, // Emerald green for string values
          ),
        ));
      } else if (number != null) {
        spans.add(TextSpan(
          text: number,
          style: baseStyle.copyWith(
            color: numberColor, // Amber gold for numbers/ports
          ),
        ));
      } else if (keyword != null) {
        spans.add(TextSpan(
          text: keyword,
          style: baseStyle.copyWith(
            color: keywordColor, // Violet purple for true/false/null
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (comment != null) {
        spans.add(TextSpan(
          text: comment,
          style: baseStyle.copyWith(
            color: commentColor, // Slate muted for comments
            fontStyle: FontStyle.italic,
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle.copyWith(color: punctuationColor),
      ));
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}

class ConfigEditorDialog extends ConsumerStatefulWidget {
  final Profile? profile;
  final String? initialContent;
  final String? title;
  final String? filePath;
  final Future<bool> Function(String content)? onSave;

  const ConfigEditorDialog({
    super.key,
    this.profile,
    this.initialContent,
    this.title,
    this.filePath,
    this.onSave,
  });

  @override
  ConsumerState<ConfigEditorDialog> createState() => _ConfigEditorDialogState();
}

class _ConfigEditorDialogState extends ConsumerState<ConfigEditorDialog> {
  late final JsonCodeSyntaxController _textCtrl;
  late final UndoHistoryController _undoCtrl;
  final ScrollController _scrollCtrl = ScrollController();
  final ScrollController _gutterCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isMaximized = false;
  bool _showSearch = false;
  bool _wordWrap = false;
  late bool _syncToFile;
  bool _isSyncingScroll = false;
  bool _hasUnsavedChanges = false;
  late String _initialContent;

  int _editorMode = 0; // 0: Visual GUI, 1: JSON Code Editor
  Map<String, dynamic>? _parsedVisualMap;

  int _cursorLine = 1;
  int _cursorCol = 1;
  int _lineCount = 1;

  // Search state
  final List<int> _matches = [];
  int _currentMatchIndex = -1;

  // Syntax validation state
  String? _syntaxError;
  int? _syntaxErrorOffset;
  int? _syntaxErrorLine;
  int? _syntaxErrorCol;
  String _detectedFormat = '';
  int _nodeCount = 0;

  static const double _fontSize = 13.0;
  static const double _lineHeightFactor = 1.5;
  static const double _lineHeight = _fontSize * _lineHeightFactor; // ~19.5px

  String? get _effectiveFilePath => widget.filePath ?? widget.profile?.filePath;
  String get _displayTitle => widget.title ?? widget.profile?.name ?? 'config.json';

  @override
  void initState() {
    super.initState();
    _initialContent = widget.profile?.rawConfig ?? widget.initialContent ?? '';
    _textCtrl = JsonCodeSyntaxController(text: _initialContent);
    _undoCtrl = UndoHistoryController();
    _syncToFile = (widget.profile?.type == ProfileType.local && widget.profile?.filePath != null) ||
        widget.filePath != null;

    _textCtrl.addListener(_onTextChanged);
    _scrollCtrl.addListener(_syncScrollGutter);
    _searchCtrl.addListener(_onSearchChanged);

    _validateSyntax(_textCtrl.text);
    _updateCursorAndStats();
    _tryParseVisualMap(_textCtrl.text);
  }

  void _tryParseVisualMap(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{')) {
      try {
        final dynamic decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          _parsedVisualMap = decoded;
          return;
        }
      } catch (_) {}
    }
    _parsedVisualMap = null;
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _scrollCtrl.removeListener(_syncScrollGutter);
    _searchCtrl.removeListener(_onSearchChanged);
    _textCtrl.dispose();
    _undoCtrl.dispose();
    _scrollCtrl.dispose();
    _gutterCtrl.dispose();
    _searchCtrl.dispose();
    _editorFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _syncScrollGutter() {
    if (_isSyncingScroll) return;
    if (_gutterCtrl.hasClients && _gutterCtrl.offset != _scrollCtrl.offset) {
      _isSyncingScroll = true;
      _gutterCtrl.jumpTo(_scrollCtrl.offset);
      _isSyncingScroll = false;
    }
  }

  void _onTextChanged() {
    _updateCursorAndStats();
    _validateSyntax(_textCtrl.text);
    _tryParseVisualMap(_textCtrl.text);
    if (!_hasUnsavedChanges && _textCtrl.text != _initialContent) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
    if (_showSearch && _searchCtrl.text.isNotEmpty) {
      _executeSearch();
    }
  }

  int _longestLineWidth = 1;

  void _updateCursorAndStats() {
    final text = _textCtrl.text;
    final lines = text.split('\n');
    _lineCount = max(1, lines.length);

    int longest = 1;
    for (final line in lines) {
      if (line.length > longest) longest = line.length;
    }
    _longestLineWidth = longest;

    final sel = _textCtrl.selection;
    if (sel.isValid) {
      final offset = sel.baseOffset.clamp(0, text.length);
      final textBefore = text.substring(0, offset);
      final linesBefore = textBefore.split('\n');
      _cursorLine = linesBefore.length;
      _cursorCol = linesBefore.last.length + 1;
    }
    setState(() {});
  }

  void _validateSyntax(String content) {
    if (content.trim().isEmpty) {
      setState(() {
        _syntaxError = null;
        _syntaxErrorOffset = null;
        _syntaxErrorLine = null;
        _syntaxErrorCol = null;
        _detectedFormat = 'Empty';
        _nodeCount = 0;
      });
      return;
    }

    final parseRes = ProfileParser.parse(content);
    if (parseRes.format == 'sing-box') {
      _detectedFormat = 'sing-box JSON';
    } else if (parseRes.format == 'clash') {
      _detectedFormat = 'Clash YAML';
    } else if (parseRes.format == 'uri-list') {
      _detectedFormat = 'URI List';
    } else {
      _detectedFormat = parseRes.format.toUpperCase();
    }
    _nodeCount = parseRes.count;

    // Check JSON syntax if JSON format
    final trimmed = content.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        jsonDecode(content);
        setState(() {
          _syntaxError = null;
          _syntaxErrorOffset = null;
          _syntaxErrorLine = null;
          _syntaxErrorCol = null;
        });
      } on FormatException catch (e) {
        final offset = e.offset ?? 0;
        final textBefore = content.substring(0, min(offset, content.length));
        final lines = textBefore.split('\n');
        final line = lines.length;
        final col = lines.last.length + 1;

        setState(() {
          _syntaxError = e.message;
          _syntaxErrorOffset = offset;
          _syntaxErrorLine = line;
          _syntaxErrorCol = col;
        });
      }
    } else {
      setState(() {
        _syntaxError = null;
        _syntaxErrorOffset = null;
        _syntaxErrorLine = null;
        _syntaxErrorCol = null;
      });
    }
  }

  void _jumpToSyntaxError() {
    if (_syntaxErrorOffset == null) return;
    final offset = _syntaxErrorOffset!.clamp(0, _textCtrl.text.length);
    _textCtrl.selection = TextSelection.collapsed(offset: offset);
    _editorFocusNode.requestFocus();

    // Scroll to error line
    if (_syntaxErrorLine != null && _scrollCtrl.hasClients) {
      final targetScroll = max(0.0, (_syntaxErrorLine! - 4) * _lineHeight);
      _scrollCtrl.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _formatJson() {
    try {
      final decoded = jsonDecode(_textCtrl.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      _textCtrl.text = formatted;
      _validateSyntax(formatted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已美化并格式化 JSON 代码'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('格式化失败，存在语法错误: $e'),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    }
  }

  void _minifyJson() {
    try {
      final decoded = jsonDecode(_textCtrl.text);
      final minified = jsonEncode(decoded);
      _textCtrl.text = minified;
      _validateSyntax(minified);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已压缩 JSON'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('压缩失败，存在语法错误: $e'),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    }
  }

  void _loadStandardTemplate() {
    final template = DefaultConfigTemplate.getStandardConfigJson();
    _textCtrl.text = template;
    _validateSyntax(template);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已载入标准 sing-box config.json 模板'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
    });
    if (_showSearch) {
      _searchFocusNode.requestFocus();
      if (_searchCtrl.text.isNotEmpty) {
        _executeSearch();
      }
    } else {
      _matches.clear();
      _currentMatchIndex = -1;
      _editorFocusNode.requestFocus();
    }
  }

  void _onSearchChanged() {
    _executeSearch();
  }

  void _executeSearch() {
    final query = _searchCtrl.text;
    _matches.clear();
    if (query.isNotEmpty) {
      final lowerText = _textCtrl.text.toLowerCase();
      final lowerQuery = query.toLowerCase();
      int start = 0;
      while (start < lowerText.length) {
        final idx = lowerText.indexOf(lowerQuery, start);
        if (idx == -1) break;
        _matches.add(idx);
        start = idx + lowerQuery.length;
      }
    }

    if (_matches.isNotEmpty) {
      if (_currentMatchIndex == -1 || _currentMatchIndex >= _matches.length) {
        _currentMatchIndex = 0;
      }
      _scrollToMatch(_matches[_currentMatchIndex]);
    } else {
      _currentMatchIndex = -1;
    }
    setState(() {});
  }

  void _nextMatch() {
    if (_matches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    });
    _scrollToMatch(_matches[_currentMatchIndex]);
  }

  void _prevMatch() {
    if (_matches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    });
    _scrollToMatch(_matches[_currentMatchIndex]);
  }

  void _scrollToMatch(int offset) {
    final queryLen = _searchCtrl.text.length;
    _textCtrl.selection = TextSelection(
      baseOffset: offset,
      extentOffset: offset + queryLen,
    );

    final textBefore = _textCtrl.text.substring(0, offset);
    final line = textBefore.split('\n').length;
    final targetScroll = max(0.0, (line - 4) * _lineHeight);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _reloadFromDisk() async {
    final path = _effectiveFilePath;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        _textCtrl.text = content;
        _hasUnsavedChanges = false;
        _validateSyntax(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已从磁盘重新加载文件内容'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('本地文件不存在: $path'),
              backgroundColor: const Color(0xFFF43F5E),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重新读取失败: $e'),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_syntaxError != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('语法校验警告', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
          content: Text(
            '当前配置检测到语法错误：\n$_syntaxError\n\n如果继续保存，可能导致代理内核无法正常启动。确定要强制保存吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('返回修改'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('强制保存'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final newContent = _textCtrl.text;

    // Custom onSave callback handler
    if (widget.onSave != null) {
      final success = await widget.onSave!(newContent);
      if (success && mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    // Profile update handler
    if (widget.profile != null) {
      await ref.read(profilesProvider.notifier).updateProfileContent(
            widget.profile!.id,
            newContent,
            syncToFile: _syncToFile,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_syncToFile && widget.profile!.filePath != null
                ? '配置已保存并同步至本地文件: ${widget.profile!.filePath}'
                : '配置已成功保存'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
      return;
    }

    // Direct local config.json creation / save
    final path = _effectiveFilePath;
    if (_syncToFile && path != null) {
      try {
        final file = File(path);
        await file.writeAsString(newContent);
      } catch (_) {}
    }

    final success = await ref.read(profilesProvider.notifier).addProfileFromRawText(
          name: _displayTitle,
          rawContent: newContent,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path != null
                ? '配置已成功保存并同步至文件: $path'
                : '配置已成功保存为本地配置文件'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF080C16) : Colors.white;
    final outerBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = _isMaximized ? screenSize.width : min(1080.0, screenSize.width * 0.92);
    final dialogHeight = _isMaximized ? screenSize.height : min(760.0, screenSize.height * 0.88);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveConfig,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _saveConfig,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true): _formatJson,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true, shift: true): _formatJson,
      },
      child: Dialog(
        insetPadding: _isMaximized ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_isMaximized ? 0 : 16),
        ),
        backgroundColor: dialogBg,
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(_isMaximized ? 0 : 16),
            border: Border.all(color: outerBorderColor, width: 1),
          ),
          child: Column(
            children: [
              // Header Toolbar
              _buildHeader(tr),

              // Search Bar (if activated)
              if (_showSearch) _buildSearchBar(tr),

              // Error alert banner if syntax is invalid
              if (_syntaxError != null) _buildSyntaxErrorBanner(tr),

              // Main Code Editor with Line Numbers Gutter OR Visual Config Editor
              if (_editorMode == 0 && _parsedVisualMap != null)
                Expanded(
                  child: VisualConfigEditor(
                    config: _parsedVisualMap!,
                    onChanged: (updatedMap) {
                      _parsedVisualMap = updatedMap;
                      final jsonStr = const JsonEncoder.withIndent('  ').convert(updatedMap);
                      _textCtrl.text = jsonStr;
                      _hasUnsavedChanges = true;
                      _validateSyntax(jsonStr);
                      setState(() {});
                    },
                  ),
                )
              else
                Expanded(
                  child: _buildEditorBody(),
                ),

              // Footer Status Bar
              _buildFooter(tr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Translations tr) {
    final hasFilePath = _effectiveFilePath != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final hoverColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Title, Badges & Window Controls
          Row(
            children: [
              const Icon(Icons.code_rounded, color: Color(0xFF818CF8), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _displayTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Format badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                ),
                child: Text(
                  _detectedFormat,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                ),
              ),
              if (_nodeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$_nodeCount ${tr.nodesCount}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              // Syntax status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _syntaxError == null
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF43F5E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _syntaxError == null
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : const Color(0xFFF43F5E).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _syntaxError == null ? tr.syntaxValid : tr.syntaxError,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _syntaxError == null ? const Color(0xFF34D399) : const Color(0xFFF43F5E),
                  ),
                ),
              ),
              if (_hasUnsavedChanges) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '未保存',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: Icon(_isMaximized ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 18),
                tooltip: _isMaximized ? tr.restore : tr.maximize,
                color: iconColor,
                hoverColor: hoverColor,
                onPressed: () => setState(() => _isMaximized = !_isMaximized),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: tr.close,
                color: iconColor,
                hoverColor: hoverColor,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Sub-Toolbar: Mode Switcher & Tools
          Row(
            children: [
              SegmentedButton<int>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
                ),
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.dashboard_customize_rounded, size: 13),
                    label: Text('可视化编辑', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.code_rounded, size: 13),
                    label: Text('JSON 源码', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_editorMode},
                onSelectionChanged: (set) {
                  final newMode = set.first;
                  if (newMode == 0) {
                    try {
                      final decoded = jsonDecode(_textCtrl.text);
                      if (decoded is Map<String, dynamic>) {
                        setState(() {
                          _parsedVisualMap = decoded;
                          _editorMode = 0;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('当前配置不是标准 JSON 对象结构，请在代码模式下修改'),
                            backgroundColor: Color(0xFFF43F5E),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('存在语法错误，无法进入可视化视图: $e'),
                          backgroundColor: const Color(0xFFF43F5E),
                        ),
                      );
                    }
                  } else {
                    setState(() => _editorMode = 1);
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                tooltip: '载入标准模板',
                color: iconColor,
                hoverColor: hoverColor,
                onPressed: _loadStandardTemplate,
              ),
              IconButton(
                icon: const Icon(Icons.format_indent_increase_rounded, size: 17),
                tooltip: '${tr.formatJson} (Ctrl+Shift+F)',
                color: iconColor,
                hoverColor: hoverColor,
                onPressed: _formatJson,
              ),
              IconButton(
                icon: const Icon(Icons.compress_rounded, size: 17),
                tooltip: tr.minifyJson,
                color: iconColor,
                hoverColor: hoverColor,
                onPressed: _minifyJson,
              ),
              IconButton(
                icon: Icon(Icons.search_rounded, size: 17, color: _showSearch ? const Color(0xFF818CF8) : iconColor),
                tooltip: '${tr.findText} (Ctrl+F)',
                hoverColor: hoverColor,
                onPressed: _toggleSearch,
              ),
              IconButton(
                icon: Icon(Icons.wrap_text_rounded, size: 17, color: _wordWrap ? const Color(0xFF818CF8) : iconColor),
                tooltip: tr.wordWrap,
                hoverColor: hoverColor,
                onPressed: () => setState(() => _wordWrap = !_wordWrap),
              ),
              if (hasFilePath)
                IconButton(
                  icon: const Icon(Icons.file_open_outlined, size: 17),
                  tooltip: tr.reloadFromFile,
                  color: iconColor,
                  hoverColor: hoverColor,
                  onPressed: _reloadFromDisk,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Translations tr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchBarBg = isDark ? const Color(0xFF0D1322) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final inputFill = isDark ? const Color(0xFF080C16) : Colors.white;
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: searchBarBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF818CF8), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: '${tr.findText}...',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                isDense: true,
                filled: true,
                fillColor: inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
              onSubmitted: (_) => _nextMatch(),
            ),
          ),
          if (_matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_currentMatchIndex + 1} / ${_matches.length}',
                style: TextStyle(fontSize: 12, color: iconColor, fontFamily: 'monospace'),
              ),
            )
          else if (_searchCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                tr.noMatchesFound,
                style: const TextStyle(fontSize: 12, color: Color(0xFFF43F5E)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.arrow_upward_rounded, size: 16),
            tooltip: tr.findPrevious,
            color: iconColor,
            onPressed: _prevMatch,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward_rounded, size: 16),
            tooltip: tr.findNext,
            color: iconColor,
            onPressed: _nextMatch,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: tr.close,
            color: iconColor,
            onPressed: _toggleSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSyntaxErrorBanner(Translations tr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF43F5E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tr.jsonSyntaxError}: $_syntaxError${_syntaxErrorLine != null ? ' (行: $_syntaxErrorLine, 列: $_syntaxErrorCol)' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFFDA4AF)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_syntaxErrorOffset != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF43F5E),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: _jumpToSyntaxError,
              icon: const Icon(Icons.near_me_rounded, size: 14),
              label: Text(tr.jumpToError, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorBg = isDark ? const Color(0xFF080C16) : Colors.white;
    final gutterBg = isDark ? const Color(0xFF0B101E) : const Color(0xFFF8FAFC);
    final codeTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      color: editorBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gutter: Line numbers
          Container(
            width: 56,
            color: gutterBg,
            child: ListView.builder(
              controller: _gutterCtrl,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 14, bottom: 20),
              itemCount: _lineCount,
              itemBuilder: (ctx, i) {
                final lineNum = i + 1;
                final isCurrent = lineNum == _cursorLine;
                final isError = lineNum == _syntaxErrorLine;

                Color numColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
                if (isError) {
                  numColor = const Color(0xFFF43F5E);
                } else if (isCurrent) {
                  numColor = const Color(0xFF818CF8);
                }

                return SizedBox(
                  height: _lineHeight,
                  child: Container(
                    padding: const EdgeInsets.only(right: 12),
                    alignment: Alignment.centerRight,
                    color: isCurrent
                        ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : const Color(0xFFCBD5E1).withValues(alpha: 0.4))
                        : (isError ? const Color(0xFFF43F5E).withValues(alpha: 0.15) : null),
                    child: Text(
                      '$lineNum',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: numColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Code Text Area
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
              scrollDirection: Axis.vertical,
              child: _wordWrap
                  ? TextField(
                      controller: _textCtrl,
                      undoController: _undoCtrl,
                      focusNode: _editorFocusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: _fontSize,
                        height: _lineHeightFactor,
                        color: codeTextColor,
                      ),
                      cursorColor: const Color(0xFF818CF8),
                      cursorWidth: 2.0,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: editorBg,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 800,
                          maxWidth: max(800.0, _longestLineWidth * 8.5 + 100),
                        ),
                        child: TextField(
                          controller: _textCtrl,
                          undoController: _undoCtrl,
                          focusNode: _editorFocusNode,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: _fontSize,
                            height: _lineHeightFactor,
                            color: codeTextColor,
                          ),
                          cursorColor: const Color(0xFF818CF8),
                          cursorWidth: 2.0,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: editorBg,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Translations tr) {
    final fileSizeKb = (_textCtrl.text.length / 1024).toStringAsFixed(1);
    final path = _effectiveFilePath;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final footerBg = isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: footerBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Status info
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip('行: $_cursorLine, 列: $_cursorCol', textMuted),
                  const SizedBox(width: 14),
                  _buildStatusChip('$_lineCount 行 | ${_textCtrl.text.length} 字符 | $fileSizeKb KB', textMuted),
                  if (path != null) ...[
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _syncToFile,
                          activeColor: const Color(0xFF6366F1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) => setState(() => _syncToFile = val ?? true),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tr.syncToFile} ($path)',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Right Save & Cancel Buttons
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr.cancel),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _saveConfig,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: Text('${tr.saveChanges} (Ctrl+S)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: color,
      ),
    );
  }
}
