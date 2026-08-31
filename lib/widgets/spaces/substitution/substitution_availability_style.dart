import 'package:flutter/material.dart';

import '../../../domain/models/substitution_participant.dart';

String substitutionAvailabilityLabel(SubstitutionAvailability availability) {
  return switch (availability) {
    SubstitutionAvailability.green => 'Всегда готов!',
    SubstitutionAvailability.yellow => 'Только в день',
    SubstitutionAvailability.red => 'Занят',
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
