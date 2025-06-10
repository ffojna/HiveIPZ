import 'package:flutter/material.dart';
import '../models/comments.dart';
import '../database/database_helper.dart';
import '../styles/hive_colors.dart';

class CommentSection extends StatefulWidget {
  final String eventId;

  const CommentSection({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController commentController = TextEditingController();
  List<Comment> comments = [];
  bool isLoadingComments = false;
  bool isEventAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    _checkAdminStatus();
  }

  // Sprawdzenie czy użytkownik jest administratorem wydarzenia
  Future<void> _checkAdminStatus() async {
    try {
      final adminStatus = await DatabaseHelper.isAdmin(widget.eventId);
      setState(() {
        isEventAdmin = adminStatus;
      });
    } catch (e) {
      print('Błąd podczas sprawdzania statusu administratora: $e');
    }
  }

  // Pobranie komentarzy z serwera
  Future<void> _fetchComments() async {
    setState(() {
      isLoadingComments = true;
    });

    try {
      final commentsData = await DatabaseHelper.getEventComments(widget.eventId);
      print(commentsData);
      setState(() {
        comments = commentsData.map((commentJson) => Comment.fromJson(commentJson)).toList();
      });
    } catch (e) {
      print('Błąd podczas pobierania komentarzy: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać komentarzy')),
      );
    } finally {
      setState(() {
        isLoadingComments = false;
      });
    }
  }




  Future<void> _addComment(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await DatabaseHelper.addEventComment(widget.eventId, text); // 👈 WYWOŁANIE dodania
      commentController.clear(); // 👈 Czyścimy input po dodaniu
      await _fetchComments(); // 👈 Odśwież listę komentarzy
    } catch (e) {
      print('Błąd komentarzy: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się dodać komentarza')),
      );
    }
  }

  // Usuwanie komentarza (tylko dla administratorów wydarzenia)
  Future<void> _deleteComment(Comment comment) async {
    try {
      await DatabaseHelper.deleteEventComment(widget.eventId, comment.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Komentarz został usunięty')),
      );
      await _fetchComments(); // Odśwież listę komentarzy
    } catch (e) {
      print('Błąd podczas usuwania komentarza: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się usunąć komentarza: $e')),
      );
    }
  }

  // Pokazuje dialog potwierdzający usunięcie komentarza
  void _showDeleteDialog(Comment comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń komentarz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Autor: ${comment.username}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Treść: ${comment.text}'),
            const SizedBox(height: 12),
            const Text('Czy na pewno chcesz usunąć ten komentarz?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteComment(comment);
            },
            child: const Text('Usuń'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );  }

  // Formatowanie daty dla komentarzy
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} dni temu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} godz. temu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min. temu';
    } else {
      return 'Przed chwilą';
    }
  }

  // Pokazuje dialog do zgłaszania komentarza
  void _showReportDialog(Comment comment) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zgłoś komentarz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Autor: ${comment.username}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Treść: ${comment.text}'),
            const SizedBox(height: 12),
            const Text('Powód zgłoszenia:'),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Opisz dlaczego zgłaszasz ten komentarz',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Podaj powód zgłoszenia')),
                );
                return;
              }
              
              try {
                await DatabaseHelper.reportComment(
                  widget.eventId,
                  comment.id,
                  reason,
                );
                
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Komentarz został zgłoszony')),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Błąd podczas zgłaszania: $e')),
                );
              }
            },
            child: const Text('Zgłoś'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  // Pokazuje kontekstowe menu po przytrzymaniu komentarza
  void _showContextMenu(BuildContext context, Offset position, Comment comment) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem(
        value: 'report',
        child: Row(
          children: [
            Icon(Icons.flag, color: Colors.red),
            SizedBox(width: 8),
            Text('Zgłoś komentarz'),
          ],
        ),
      ),
    ];

    // Dodaj opcję usuwania tylko dla admina
    if (isEventAdmin) {
      menuItems.add(
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Usuń komentarz'),
            ],
          ),
        ),
      );
    }
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: menuItems,
    ).then((value) {
      if (value == 'report') {
        _showReportDialog(comment);
      } else if (value == 'delete') {
        _showDeleteDialog(comment);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Komentarze${isEventAdmin ? ' (Administrator)' : ''}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: isLoadingComments
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                    ? const Center(child: Text('Nie ma jeszcze komentarzy'))
                    : ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return GestureDetector(
                            onLongPress: () {
                              final RenderBox renderBox = context.findRenderObject() as RenderBox;
                              final position = renderBox.localToGlobal(Offset.zero);
                              _showContextMenu(context, position, comment);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        comment.username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),                                      Row(
                                        children: [
                                          Text(
                                            _formatDate(comment.createdAt),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.report_problem, size: 16, color: Colors.red),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              _showReportDialog(comment);
                                            },
                                          ),
                                          // Pokaż przycisk usuwania tylko dla admina
                                          if (isEventAdmin)
                                            IconButton(
                                              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                _showDeleteDialog(comment);
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(comment.text),
                                  const Divider(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: 'Dodaj komentarz...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: HiveColors.main,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: HiveColors.main,
                        width: 2,
                      ),
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.send,
                  color: HiveColors.main,
                ),
                onPressed: () {
                  _addComment(commentController.text).then((_) {
                    commentController.clear();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Pomocnicza metoda do wyświetlania sekcji komentarzy w oknie modalnym
void showCommentsModal(BuildContext context, String eventId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CommentSection(eventId: eventId),
      );
    },
  );
}