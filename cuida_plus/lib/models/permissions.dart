/// Permissões granulares que o paciente concede ao familiar.
class Permission {
  static const viewMedications = 'canViewMedications';
  static const viewSchedules = 'canViewSchedules';
  static const viewHistory = 'canViewHistory';
  static const receiveNotifications = 'canReceiveNotifications';
  static const viewConsultations = 'canViewConsultations';

  static const labels = <String, String>{
    viewMedications: 'Ver medicamentos',
    viewSchedules: 'Ver horários',
    viewHistory: 'Ver histórico',
    receiveNotifications: 'Receber notificações',
    viewConsultations: 'Ver consultas',
  };
}
