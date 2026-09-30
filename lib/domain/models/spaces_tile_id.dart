enum SpacesTileId { chats, substitution, vesselCalls, calendar, buses, safety }

extension SpacesTileIdPresentation on SpacesTileId {
  String get title {
    return switch (this) {
      SpacesTileId.chats => 'Чаты',
      SpacesTileId.substitution => 'Список',
      SpacesTileId.vesselCalls => 'Судозаходы',
      SpacesTileId.calendar => 'Календарь смен',
      SpacesTileId.buses => 'Автобусы',
      SpacesTileId.safety => 'ОТ и ТБ',
    };
  }
}
