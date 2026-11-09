import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/phone_number.dart';

/// Phone input: country-code dropdown (default +251 Ethiopia) and a number
/// box that accepts digits only — letters, spaces, "+", "-", "(", ")" and
/// other punctuation cannot be typed or pasted. Validate with
/// [PhoneNumbers.isValid] and store [PhoneNumbers.toE164].
class PhoneNumberField extends StatelessWidget {
  final TextEditingController controller;
  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final String labelText;
  final bool isAmharic;
  final bool enabled;

  /// Red text under the field (e.g. "not a valid number"); null = none.
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    required this.labelText,
    this.isAmharic = false,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });

  /// Translated reason [digits] can't be accepted for [country], or null if
  /// it's fine. An empty field is an error only when [required].
  static String? validate(PhoneCountry country, String digits, {required bool isAmharic, bool required = true}) {
    final am = isAmharic;
    if (digits.isEmpty) {
      if (!required) return null;
      return am ? 'የስልክ ቁጥር ያስፈልጋል።' : 'Phone number is required.';
    }
    if (PhoneNumbers.isValid(country, digits)) return null;
    if (country.dialCode == PhoneNumbers.ethiopia.dialCode) {
      return am
          ? 'ትክክለኛ የኢትዮጵያ ሞባይል ቁጥር ያስገቡ፦ በ9 ወይም በ7 የሚጀምር 9 አሃዝ (ለምሳሌ 912345678)።'
          : 'Enter a valid Ethiopian mobile number: 9 digits starting with 9 or 7 (e.g. 912345678).';
    }
    final len = country.minDigits == country.maxDigits
        ? '${country.minDigits}'
        : '${country.minDigits}–${country.maxDigits}';
    return am
        ? 'ለ${country.nameAm} ($len አሃዝ) ትክክለኛ ቁጥር ያስገቡ (ለምሳሌ ${country.example})።'
        : 'Enter a valid ${country.nameEn} number ($len digits, e.g. ${country.example}).';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: DropdownButtonFormField<String>(
            initialValue: country.dialCode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: isAmharic ? 'ኮድ' : 'Code',
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            ),
            // Closed: just flag + code. Open: full country names.
            selectedItemBuilder: (_) => [
              for (final c in PhoneNumbers.countries)
                Text('${c.flag} ${c.dialCode}', overflow: TextOverflow.ellipsis),
            ],
            items: [
              for (final c in PhoneNumbers.countries)
                DropdownMenuItem(
                  value: c.dialCode,
                  child: Text(
                    '${c.flag} ${c.dialCode}  ${isAmharic ? c.nameAm : c.nameEn}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: enabled
                ? (code) {
                    if (code == null) return;
                    final next = PhoneNumbers.countries.firstWhere((c) => c.dialCode == code);
                    // Trim anything longer than the new country allows.
                    final max = PhoneNumbers.maxInputLength(next);
                    if (controller.text.length > max) {
                      controller.text = controller.text.substring(0, max);
                    }
                    onCountryChanged(next);
                  }
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(PhoneNumbers.maxInputLength(country)),
            ],
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: country.example,
              errorText: errorText,
              errorMaxLines: 3,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
        ),
      ],
    );
  }
}
