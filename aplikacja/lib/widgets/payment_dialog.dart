import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';

class PaymentBottomSheet extends StatefulWidget {
  final double price;
  final bool hasDiscount;
  final VoidCallback onDiscountTap;
  final bool hasDiscountTickets;
  final bool hasVipTickets;
  final String userId;

  const PaymentBottomSheet({
    super.key,
    required this.price,
    required this.hasDiscount,
    required this.onDiscountTap,
    this.hasDiscountTickets = false,
    this.hasVipTickets = false,
    required this.userId,
  });

  @override
  _PaymentBottomSheetState createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  String? _cardNumberError;
  String _selectedTicketType = 'standard';

  @override
  void initState() {
    super.initState();
    _loadSavedCardDetails();
  }

  Future<void> _loadSavedCardDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cardNumberController.text = prefs.getString('cardNumber') ?? '';
      _expiryDateController.text = prefs.getString('expiryDate') ?? '';
      _cvvController.text = prefs.getString('cvv') ?? '';
    });
  }

  bool _validateCardNumber() {
    final cardNumber = _cardNumberController.text;
    if (cardNumber.length != 16) {
      setState(() {
        _cardNumberError = 'Numer karty musi zawierać 16 cyfr';
      });
      return false;
    }
    return true;
  }

  double _calculateFinalPrice() {
    double basePrice = widget.price;
    double priceAfterTicketType;
    double priceAfterDiscount = 0.0;

    // Najpierw oblicz cenę na podstawie typu biletu
    switch (_selectedTicketType) {
      case 'vip':
        priceAfterTicketType = basePrice * 1.3; // +30%
        break;
      case 'discount':
        priceAfterTicketType = basePrice * 0.7; // -30%
        break;
      case 'standard':
      default:
        priceAfterTicketType = basePrice;
        break;
    }

    // Następnie odejmij zniżkę hasDiscount, jeśli dotyczy
    double discount = widget.hasDiscount && basePrice > 10 ? 10.0 : 0.0;
    return priceAfterDiscount = priceAfterTicketType - discount;
  }

  // NOWA metoda do uzyskania nazwy typu biletu
  String _getTicketTypeName(String type) {
    switch (type) {
      case 'vip':
        return 'VIP (+30%)';
      case 'discount':
        return 'Ulgowy (-30%)';
      case 'standard':
      default:
        return 'Standardowy';
    }
  }

  void _showDiscountDialog(
      BuildContext context, double price, bool canUsePromo) async {
    if (!canUsePromo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie możesz użyć promocji na ten bilet.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Użyć promocji?'),
          content: const Text(
              'Masz aktywną promocję -10zł. Czy chcesz ją wykorzystać na ten bilet?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Użyj'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      Navigator.pop(context); // zamknij poprzedni PaymentBottomSheet

      final paymentConfirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PaymentBottomSheet(
          price: price,
          hasDiscount: true,
          onDiscountTap: () => _showDiscountDialog(context, price, canUsePromo),
          userId: widget.userId, // Pass userId here
        ),
      );

      if (paymentConfirmed != true) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final discount = widget.hasDiscount && widget.price > 10 ? 10.0 : 0.0;
    final finalPrice = _calculateFinalPrice();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Górny uchwyt
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Dodaj metodę płatności',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // POLA KARTY
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Numer karty',
                      errorText: _cardNumberError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _expiryDateController,
                          decoration: const InputDecoration(
                            labelText: 'Data ważności',
                            border: OutlineInputBorder(),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _cvvController,
                          decoration: const InputDecoration(
                            labelText: 'CVV',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  if (widget.hasDiscountTickets || widget.hasVipTickets) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Typ biletu',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Text(_getTicketTypeName('standard')),
                            value: 'standard',
                            groupValue: _selectedTicketType,
                            onChanged: (value) {
                              setState(() {
                                _selectedTicketType = value!;
                              });
                            },
                          ),
                          if (widget.hasDiscountTickets)
                            RadioListTile<String>(
                              title: Text(_getTicketTypeName('discount')),
                              value: 'discount',
                              groupValue: _selectedTicketType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedTicketType = value!;
                                });
                              },
                            ),
                          if (widget.hasVipTickets)
                            RadioListTile<String>(
                              title: Text(_getTicketTypeName('vip')),
                              value: 'vip',
                              groupValue: _selectedTicketType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedTicketType = value!;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // DODAJ PROMOCJĘ
                  GestureDetector(
                    onTap: widget.onDiscountTap,
                    child: Row(
                      children: [
                        const Icon(Icons.percent_rounded, size: 28),
                        const SizedBox(width: 8),
                        const Text(
                          'Dodaj promocję',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // PODSUMOWANIE
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Podsumowanie',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _summaryRow(
                      'Cena biletu', '${widget.price.toStringAsFixed(2)}zł'),
                   if (_selectedTicketType == 'vip')
                    _summaryRow(
                        'Dopłata VIP (+30%)', '+${(widget.price * 0.3).toStringAsFixed(2)}zł',
                        color: Colors.orange),
                  if (_selectedTicketType == 'discount')
                    _summaryRow(
                        'Zniżka ulgowa (-30%)', '-${(widget.price * 0.3).toStringAsFixed(2)}zł',
                        color: Colors.green),
                  if (discount > 0)
                    _summaryRow(
                        'Promocja %', '-${discount.toStringAsFixed(2)}zł',
                        color: Colors.green),

                  const Divider(height: 32),

                  _summaryRow('Suma', '${_calculateFinalPrice().toStringAsFixed(2)}zł', bold: true),  
                    
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ZAPŁAĆ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_validateCardNumber()) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                      'cardNumber', _cardNumberController.text);
                  await prefs.setString(
                      'expiryDate', _expiryDateController.text);
                  await prefs.setString('cvv', _cvvController.text);

                  try {
                    await DatabaseHelper.addPoints(
                      userId: widget.userId, // Funkcja oczekuje String
                      amount: _calculateFinalPrice(),
                      reason: "Kupno biletu", // Przekazujemy nowy, opcjonalny parametr
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Punkty dodane pomyślnie!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Błąd podczas dodawania punktów: $e')),
                    );
                  }

                  Navigator.pop(context, {
                    'confirmed': true,
                    'ticketType': _selectedTicketType,
                    'finalPrice': _calculateFinalPrice(), 
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.blue[50],
              ),
              child: const Text(
                'Zapisz się i zapłać',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, {'confirmed': false}),
              child: const Text('Anuluj'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }
}
