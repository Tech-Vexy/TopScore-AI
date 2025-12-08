import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/support_ticket_model.dart';
import '../../constants/colors.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showCreateTicketDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Support Ticket'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Brief summary of the issue',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a subject' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe your issue in detail',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a message' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        setState(() => isLoading = true);
                        try {
                          final user = Provider.of<AuthProvider>(context, listen: false).userModel;
                          if (user != null) {
                            final ticket = SupportTicket(
                              id: '', // Firestore generates ID
                              userId: user.uid,
                              subject: subjectController.text.trim(),
                              message: messageController.text.trim(),
                              createdAt: DateTime.now(),
                            );
                            await _firestoreService.createSupportTicket(ticket);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ticket created successfully'),
                                  backgroundColor: AppColors.googleGreen,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating ticket: $e'),
                                backgroundColor: AppColors.googleRed,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final theme = Theme.of(context);

    if (user == null) {
      return Center(child: Text('Please log in to view support tickets', style: TextStyle(color: theme.colorScheme.onSurface)));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support Center',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'We are here to help',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateTicketDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // Ticket List
          Expanded(
            child: StreamBuilder<List<SupportTicket>>(
              stream: _firestoreService.getUserSupportTickets(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  if (snapshot.error.toString().contains('permission-denied')) {
                     return Center(child: Text('Access denied. Please contact support.', style: TextStyle(color: theme.colorScheme.onSurface)));
                  }
                  if (snapshot.error.toString().contains('unavailable') || 
                      snapshot.error.toString().contains('BLOCKED_BY_CLIENT')) {
                     return Center(
                       child: Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Text(
                           'Connection blocked. Please disable ad blockers or check your internet connection.',
                           textAlign: TextAlign.center,
                           style: TextStyle(color: theme.colorScheme.onSurface),
                         ),
                       ),
                     );
                  }
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.onSurface)));
                }

                final tickets = snapshot.data ?? [];

                if (tickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.support_agent, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No support tickets yet',
                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _showCreateTicketDialog,
                          child: const Text('Create your first ticket'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(ticket.status).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getStatusIcon(ticket.status),
                            color: _getStatusColor(ticket.status),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          ticket.subject,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, y • h:mm a').format(ticket.createdAt),
                              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(ticket.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ticket.status.toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(ticket.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Message:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(ticket.message, style: TextStyle(color: theme.colorScheme.onSurface)),
                                if (ticket.reply != null) ...[
                                  const SizedBox(height: 16),
                                  Divider(color: theme.dividerColor),
                                  const SizedBox(height: 8),
                                  const Row(
                                    children: [
                                      Icon(Icons.support_agent, size: 16, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text(
                                        'Support Reply:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(ticket.reply!, style: TextStyle(color: theme.colorScheme.onSurface)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return AppColors.googleGreen;
      case 'closed':
        return AppColors.textSecondary;
      default:
        return AppColors.googleYellow;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Icons.check_circle_outline;
      case 'closed':
        return Icons.lock_outline;
      default:
        return Icons.schedule;
    }
  }
}
