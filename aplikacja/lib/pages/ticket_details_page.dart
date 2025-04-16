import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/ticket.dart';

class TicketDetailsPage extends StatelessWidget {
  final Ticket ticket;

  const TicketDetailsPage({Key? key, required this.ticket}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilet'),
        backgroundColor: Colors.amber,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Event name
              Text(
                ticket.eventName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // QR Code
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: ticket.ticketNumber,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              // Ticket number
              Text(
                'Numer biletu: ${ticket.ticketNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              
              // Event details
              _buildInfoSection('WYDARZENIE'),
              _buildDetailRow('Nazwa', ticket.eventName),
              _buildDetailRow('Miejsce', ticket.eventLocation),
              _buildDetailRow('Data', DateFormat('dd.MM.yyyy HH:mm').format(
                DateTime.parse(ticket.eventDate),
              )),
              
              const SizedBox(height: 20),
              
              // User details
              _buildInfoSection('WŁAŚCICIEL'),
              _buildDetailRow('Imię i nazwisko', '${ticket.userName} ${ticket.userSurname}'),
              _buildDetailRow('Nazwa użytkownika', ticket.nickName),
              
              const SizedBox(height: 20),
              
              // Ticket details
              _buildInfoSection('INFORMACJE O BILECIE'),
              _buildDetailRow('Status', ticket.status),
              _buildDetailRow('Cena', ticket.price > 0 ? '${ticket.price} zł' : 'Bezpłatny'),
              _buildDetailRow('Data zakupu', DateFormat('dd.MM.yyyy HH:mm').format(
                DateTime.parse(ticket.purchaseDate),
              )),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        const Divider(thickness: 1),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}