import { SafetyBreakdown } from "./types";

export function calculateSafetyScore(breakdown: SafetyBreakdown): number {
  const brakingPenalty = breakdown.suddenBrakingEvents * 4;
  const fallPenalty = breakdown.fallsDetected * 22;
  const geofencePenalty = breakdown.geofenceBreaches * 8;
  const maintenancePenalty = Math.max(0, 92 - breakdown.maintenanceHealth);

  const weighted = Math.floor(
    breakdown.speedZoneCompliance * 0.5 +
      breakdown.maintenanceHealth * 0.25 +
      (100 - brakingPenalty) * 0.15 +
      (100 - geofencePenalty - fallPenalty - maintenancePenalty) * 0.1
  );

  return clamp(weighted, 45, 100);
}

export function calculateRidePoints(distanceMiles: number, safetyScore: number): number {
  const safetyMultiplier = Math.max(0.7, safetyScore / 100.0);
  const base = distanceMiles * 22.0;
  return Math.floor(base * safetyMultiplier);
}

export function pointsToCoins(points: number): number {
  return Math.max(1, Math.floor(points / 10));
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}
