import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { calculateRidePoints, calculateSafetyScore, pointsToCoins } from "./scoring";
import { RideTelemetryPayload, SafetyBreakdown, UserRole } from "./types";

admin.initializeApp();
const db = admin.firestore();

interface UserProfile {
  role: UserRole;
  familyId: string;
  displayName?: string;
  deviceTokens?: string[];
  managedChildUserId?: string;
}

export const submitRideTelemetry = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const payload = request.data as RideTelemetryPayload;
  const user = await getUserProfile(uid);

  if (user.role !== "child") {
    throw new HttpsError("permission-denied", "Only child accounts can submit rides.");
  }
  if (payload.childUserId !== uid || payload.familyId !== user.familyId) {
    throw new HttpsError("permission-denied", "Ride family ownership mismatch.");
  }

  validateRidePayload(payload);

  const breakdown: SafetyBreakdown = {
    speedZoneCompliance: payload.speedZoneCompliance,
    suddenBrakingEvents: payload.suddenBrakingEvents,
    fallsDetected: payload.fallsDetected,
    maintenanceHealth: payload.maintenanceHealth,
    geofenceBreaches: payload.geofenceBreaches
  };

  const safetyScore = calculateSafetyScore(breakdown);
  const pointsEarned = calculateRidePoints(payload.distanceMiles, safetyScore);
  const virtualCoinsEarned = pointsToCoins(pointsEarned);
  const rideRef = db.collection("ride_telemetry").doc();

  await db.runTransaction(async (tx) => {
    tx.set(rideRef, {
      familyId: payload.familyId,
      childUserId: payload.childUserId,
      date: payload.date ? admin.firestore.Timestamp.fromDate(new Date(payload.date)) : admin.firestore.FieldValue.serverTimestamp(),
      distanceMiles: payload.distanceMiles,
      durationMinutes: payload.durationMinutes,
      averageSpeedMph: payload.averageSpeedMph,
      maxSpeedMph: payload.maxSpeedMph,
      speedZoneCompliance: payload.speedZoneCompliance,
      suddenBrakingEvents: payload.suddenBrakingEvents,
      fallsDetected: payload.fallsDetected,
      maintenanceHealth: payload.maintenanceHealth,
      geofenceBreaches: payload.geofenceBreaches,
      safetyScore,
      pointsEarned,
      virtualCoinsEarned,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const walletRef = db.collection("wallets").doc(payload.childUserId);
    tx.set(
      walletRef,
      {
        familyId: payload.familyId,
        childUserId: payload.childUserId,
        balanceCoins: admin.firestore.FieldValue.increment(virtualCoinsEarned),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    const transactionRef = db.collection("wallet_transactions").doc();
    tx.set(transactionRef, {
      familyId: payload.familyId,
      childUserId: payload.childUserId,
      parentUserId: null,
      amount: virtualCoinsEarned,
      type: "earn",
      reason: "Ride completion reward",
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  return {
    rideId: rideRef.id,
    safetyScore,
    pointsEarned,
    virtualCoinsEarned
  };
});

export const redeemReward = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const parent = await getUserProfile(uid);
  if (parent.role !== "parent") {
    throw new HttpsError("permission-denied", "Only parents can redeem rewards.");
  }

  const childUserId = request.data?.childUserId as string;
  const coinCost = Number(request.data?.coinCost ?? 0);
  const itemTitle = String(request.data?.itemTitle ?? "Reward");

  if (!childUserId || coinCost <= 0) {
    throw new HttpsError("invalid-argument", "childUserId and coinCost are required.");
  }

  const child = await getUserProfile(childUserId);
  if (child.familyId !== parent.familyId) {
    throw new HttpsError("permission-denied", "Child is not in parent family.");
  }

  const walletRef = db.collection("wallets").doc(childUserId);
  const transactionRef = db.collection("wallet_transactions").doc();

  await db.runTransaction(async (tx) => {
    const walletSnap = await tx.get(walletRef);
    const balance = Number(walletSnap.data()?.balanceCoins ?? 0);
    if (balance < coinCost) {
      throw new HttpsError("failed-precondition", "Insufficient virtual coins.");
    }

    tx.set(
      walletRef,
      {
        familyId: parent.familyId,
        childUserId,
        balanceCoins: balance - coinCost,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    tx.set(transactionRef, {
      familyId: parent.familyId,
      childUserId,
      parentUserId: uid,
      amount: -coinCost,
      type: "redeem",
      reason: `Parent redeemed ${itemTitle}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  return {
    transactionId: transactionRef.id,
    itemTitle,
    amount: -coinCost
  };
});

export const acknowledgeGeofenceAlert = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const user = await getUserProfile(uid);
  if (user.role !== "parent") {
    throw new HttpsError("permission-denied", "Only parents can acknowledge alerts.");
  }

  const alertId = request.data?.alertId as string;
  if (!alertId) {
    throw new HttpsError("invalid-argument", "alertId is required.");
  }

  const alertRef = db.collection("geofence_alerts").doc(alertId);
  const alert = await alertRef.get();
  if (!alert.exists) {
    throw new HttpsError("not-found", "Alert not found.");
  }
  const alertFamilyId = alert.data()?.familyId as string;
  if (alertFamilyId !== user.familyId) {
    throw new HttpsError("permission-denied", "Alert does not belong to this family.");
  }

  await alertRef.set(
    {
      acknowledged: true,
      acknowledgedAt: admin.firestore.FieldValue.serverTimestamp(),
      acknowledgedBy: uid
    },
    { merge: true }
  );

  return { success: true };
});

export const requestHelp = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const child = await getUserProfile(uid);
  if (child.role !== "child") {
    throw new HttpsError("permission-denied", "Only child accounts can request help.");
  }

  const message = String(request.data?.message ?? "I need help right now.");
  const urgency = String(request.data?.urgency ?? "high");
  const latitude = Number(request.data?.latitude ?? NaN);
  const longitude = Number(request.data?.longitude ?? NaN);
  const horizontalAccuracyMeters = Number(request.data?.horizontalAccuracyMeters ?? NaN);

  const requestRef = db.collection("help_requests").doc();
  await requestRef.set({
    familyId: child.familyId,
    childUserId: uid,
    message,
    urgency,
    status: "pending",
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
    latitude: Number.isFinite(latitude) ? latitude : null,
    longitude: Number.isFinite(longitude) ? longitude : null,
    horizontalAccuracyMeters: Number.isFinite(horizontalAccuracyMeters) ? horizontalAccuracyMeters : null
  });

  return { requestId: requestRef.id };
});

export const acknowledgeHelpRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const parent = await getUserProfile(uid);
  if (parent.role !== "parent") {
    throw new HttpsError("permission-denied", "Only parent accounts can acknowledge help requests.");
  }

  const requestId = String(request.data?.requestId ?? "");
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }

  const helpRef = db.collection("help_requests").doc(requestId);
  const helpSnap = await helpRef.get();
  if (!helpSnap.exists) {
    throw new HttpsError("not-found", "Help request not found.");
  }
  const familyId = String(helpSnap.data()?.familyId ?? "");
  if (familyId !== parent.familyId) {
    throw new HttpsError("permission-denied", "Help request does not belong to this family.");
  }

  await helpRef.set(
    {
      status: "acknowledged",
      acknowledgedBy: uid,
      acknowledgedAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

  return { success: true };
});

export const processBadgesOnRide = onDocumentCreated("ride_telemetry/{rideId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const familyId = String(data.familyId ?? "");
  const childUserId = String(data.childUserId ?? "");
  if (!familyId || !childUserId) return;

  const ridesSnap = await db
    .collection("ride_telemetry")
    .where("familyId", "==", familyId)
    .where("childUserId", "==", childUserId)
    .get();

  const rides = ridesSnap.docs.map((doc) => doc.data());
  const totalDistance = rides.reduce((sum, ride) => sum + Number(ride.distanceMiles ?? 0), 0);
  const bestSafety = rides.reduce((max, ride) => Math.max(max, Number(ride.safetyScore ?? 0)), 0);
  const totalCoins = rides.reduce((sum, ride) => sum + Number(ride.virtualCoinsEarned ?? 0), 0);
  const hasAnyRide = rides.length > 0;

  const badges = [
    {
      id: `${childUserId}_first_wheel_win`,
      title: "First Wheel Win",
      subtitle: "Complete your first tracked ride",
      icon: "star.fill",
      unlocked: hasAnyRide
    },
    {
      id: `${childUserId}_road_ranger`,
      title: "Road Ranger",
      subtitle: "Ride 75 miles this year",
      icon: "figure.outdoor.cycle.circle.fill",
      unlocked: totalDistance >= 75
    },
    {
      id: `${childUserId}_safety_champ`,
      title: "Safety Champ",
      subtitle: "Hit a 95+ safety score",
      icon: "checkmark.shield.fill",
      unlocked: bestSafety >= 95
    },
    {
      id: `${childUserId}_coin_collector`,
      title: "Coin Collector",
      subtitle: "Earn 500 virtual coins",
      icon: "dollarsign.circle.fill",
      unlocked: totalCoins >= 500
    }
  ];

  const batch = db.batch();
  badges.forEach((badge) => {
    const ref = db.collection("badges").doc(badge.id);
    batch.set(
      ref,
      {
        familyId,
        childUserId,
        title: badge.title,
        subtitle: badge.subtitle,
        icon: badge.icon,
        isUnlocked: badge.unlocked,
        unlockedAt: badge.unlocked ? admin.firestore.FieldValue.serverTimestamp() : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
  });
  await batch.commit();
});

export const notifyParentsOnGeofenceAlert = onDocumentCreated("geofence_alerts/{alertId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const familyId = String(data.familyId ?? "");
  const message = String(data.message ?? "Geofence alert");
  const zoneName = String(data.zoneName ?? "Geofence");
  if (!familyId) return;

  const parentsSnap = await db
    .collection("users")
    .where("familyId", "==", familyId)
    .where("role", "==", "parent")
    .get();

  const tokens = parentsSnap.docs.flatMap((doc) => {
    const profile = doc.data() as UserProfile;
    return profile.deviceTokens ?? [];
  });

  if (tokens.length === 0) {
    logger.info("No parent device tokens found", { familyId });
    return;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: `KidRide Alert: ${zoneName}`,
      body: message
    },
    data: {
      familyId,
      zoneName
    }
  });

  logger.info("Geofence push sent", {
    familyId,
    sent: response.successCount,
    failed: response.failureCount
  });
});

export const notifyParentsOnHelpRequest = onDocumentCreated("help_requests/{requestId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const familyId = String(data.familyId ?? "");
  const message = String(data.message ?? "Your child requested help.");
  const urgency = String(data.urgency ?? "high");
  if (!familyId) return;

  const parentsSnap = await db
    .collection("users")
    .where("familyId", "==", familyId)
    .where("role", "==", "parent")
    .get();

  const tokens = parentsSnap.docs.flatMap((doc) => {
    const profile = doc.data() as UserProfile;
    return profile.deviceTokens ?? [];
  });

  if (tokens.length === 0) {
    logger.info("No parent tokens for help request", { familyId });
    return;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: `Emergency Help (${urgency.toUpperCase()})`,
      body: message
    },
    data: {
      familyId,
      urgency
    }
  });

  logger.info("Help request push sent", {
    familyId,
    sent: response.successCount,
    failed: response.failureCount
  });
});

async function getUserProfile(uid: string): Promise<UserProfile> {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("failed-precondition", "User profile document missing.");
  }
  const data = snap.data() as UserProfile | undefined;
  if (!data?.role || !data.familyId) {
    throw new HttpsError("failed-precondition", "User profile is incomplete.");
  }
  return data;
}

function validateRidePayload(payload: RideTelemetryPayload): void {
  if (payload.distanceMiles <= 0 || payload.distanceMiles > 100) {
    throw new HttpsError("invalid-argument", "distanceMiles is out of valid range.");
  }
  if (payload.durationMinutes <= 0 || payload.durationMinutes > 600) {
    throw new HttpsError("invalid-argument", "durationMinutes is out of valid range.");
  }
  if (payload.averageSpeedMph <= 0 || payload.maxSpeedMph <= 0) {
    throw new HttpsError("invalid-argument", "Speed values must be positive.");
  }
}
