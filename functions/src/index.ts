import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ── Helpers ───────────────────────────────────────────────

interface UserProfile {
  displayName?: string;
  fcmTokens?: Record<string, string>;
  notificationPreferences?: {
    eventCreated?: boolean;
    eventUpdated?: boolean;
    eventDeleted?: boolean;
    shoppingChanges?: boolean;
  };
}

interface FamilyDoc {
  memberUIDs: string[];
}

/**
 * Collect FCM tokens for family members, respecting preferences and
 * excluding the user who made the change.
 */
async function collectTokens(
  familyId: string,
  excludeUID: string | undefined,
  prefKey: keyof NonNullable<UserProfile["notificationPreferences"]>
): Promise<string[]> {
  const familySnap = await db.collection("families").doc(familyId).get();
  const family = familySnap.data() as FamilyDoc | undefined;
  if (!family?.memberUIDs) return [];

  const tokens: string[] = [];

  for (const uid of family.memberUIDs) {
    if (uid === excludeUID) continue;

    const userSnap = await db.collection("users").doc(uid).get();
    const user = userSnap.data() as UserProfile | undefined;
    if (!user?.fcmTokens) continue;

    // nil preferences = all enabled (opt-out model)
    const prefs = user.notificationPreferences;
    if (prefs && prefs[prefKey] === false) continue;

    tokens.push(...Object.values(user.fcmTokens));
  }

  return tokens;
}

async function sendPush(tokens: string[], title: string, body: string) {
  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    tokens,
    apns: {
      payload: {
        aps: { sound: "default" },
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    console.log(
      `Push sent: ${response.successCount} success, ${response.failureCount} failure`
    );
    // Log individual errors so we can diagnose delivery issues
    response.responses.forEach((resp, i) => {
      if (resp.error) {
        console.error(
          `Token[${i}] error: ${resp.error.code} – ${resp.error.message}`
        );
      }
    });
  } catch (err) {
    console.error("Push send error:", err);
  }
}

// ── Event Created ─────────────────────────────────────────

export const onEventCreated = onDocumentCreated(
  "families/{familyId}/events/{eventId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const familyId = event.params.familyId;
    const title = data.title || "New event";
    const modifierUID = data.lastModifiedByUID;
    const createdBy = data.createdBy || "Someone";

    const tokens = await collectTokens(familyId, modifierUID, "eventCreated");
    await sendPush(tokens, "Choo", `${createdBy} added "${title}"`);
  }
);

// ── Event Updated ─────────────────────────────────────────

export const onEventUpdated = onDocumentUpdated(
  "families/{familyId}/events/{eventId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Skip if only lastModifiedByUID changed (no real content change)
    const fieldsToCompare = [
      "title",
      "startDate",
      "endDate",
      "isAllDay",
      "location",
      "recurrenceFrequency",
      "recurrenceEndDate",
      "attendeeUIDs",
      "isBill",
      "amount",
    ];
    const hasRealChange = fieldsToCompare.some(
      (f) => JSON.stringify(before[f]) !== JSON.stringify(after[f])
    );
    if (!hasRealChange) return;

    const familyId = event.params.familyId;
    const title = after.title || "An event";
    const modifierUID = after.lastModifiedByUID;

    const tokens = await collectTokens(familyId, modifierUID, "eventUpdated");
    await sendPush(tokens, "Choo", `"${title}" was updated`);
  }
);

// ── Event Deleted ─────────────────────────────────────────

export const onEventDeleted = onDocumentDeleted(
  "families/{familyId}/events/{eventId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const familyId = event.params.familyId;
    const title = data.title || "An event";
    // lastModifiedByUID is still available on the deleted doc snapshot
    const modifierUID = data.lastModifiedByUID;
    const tokens = await collectTokens(familyId, modifierUID, "eventDeleted");
    await sendPush(tokens, "Choo", `"${title}" was removed`);
  }
);
