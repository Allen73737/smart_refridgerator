import 'dart:convert';
import 'dart:ui'; // 🔹 Added for Blur
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/secure_storage_service.dart';

class ChatAssistantOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String action, String? value)? onActionTriggered;

  const ChatAssistantOverlay({super.key, required this.onClose, this.onActionTriggered});

  @override
  State<ChatAssistantOverlay> createState() => _ChatAssistantOverlayState();
}

class _ChatAssistantOverlayState extends State<ChatAssistantOverlay> with SingleTickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  final Set<int> _confirmedIndices = {};
  
  static final List<Map<String, String>> _persistedMessages = [
    {"role": "assistant", "content": "Hello! I am Smridgey - Your Smridge AI Companion. How can I transform your kitchen experience today? ✨"}
  ];

  bool _isTyping = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final isAtBottom = _scrollController.hasClients &&
          _scrollController.offset >= _scrollController.position.maxScrollExtent - 100;
      if (isAtBottom && _showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      } else if (!isAtBottom && !_showScrollToBottom) {
        setState(() => _showScrollToBottom = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _clearChat() {
    setState(() {
      _persistedMessages.clear();
      _persistedMessages.add({
        "role": "assistant", 
        "content": "History purged. Fresh start! How may I assist? 🌿"
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final affirmationWords = ['confirm', 'yes', 'yep', 'y', 'do it', 'sure', 'pls', 'please'];
    if (affirmationWords.contains(text.toLowerCase())) {
       for (int i = _persistedMessages.length - 1; i >= 0; i--) {
         final msg = _persistedMessages[i];
         final actionType = msg["action"];
         if (actionType != null && actionType.isNotEmpty && !_confirmedIndices.contains(i)) {
            final isCRUD = actionType == "ADD_ITEM_AI" || actionType == "ADD_ITEM" || 
                           actionType == "DELETE_ITEM" || actionType == "EDIT_ITEM";
            if (isCRUD) {
               widget.onActionTriggered?.call(actionType, msg["actionValue"]);
               setState(() {
                 _confirmedIndices.add(i);
                 _persistedMessages.add({"role": "user", "content": text});
               });
               _msgController.clear();
               return;
            }
         }
       }
    }

    setState(() {
      _persistedMessages.add({"role": "user", "content": text});
      _isTyping = true;
    });
    _msgController.clear();

    final token = await SecureStorageService.getToken();
    if (token == null) return;
    
    final history = _persistedMessages.map((m) => {
      "role": m["role"]!,
      "content": m["content"]!,
    }).toList();

    final reply = await ApiService.askChatAssistant(text, token, history: history);

    String? cleanReply = reply;
    String? detectedAction;
    String? actionValue;

    if (reply != null && reply.contains("[ACTION:")) {
      final regExp = RegExp(r"\[ACTION:([A-Z_]+):?(.*?)\]", dotAll: true);
      final match = regExp.firstMatch(reply);
      if (match != null) {
        detectedAction = match.group(1);
        actionValue = match.group(2);
        if (actionValue?.isEmpty ?? true) actionValue = null;
        cleanReply = reply.replaceAll(regExp, "").trim();
      }
    }

    if (mounted) {
      setState(() {
        _isTyping = false;
        _persistedMessages.add({
          "role": "assistant", 
          "content": cleanReply ?? "I'm having trouble connecting to my neural core. Please check your connection.",
          "action": detectedAction ?? "",
          "actionValue": actionValue ?? "",
        });
      });
      
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

      final isInventoryAction = detectedAction == "ADD_ITEM_AI" || 
                                detectedAction == "ADD_ITEM" || 
                                detectedAction == "DELETE_ITEM" || 
                                detectedAction == "EDIT_ITEM" ||
                                detectedAction == "OPEN_SCREEN";

      if (detectedAction != null && !isInventoryAction) {
        if (widget.onActionTriggered != null) {
          widget.onActionTriggered!(detectedAction, actionValue);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    final glassColor = isLight ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.75);
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return AnimatedContainer(
      duration: 400.ms,
      curve: Curves.easeInOutQuart,
      margin: _isExpanded ? EdgeInsets.zero : const EdgeInsets.all(12),
      height: _isExpanded ? MediaQuery.of(context).size.height : MediaQuery.of(context).size.height * 0.75,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_isExpanded ? 0 : 32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(_isExpanded ? 0 : 32),
              border: Border.all(color: Colors.white24.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, spreadRadius: -5)
              ],
            ),
            child: Column(
            children: [
              // Premium Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor.withOpacity(0.8), accentColor.withOpacity(0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.psychology, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SMRIDGEY", 
                            style: GoogleFonts.orbitron(
                              color: Colors.white, 
                              fontSize: 18, 
                              fontWeight: FontWeight.w900, 
                              letterSpacing: 3,
                            ),
                          ),
                          Text("AI Assistant • Online", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    _headerAction(Icons.delete_sweep, _clearChat),
                    _headerAction(_isExpanded ? Icons.fullscreen_exit : Icons.fullscreen, () => setState(() => _isExpanded = !_isExpanded)),
                    _headerAction(Icons.close, widget.onClose),
                  ],
                ),
              ),

              // Chat Canvas
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: _persistedMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _persistedMessages[index];
                        final isUser = msg["role"] == "user";
                        return _buildChatBubble(msg, isUser, index, isLight, textColor, accentColor);
                      },
                    ),
                    if (_showScrollToBottom)
                      Positioned(bottom: 20, right: 20, child: _buildScrollDownIcon()),
                  ],
                ),
              ),

              if (_isTyping) _buildTypingIndicator(isLight),

              // Glassy Input Field
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _msgController,
                          style: TextStyle(color: textColor, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: "Type a command...",
                            hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, color: Colors.black, size: 24),
                      ),
                    ),
                  ],
                ),
              )
            ],
            ),
          ),
        ),
      ),
    ).animate()
     .fadeIn(duration: 400.ms)
     .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack)
     .slideY(begin: 0.2, curve: Curves.easeOutCubic);
  }

  Widget _headerAction(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 22),
      onPressed: onTap,
      splashRadius: 24,
    );
  }

  Widget _buildChatBubble(Map<String, String> msg, bool isUser, int index, bool isLight, Color textColor, Color accentColor) {
    final bubbleColor = isUser 
        ? accentColor.withOpacity(isLight ? 0.7 : 0.2) 
        : (isLight ? Colors.white : Colors.white10);
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(24).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(24),
            bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(24),
          ),
          boxShadow: [
            if (isUser) BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: msg["content"]!,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: isUser && isLight ? Colors.white : textColor, fontSize: 14, height: 1.5),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                code: TextStyle(backgroundColor: Colors.black12, color: accentColor),
              ),
            ),
            if (msg["action"] != null && msg["action"]!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildActionButton(msg, index, accentColor),
            ]
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: isUser ? 0.1 : -0.1),
    );
  }

  Widget _buildActionButton(Map<String, String> msg, int index, Color accentColor) {
    final action = msg["action"]!;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
      ),
      icon: Icon(_getActionIcon(action, index), size: 18),
      label: Text(_getActionLabel(action, msg["actionValue"], index), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      onPressed: () {
        final actionType = msg["action"]!;
        final isCRUD = actionType == "ADD_ITEM_AI" || actionType == "ADD_ITEM" || 
                       actionType == "DELETE_ITEM" || actionType == "EDIT_ITEM";

        if (isCRUD && !_confirmedIndices.contains(index)) {
          widget.onActionTriggered?.call(actionType, msg["actionValue"]);
          setState(() => _confirmedIndices.add(index));
        } else {
          if (isCRUD) {
            widget.onActionTriggered?.call("OPEN_SCREEN", "Inventory");
          } else {
            widget.onActionTriggered?.call(actionType, msg["actionValue"]);
          }
          widget.onClose();
        }
      },
    );
  }

  Widget _buildTypingIndicator(bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 10),
      child: Row(
        children: [
          Text("analyzing", style: TextStyle(color: isLight ? Colors.black45 : Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(width: 4),
          _dot(0), _dot(1), _dot(2),
        ],
      ),
    );
  }

  Widget _dot(int delay) {
    return Container(
      width: 4, height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(delay: (delay * 150).ms, duration: 400.ms);
  }

  Widget _buildScrollDownIcon() {
    return GestureDetector(
      onTap: _scrollToBottom,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
      ),
    ).animate().scale().fade();
  }

  IconData _getActionIcon(String action, int index) {
    if (action == "OPEN_SCREEN") return Icons.explore_rounded;
    if (_confirmedIndices.contains(index)) return Icons.arrow_forward_rounded;
    return Icons.check_circle_rounded;
  }

  String _getActionLabel(String action, String? value, int index) {
    final isCRUD = action == "ADD_ITEM_AI" || action == "ADD_ITEM" || 
                   action == "DELETE_ITEM" || action == "EDIT_ITEM";
    if (isCRUD && !_confirmedIndices.contains(index)) return "Execute Command";
    if (action == "OPEN_SCREEN" || (isCRUD && _confirmedIndices.contains(index))) {
       return "View Hub";
    }
    return "Confirm";
  }
}
