export type Severity = 'critical' | 'serious' | 'minor';

export type EmergencyType =
  | 'heart_attack'
  | 'breathing_difficulty'
  | 'choking'
  | 'injury'
  | 'traffic_accident'
  | 'poisoning'
  | 'fall'
  | 'unconsciousness'
  | 'other';

export const EMERGENCY_TYPES: Record<EmergencyType, string> = {
  heart_attack: 'Kalp Krizi',
  breathing_difficulty: 'Nefes Darlığı',
  choking: 'Boğulma',
  injury: 'Yaralanma',
  traffic_accident: 'Trafik Kazası',
  poisoning: 'Zehirlenme',
  fall: 'Düşme',
  unconsciousness: 'Bilinç Kaybı',
  other: 'Diğer',
};

export const HAZARDS: Record<string, string> = {
  fire: 'Yangın',
  traffic: 'Trafik',
  attacker: 'Saldırgan',
  electric: 'Elektrik',
  chemical: 'Kimyasal',
};

export type EmergencyStatus =
  | 'open'
  | 'accepted'
  | 'resolved'
  | 'cancelled'
  | 'expired';

export type CloseReason =
  | 'cancelled'
  | 'expired'
  | 'resolved'
  | 'timeout_1h';

export interface EmergencyDoc {
  id?: string;
  type: EmergencyType;
  severity: Severity;
  location: { latitude: number; longitude: number };
  geohash: string;
  address: string;
  description: string;
  patient?: {
    gender?: 'Kadın' | 'Erkek' | 'Belirtilmemiş';
    age?: number;
    consciousness?: 'Açık' | 'Kapalı' | 'Bilinmiyor';
    breathing?: 'Var' | 'Yok' | 'Zor' | 'Bilinmiyor';
  };
  contactPhone?: string;
  hazards: string[];
  region: { country: string; city: string; district: string };
  status: EmergencyStatus;
  waveLevel: number;
  acceptedBy: string[];
  closedAt?: unknown;
  closedBy?: string;
  closeReason?: CloseReason;
  createdAt?: unknown;
}
