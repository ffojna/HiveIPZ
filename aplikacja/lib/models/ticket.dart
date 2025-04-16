class Ticket {
  final String ticketId;
  final String status;
  final double price;
  final String purchaseDate;
  final String eventId;
  final String eventName;
  final String eventLocation;
  final String eventDate;
  final String ticketNumber;
  final String userName;
  final String userSurname;
  final String nickName;

  Ticket({
    required this.ticketId,
    required this.status,
    required this.price,
    required this.purchaseDate,
    required this.eventId,
    required this.eventName,
    required this.eventLocation,
    required this.eventDate,
    required this.ticketNumber,
    required this.userName,
    required this.userSurname,
    required this.nickName,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    // Handle price conversion safely
    double convertPrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // Format date safely
    String formatDate(dynamic date) {
      if (date == null) return '';
      return date.toString();
    }

    return Ticket(
      ticketId: json['ticket_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      price: convertPrice(json['price']),
      purchaseDate: formatDate(json['purchase_date']),
      eventId: json['event_id']?.toString() ?? '',
      eventName: json['event_name']?.toString() ?? '',
      eventLocation: json['event_location']?.toString() ?? '',
      eventDate: formatDate(json['event_date']),
      ticketNumber: json['ticket_number']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      userSurname: json['user_surname']?.toString() ?? '',
      nickName: json['nickName']?.toString() ?? '',
    );
  }
}