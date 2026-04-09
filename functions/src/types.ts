export type UserRole = "parent" | "child";

export interface SafetyBreakdown {
  speedZoneCompliance: number;
  suddenBrakingEvents: number;
  fallsDetected: number;
  maintenanceHealth: number;
  geofenceBreaches: number;
}

export interface RideTelemetryPayload {
  familyId: string;
  childUserId: string;
  date?: string;
  distanceMiles: number;
  durationMinutes: number;
  averageSpeedMph: number;
  maxSpeedMph: number;
  speedZoneCompliance: number;
  suddenBrakingEvents: number;
  fallsDetected: number;
  maintenanceHealth: number;
  geofenceBreaches: number;
}
