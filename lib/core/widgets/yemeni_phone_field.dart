import 'package:flutter/material.dart';
import '../services/contacts_picker_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class YemeniPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isRequired;
  final ValueChanged<ContactPicked>? onContactPicked;
  final ValueChanged<String>? onChanged;

  const YemeniPhoneField({
    super.key,
    required this.controller,
    this.label = 'رقم الهاتف / الاتصال',
    this.hint = '777 123 456',
    this.isRequired = false,
    this.onContactPicked,
    this.onChanged,
  });

  @override
  State<YemeniPhoneField> createState() => _YemeniPhoneFieldState();
}

class _YemeniPhoneFieldState extends State<YemeniPhoneField> {
  String? _carrier;

  @override
  void initState() {
    super.initState();
    _updateCarrier();
    widget.controller.addListener(_updateCarrier);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateCarrier);
    super.dispose();
  }

  void _updateCarrier() {
    final carrier = Validators.getYemeniCarrier(widget.controller.text);
    if (_carrier != carrier) {
      if (mounted) {
        setState(() {
          _carrier = carrier;
        });
      }
    }
  }

  Color _getCarrierColor(String carrier) {
    if (carrier.contains('يمن موبايل')) return const Color(0xFF16A34A); // Green
    if (carrier.contains('يو')) return const Color(0xFFD97706);         // Gold / Yellow
    if (carrier.contains('سبأفون')) return const Color(0xFF0284C7);      // Blue
    if (carrier.contains('واي')) return const Color(0xFF9333EA);         // Purple
    return const Color(0xFF475569);                                     // Slate for Landline
  }

  IconData _getCarrierIcon(String carrier) {
    if (carrier.contains('ثابت')) return Icons.phone_in_talk_rounded;
    return Icons.sim_card_rounded;
  }

  Future<void> _pickContact() async {
    final contact = await ContactsPickerService.pickContact();
    if (contact != null) {
      final cleaned = Validators.cleanYemeniPhone(contact.phone);
      final formatted = Validators.formatYemeniPhone(cleaned);
      widget.controller.text = formatted;
      widget.onChanged?.call(formatted);
      widget.onContactPicked?.call(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.label}${widget.isRequired ? ' *' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            if (_carrier != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCarrierColor(_carrier!).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _getCarrierColor(_carrier!).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getCarrierIcon(_carrier!), size: 11, color: _getCarrierColor(_carrier!)),
                    const SizedBox(width: 4),
                    Text(
                      _carrier!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getCarrierColor(_carrier!),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.phone,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_rounded, size: 16, color: AppTheme.primaryNavy),
                  SizedBox(width: 4),
                  Text(
                    '+967',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                    tooltip: 'مسح',
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                    },
                  ),
                Tooltip(
                  message: 'فتح جهات الاتصال لاختيار رقم',
                  child: InkWell(
                    onTap: _pickContact,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.contacts_rounded,
                        size: 18,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          validator: (val) {
            if (widget.isRequired && (val == null || val.trim().isEmpty)) {
              return '${widget.label} مطلوب';
            }
            return Validators.yemeniPhone(val);
          },
          onChanged: (val) {
            widget.onChanged?.call(val);
          },
        ),
      ],
    );
  }
}
