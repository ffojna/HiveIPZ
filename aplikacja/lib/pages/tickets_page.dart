import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/ticket.dart';
import 'ticket_details_page.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({Key? key}) : super(key: key);

  @override
  _TicketsPageState createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  bool _isLoading = true;
  List<Ticket> _tickets = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final ticketsData = await DatabaseHelper.getUserTickets();
      setState(() {
        _tickets = ticketsData.map((data) => Ticket.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Nie udało się załadować biletów: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje bilety'),
        backgroundColor: Colors.amber,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
              : _tickets.isEmpty
                  ? const Center(child: Text('Nie masz jeszcze żadnych biletów'))
                  : RefreshIndicator(
                      onRefresh: _loadTickets,
                      child: ListView.builder(
                        itemCount: _tickets.length,
                        itemBuilder: (context, index) {
                          final ticket = _tickets[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: ListTile(
                              title: Text(
                                ticket.eventName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ticket.eventLocation),
                                  Text(
                                    'Data: ${DateFormat('dd.MM.yyyy HH:mm').format(
                                      DateTime.parse(ticket.eventDate),
                                    )}',
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.qr_code),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TicketDetailsPage(ticket: ticket),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}