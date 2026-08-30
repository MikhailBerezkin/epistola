import 'package:flutter/material.dart';

import '../../../domain/models/substitution_participant.dart';

String substitutionAvailabilityLabel(SubstitutionAvailability availability) {
  return switch (availability) {
    SubstitutionAvailability.green => 'Готов',
    SubstitutionAvailability.yellow => 'Не в приоритете',
    SubstitutionAvailability.red => 'Не вызывать',
  };
}

Color substitutionAvailabilityColor(SubstitutionAvailability availability) {
  return switch (availability) {
    SubstitutionAvailability.green => Colors.green,
    SubstitutionAvailability.yellow => Colors.amber,
    SubstitutionAvailability.red => Colors.red,
  };
}

Color substitutionAvailabilityTextColor(SubstitutionAvailability availability) {
  return switch (availability) {
    SubstitutionAvailability.green => Colors.white,
    SubstitutionAvailability.yellow => Colors.black87,
    SubstitutionAvailability.red => Colors.white,
  };
}
