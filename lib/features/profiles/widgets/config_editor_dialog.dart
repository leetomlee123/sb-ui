import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/engine/profile_parser.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/models/profile.dart';
import '../../../core/providers/profiles_provider.dart';

class ConfigEditorDialog extends ConsumerStatefulWidget {
  final Profile profile;

  const ConfigEditorDialog({
    super.key,
    required this.profile,
  });

  @override
  ConsumerState<ConfigEditorDialog> createState() => _ConfigEditorDialogState();
}

class _ConfigEditorDialogState extends ConsumerState<ConfigEditorDialog> {
  late final TextEditingController _textCtrl;
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

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.profile.rawConfig);
    _undoCtrl = UndoHistoryController();
    _syncToFile = widget.profile.type == ProfileType.local && widget.profile.filePath != null;

    _textCtrl.addListener(_onTextChanged);
    _scrollCtrl.addListener(_syncScrollGutter);
    _searchCtrl.addListener(_onSearchChanged);

    _validateSyntax(_textCtrl.text);
    _updateCursorAndStats();
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
    if (!_hasUnsavedChanges && _textCtrl.text != widget.profile.rawConfig) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
    if (_showSearch && _searchCtrl.text.isNotEmpty) {
      _executeSearch();
    }
  }

  void _updateCursorAndStats() {
    final text = _textCtrl.text;
    final lines = text.split('\n');
    _lineCount = max(1, lines.length);

    final sel = _textCtrl.selection;
    if (sel.isValid) {
      final offset = sel.baseOffset.clamp(0, text.length);
      final textBefore = text.substring(0, offset);
      final linesBefore = textBefore.split('\n');
      _cursorLine = linesBefore.length;
      _cursorCol = linesBefore.last.length + 1;
    }
    if (mounted) setState(() {});
  }

  void _validateSyntax(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _syntaxError = null;
      _syntaxErrorOffset = null;
      _syntaxErrorLine = null;
      _syntaxErrorCol = null;
      _detectedFormat = 'Empty';
      _nodeCount = 0;
      return;
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        jsonDecode(trimmed);
        final parseResult = ProfileParser.parse(trimmed);
        _syntaxError = null;
        _syntaxErrorOffset = null;
        _syntaxErrorLine = null;
        _syntaxErrorCol = null;
        _detectedFormat = 'sing-box JSON';
        _nodeCount = parseResult.count;
      } on FormatException catch (e) {
        _syntaxError = e.message;
        _syntaxErrorOffset = e.offset;
        _detectedFormat = 'JSON (Invalid)';
        if (e.offset != null) {
          final before = text.substring(0, e.offset!.clamp(0, text.length));
          final lines = before.split('\n');
          _syntaxErrorLine = lines.length;
          _syntaxErrorCol = lines.last.length + 1;
        }
      } catch (e) {
        _syntaxError = e.toString();
        _syntaxErrorOffset = null;
        _detectedFormat = 'JSON (Invalid)';
      }
    } else if (trimmed.contains('proxies:') ||
        trimmed.contains('proxy-groups:') ||
        trimmed.contains('rules:')) {
      try {
        final parseResult = ProfileParser.parse(trimmed);
        _syntaxError = null;
        _syntaxErrorOffset = null;
        _syntaxErrorLine = null;
        _syntaxErrorCol = null;
        _detectedFormat = 'Clash YAML';
        _nodeCount = parseResult.count;
      } catch (e) {
        _syntaxError = 'YAML Error: $e';
        _detectedFormat = 'YAML (Invalid)';
      }
    } else {
      final parseResult = ProfileParser.parse(trimmed);
      _syntaxError = null;
      _syntaxErrorOffset = null;
      _syntaxErrorLine = null;
      _syntaxErrorCol = null;
      _detectedFormat = 'URI List';
      _nodeCount = parseResult.count;
    }
  }

  void _jumpToError() {
    if (_syntaxErrorOffset != null) {
      final offset = _syntaxErrorOffset!.clamp(0, _textCtrl.text.length);
      _textCtrl.selection = TextSelection.collapsed(offset: offset);
      final textBefore = _textCtrl.text.substring(0, offset);
      final line = textBefore.split('\n').length;
      final targetScroll = max(0.0, (line - 4) * _lineHeight);
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      _editorFocusNode.requestFocus();
    }
  }

  void _formatJson() {
    try {
      final decoded = jsonDecode(_textCtrl.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      final prevSelection = _textCtrl.selection;
      _textCtrl.text = formatted;
      if (prevSelection.isValid && prevSelection.end <= formatted.length) {
        _textCtrl.selection = prevSelection;
      }
      _validateSyntax(formatted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已成功格式化 JSON'),
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
    if (widget.profile.filePath == null) return;
    try {
      final file = File(widget.profile.filePath!);
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
              content: Text('本地文件不存在: ${widget.profile.filePath}'),
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
    await ref.read(profilesProvider.notifier).updateProfileContent(
          widget.profile.id,
          newContent,
          syncToFile: _syncToFile,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_syncToFile && widget.profile.filePath != null
              ? '配置已保存并同步至本地文件: ${widget.profile.filePath}'
              : '配置已成功保存'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationsProvider);
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = _isMaximized ? screenSize.width : min(1060.0, screenSize.width * 0.92);
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
        backgroundColor: const Color(0xFF0F172A),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(_isMaximized ? 0 : 16),
            border: Border.all(color: const Color(0xFF334155), width: 1),
          ),
          child: Column(
            children: [
              // Header Toolbar
              _buildHeader(tr),

              // Search Bar (if activated)
              if (_showSearch) _buildSearchBar(tr),

              // Error alert banner if syntax is invalid
              if (_syntaxError != null) _buildSyntaxErrorBanner(tr),

              // Main Code Editor with Line Numbers Gutter
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          const Icon(Icons.code_rounded, color: Color(0xFF818CF8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.profile.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF1F5F9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                // Format badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _detectedFormat,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                  ),
                ),
                const SizedBox(width: 8),
                // Nodes count badge
                if (_nodeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$_nodeCount ${tr.nodesCount}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF34D399)),
                    ),
                  ),
                const SizedBox(width: 8),
                // Syntax status badge
                if (_syntaxError == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          tr.syntaxValid,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  )
                else
                  InkWell(
                    onTap: _jumpToError,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFF43F5E)),
                          const SizedBox(width: 4),
                          Text(
                            _syntaxErrorLine != null
                                ? '${tr.syntaxError}: 第 $_syntaxErrorLine 行'
                                : tr.syntaxError,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action tools
          IconButton(
            icon: const Icon(Icons.format_indent_increase_rounded, size: 18),
            tooltip: '${tr.formatJson} (Ctrl+Shift+F)',
            color: const Color(0xFF94A3B8),
            hoverColor: const Color(0xFF334155),
            onPressed: _formatJson,
          ),
          IconButton(
            icon: const Icon(Icons.compress_rounded, size: 18),
            tooltip: tr.minifyJson,
            color: const Color(0xFF94A3B8),
            hoverColor: const Color(0xFF334155),
            onPressed: _minifyJson,
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, size: 18, color: _showSearch ? const Color(0xFF818CF8) : const Color(0xFF94A3B8)),
            tooltip: '${tr.findText} (Ctrl+F)',
            hoverColor: const Color(0xFF334155),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: Icon(Icons.wrap_text_rounded, size: 18, color: _wordWrap ? const Color(0xFF818CF8) : const Color(0xFF94A3B8)),
            tooltip: tr.wordWrap,
            hoverColor: const Color(0xFF334155),
            onPressed: () => setState(() => _wordWrap = !_wordWrap),
          ),
          if (widget.profile.type == ProfileType.local && widget.profile.filePath != null)
            IconButton(
              icon: const Icon(Icons.file_open_outlined, size: 18),
              tooltip: tr.reloadFromFile,
              color: const Color(0xFF94A3B8),
              hoverColor: const Color(0xFF334155),
              onPressed: _reloadFromDisk,
            ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(_isMaximized ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 20),
            tooltip: _isMaximized ? tr.restore : tr.maximize,
            color: const Color(0xFF94A3B8),
            hoverColor: const Color(0xFF334155),
            onPressed: () => setState(() => _isMaximized = !_isMaximized),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: tr.close,
            color: const Color(0xFF94A3B8),
            hoverColor: const Color(0xFF334155),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Translations tr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xFF818CF8)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              style: const TextStyle(fontSize: 13, color: Color(0xFFF1F5F9)),
              decoration: InputDecoration(
                hintText: tr.isZh ? '输入关键词在配置中查找...' : 'Search in config...',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF818CF8)),
                ),
              ),
              onSubmitted: (_) => _nextMatch(),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _matches.isNotEmpty
                ? '${_currentMatchIndex + 1} / ${_matches.length}'
                : (_searchCtrl.text.isNotEmpty ? '0 / 0' : ''),
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            tooltip: tr.isZh ? '上一个' : 'Previous',
            color: const Color(0xFF94A3B8),
            onPressed: _matches.isNotEmpty ? _prevMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            tooltip: tr.isZh ? '下一个' : 'Next',
            color: const Color(0xFF94A3B8),
            onPressed: _matches.isNotEmpty ? _nextMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: tr.close,
            color: const Color(0xFF94A3B8),
            onPressed: _toggleSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSyntaxErrorBanner(Translations tr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF450A0A),
        border: Border(bottom: BorderSide(color: Color(0xFF991B1B))),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFF87171)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _syntaxErrorLine != null
                  ? '第 $_syntaxErrorLine 行，第 $_syntaxErrorCol 列: $_syntaxError'
                  : '语法解析异常: $_syntaxError',
              style: const TextStyle(fontSize: 12, color: Color(0xFFFECACA), fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_syntaxErrorOffset != null)
            TextButton.icon(
              onPressed: _jumpToError,
              icon: const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFFF87171)),
              label: Text(
                tr.jumpToError,
                style: const TextStyle(fontSize: 12, color: Color(0xFFF87171), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Gutter Line Numbers
        Container(
          width: 54,
          decoration: const BoxDecoration(
            color: Color(0xFF090D16),
            border: Border(right: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: ListView.builder(
            controller: _gutterCtrl,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _lineCount,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final lineNum = index + 1;
              final isCurrentLine = lineNum == _cursorLine;
              final isErrorLine = lineNum == _syntaxErrorLine;

              return Container(
                height: _lineHeight,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 10),
                color: isErrorLine
                    ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                    : (isCurrentLine ? const Color(0xFF334155).withValues(alpha: 0.4) : null),
                child: Text(
                  '$lineNum',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: _fontSize,
                    height: _lineHeightFactor,
                    color: isErrorLine
                        ? const Color(0xFFF87171)
                        : (isCurrentLine ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                    fontWeight: (isCurrentLine || isErrorLine) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),

        // Text Field Area
        Expanded(
          child: Container(
            color: const Color(0xFF0F172A),
            child: _wordWrap
                ? _buildTextField(null)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 800),
                      child: _buildTextField(double.infinity),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(double? width) {
    final field = TextField(
      controller: _textCtrl,
      focusNode: _editorFocusNode,
      undoController: _undoCtrl,
      scrollController: _scrollCtrl,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: _fontSize,
        height: _lineHeightFactor,
        color: Color(0xFFE2E8F0),
        letterSpacing: 0.3,
      ),
      cursorColor: const Color(0xFF818CF8),
      cursorWidth: 2,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
      ),
    );

    return width != null ? SizedBox(width: max(800.0, _calculateLongestLine()), child: field) : field;
  }

  double _calculateLongestLine() {
    final lines = _textCtrl.text.split('\n');
    int maxLen = 0;
    for (final l in lines) {
      if (l.length > maxLen) maxLen = l.length;
    }
    return max(900.0, maxLen * 8.5);
  }

  Widget _buildFooter(Translations tr) {
    final fileSizeKb = (_textCtrl.text.length / 1024).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
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
                  _buildStatusChip('行: $_cursorLine, 列: $_cursorCol'),
                  const SizedBox(width: 14),
                  _buildStatusChip('$_lineCount 行 | ${_textCtrl.text.length} 字符 | $fileSizeKb KB'),
                  if (widget.profile.type == ProfileType.local && widget.profile.filePath != null) ...[
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
                          '${tr.syncToFile} (${widget.profile.filePath})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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

  Widget _buildStatusChip(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: Color(0xFF94A3B8),
      ),
    );
  }
}
