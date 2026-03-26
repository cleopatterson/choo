import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { google, calendar_v3 } from "googleapis";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ── Google Calendar secrets ──────────────────────────────
const calendarSAKey = defineSecret("GOOGLE_CALENDAR_SA_KEY");
const calendarId = defineSecret("GOOGLE_CALENDAR_ID");

// ── GitHub secrets ──────────────────────────────────────
const githubToken = defineSecret("GITHUB_TOKEN");

function getCalendarClient(saKeyJson: string): calendar_v3.Calendar {
  const key = JSON.parse(saKeyJson);
  const auth = new google.auth.JWT(
    key.client_email,
    undefined,
    key.private_key,
    ["https://www.googleapis.com/auth/calendar"]
  );
  return google.calendar({ version: "v3", auth });
}

// ── Google Calendar sync helpers ─────────────────────────

const SYDNEY_TZ = "Australia/Sydney";

function toRRule(frequency: string, endDate?: Date): string[] {
  const freqMap: Record<string, string> = {
    daily: "DAILY",
    weekly: "WEEKLY",
    fortnightly: "WEEKLY;INTERVAL=2",
    monthly: "MONTHLY",
    yearly: "YEARLY",
  };
  const rruleFreq = freqMap[frequency];
  if (!rruleFreq) return [];
  let rule = `RRULE:FREQ=${rruleFreq}`;
  if (endDate) {
    const y = endDate.getFullYear();
    const m = String(endDate.getMonth() + 1).padStart(2, "0");
    const d = String(endDate.getDate()).padStart(2, "0");
    rule += `;UNTIL=${y}${m}${d}`;
  }
  return [rule];
}

function firestoreTimestampToDate(raw: unknown): Date | null {
  if (!raw) return null;
  if (typeof raw === "object" && raw !== null && "_seconds" in raw) {
    return new Date((raw as { _seconds: number })._seconds * 1000);
  }
  if (typeof raw === "string") {
    const d = new Date(raw);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}

function buildGoogleEvent(
  data: Record<string, unknown>
): calendar_v3.Schema$Event {
  const isAllDay = data.isAllDay === true;
  const startDate = firestoreTimestampToDate(data.startDate);
  const endDate = firestoreTimestampToDate(data.endDate);

  const event: calendar_v3.Schema$Event = {
    summary: (data.title as string) || "Choo event",
  };

  if (data.location) event.location = data.location as string;
  if (data.note) event.description = data.note as string;

  if (isAllDay && startDate && endDate) {
    // Google Calendar all-day end date is exclusive, so add 1 day
    const endPlusOne = new Date(endDate);
    endPlusOne.setDate(endPlusOne.getDate() + 1);
    event.start = { date: startDate.toISOString().split("T")[0] };
    event.end = { date: endPlusOne.toISOString().split("T")[0] };
  } else if (startDate && endDate) {
    event.start = { dateTime: startDate.toISOString(), timeZone: SYDNEY_TZ };
    event.end = { dateTime: endDate.toISOString(), timeZone: SYDNEY_TZ };
  }

  if (data.recurrenceFrequency) {
    const recEnd = firestoreTimestampToDate(data.recurrenceEndDate);
    event.recurrence = toRRule(
      data.recurrenceFrequency as string,
      recEnd ?? undefined
    );
  }

  return event;
}

function shouldSyncToGoogle(data: Record<string, unknown>): boolean {
  // Don't sync todos or bills — they don't belong on a shared calendar
  if (data.isTodo === true) return false;
  if (data.isBill === true) return false;
  return true;
}

async function syncCreateToGoogle(
  data: Record<string, unknown>,
  familyId: string,
  eventId: string
): Promise<void> {
  if (!shouldSyncToGoogle(data)) return;

  const cal = getCalendarClient(calendarSAKey.value());
  const gcalId = calendarId.value();
  const event = buildGoogleEvent(data);

  const res = await cal.events.insert({ calendarId: gcalId, requestBody: event });
  const googleEventId = res.data.id;

  if (googleEventId) {
    await db
      .collection("families")
      .doc(familyId)
      .collection("events")
      .doc(eventId)
      .update({ googleCalendarEventId: googleEventId });
  }
}

async function syncUpdateToGoogle(
  data: Record<string, unknown>,
  familyId: string,
  eventId: string
): Promise<void> {
  const cal = getCalendarClient(calendarSAKey.value());
  const gcalId = calendarId.value();
  const googleEventId = data.googleCalendarEventId as string | undefined;

  if (!shouldSyncToGoogle(data)) {
    // If it was previously synced but is now a todo/bill, delete from Google
    if (googleEventId) {
      try {
        await cal.events.delete({ calendarId: gcalId, eventId: googleEventId });
      } catch { /* already deleted */ }
      await db
        .collection("families")
        .doc(familyId)
        .collection("events")
        .doc(eventId)
        .update({ googleCalendarEventId: null });
    }
    return;
  }

  const event = buildGoogleEvent(data);

  if (googleEventId) {
    await cal.events.update({
      calendarId: gcalId,
      eventId: googleEventId,
      requestBody: event,
    });
  } else {
    // First sync for a pre-existing event
    const res = await cal.events.insert({ calendarId: gcalId, requestBody: event });
    if (res.data.id) {
      await db
        .collection("families")
        .doc(familyId)
        .collection("events")
        .doc(eventId)
        .update({ googleCalendarEventId: res.data.id });
    }
  }
}

async function syncDeleteToGoogle(
  data: Record<string, unknown>
): Promise<void> {
  const googleEventId = data.googleCalendarEventId as string | undefined;
  if (!googleEventId) return;

  const cal = getCalendarClient(calendarSAKey.value());
  const gcalId = calendarId.value();

  try {
    await cal.events.delete({ calendarId: gcalId, eventId: googleEventId });
  } catch { /* already deleted */ }
}

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

async function sendPush(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
) {
  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    tokens,
    data: data ?? {},
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

/**
 * Format a Firestore timestamp or date into a readable string like "Wed 11 Mar".
 */
function formatEventDate(raw: unknown): string | null {
  if (!raw) return null;
  let date: Date;
  if (typeof raw === "object" && raw !== null && "_seconds" in raw) {
    date = new Date((raw as { _seconds: number })._seconds * 1000);
  } else if (typeof raw === "string") {
    date = new Date(raw);
  } else {
    return null;
  }
  if (isNaN(date.getTime())) return null;
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  return `${days[date.getDay()]} ${date.getDate()} ${months[date.getMonth()]}`;
}

/**
 * Extract eventDate as epoch seconds string for the push data payload.
 */
function eventDateEpoch(raw: unknown): string | null {
  if (!raw) return null;
  if (typeof raw === "object" && raw !== null && "_seconds" in raw) {
    return String((raw as { _seconds: number })._seconds);
  }
  if (typeof raw === "string") {
    const ms = new Date(raw).getTime();
    return isNaN(ms) ? null : String(ms / 1000);
  }
  return null;
}

// ── Event Created ─────────────────────────────────────────

export const onEventCreated = onDocumentCreated(
  {
    document: "families/{familyId}/events/{eventId}",
    secrets: [calendarSAKey, calendarId],
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const familyId = event.params.familyId;
    const eventId = event.params.eventId;
    const title = data.title || "New event";
    const modifierUID = data.lastModifiedByUID;
    const createdBy = data.createdBy || "Someone";

    const dateLabel = formatEventDate(data.startDate);
    const body = dateLabel
      ? `${createdBy} added "${title}" on ${dateLabel}`
      : `${createdBy} added "${title}"`;

    const pushData: Record<string, string> = {};
    const epoch = eventDateEpoch(data.startDate);
    if (epoch) pushData.eventDate = epoch;

    const tokens = await collectTokens(familyId, modifierUID, "eventCreated");
    await sendPush(tokens, "Choo", body, pushData);

    // Sync to Google Calendar
    try {
      await syncCreateToGoogle(data, familyId, eventId);
    } catch (err) {
      console.error("Google Calendar create sync failed:", err);
    }
  }
);

// ── Event Updated ─────────────────────────────────────────

export const onEventUpdated = onDocumentUpdated(
  {
    document: "families/{familyId}/events/{eventId}",
    secrets: [calendarSAKey, calendarId],
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Skip if only googleCalendarEventId or lastModifiedByUID changed
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
      "isTodo",
      "amount",
      "note",
    ];
    const hasRealChange = fieldsToCompare.some(
      (f) => JSON.stringify(before[f]) !== JSON.stringify(after[f])
    );
    if (!hasRealChange) return;

    const familyId = event.params.familyId;
    const eventId = event.params.eventId;
    const title = after.title || "An event";
    const modifierUID = after.lastModifiedByUID;

    const dateLabel = formatEventDate(after.startDate);
    const body = dateLabel
      ? `"${title}" was updated (${dateLabel})`
      : `"${title}" was updated`;

    const pushData: Record<string, string> = {};
    const epoch = eventDateEpoch(after.startDate);
    if (epoch) pushData.eventDate = epoch;

    const tokens = await collectTokens(familyId, modifierUID, "eventUpdated");
    await sendPush(tokens, "Choo", body, pushData);

    // Sync to Google Calendar
    try {
      await syncUpdateToGoogle(after, familyId, eventId);
    } catch (err) {
      console.error("Google Calendar update sync failed:", err);
    }
  }
);

// ── Event Deleted ─────────────────────────────────────────

export const onEventDeleted = onDocumentDeleted(
  {
    document: "families/{familyId}/events/{eventId}",
    secrets: [calendarSAKey, calendarId],
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const familyId = event.params.familyId;
    const title = data.title || "An event";
    // lastModifiedByUID is still available on the deleted doc snapshot
    const modifierUID = data.lastModifiedByUID;
    const dateLabel = formatEventDate(data.startDate);
    const body = dateLabel
      ? `"${title}" (${dateLabel}) was removed`
      : `"${title}" was removed`;

    const tokens = await collectTokens(familyId, modifierUID, "eventDeleted");
    await sendPush(tokens, "Choo", body);

    // Delete from Google Calendar
    try {
      await syncDeleteToGoogle(data);
    } catch (err) {
      console.error("Google Calendar delete sync failed:", err);
    }
  }
);

// ── Backfill existing events to Google Calendar ──────────

export const backfillGoogleCalendar = onRequest(
  { secrets: [calendarSAKey, calendarId] },
  async (req, res) => {
    const familyId = req.query.familyId as string;
    if (!familyId) {
      res.status(400).send("Missing familyId query parameter");
      return;
    }

    const allEventsSnap = await db
      .collection("families")
      .doc(familyId)
      .collection("events")
      .get();

    const toSync = allEventsSnap.docs.filter((doc) => {
      const data = doc.data();
      return !data.googleCalendarEventId && shouldSyncToGoogle(data);
    });

    let synced = 0;
    let skipped = 0;

    for (const doc of toSync) {
      try {
        await syncCreateToGoogle(doc.data(), familyId, doc.id);
        synced++;
      } catch (err) {
        console.error(`Failed to sync event ${doc.id}:`, err);
        skipped++;
      }
    }

    res.send(`Backfill complete: ${synced} synced, ${skipped} failed, ${allEventsSnap.size - toSync.length} already synced or excluded`);
  }
);

// ── Bug Report → GitHub Issue ───────────────────────────

const GITHUB_OWNER = "cleopatterson";
const GITHUB_REPO = "choo";

export const onBugReportCreated = onDocumentCreated(
  {
    document: "families/{familyId}/bugReports/{reportId}",
    secrets: [githubToken],
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const familyId = event.params.familyId;
    const reportId = event.params.reportId;

    try {
      const response = await fetch(
        `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${githubToken.value()}`,
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            title: `[Bug] ${data.title}`,
            body: [
              `**Severity**: ${data.severity}`,
              `**Reported by**: ${data.createdBy}`,
              "",
              data.description || "_No description provided_",
              "",
              "---",
              `_Firestore: families/${familyId}/bugReports/${reportId}_`,
            ].join("\n"),
            labels: ["bug-report", `severity-${data.severity}`],
          }),
        }
      );

      if (!response.ok) {
        console.error("GitHub API error:", response.status, await response.text());
        return;
      }

      const issue = await response.json();

      // Write issue URL and number back to Firestore
      await db
        .collection("families")
        .doc(familyId)
        .collection("bugReports")
        .doc(reportId)
        .update({
          githubIssueUrl: issue.html_url,
          githubIssueNumber: issue.number,
          status: "inProgress",
          updatedAt: new Date(),
        });

      console.log(`Created GitHub issue #${issue.number} for bug report ${reportId}`);
    } catch (err) {
      console.error("Failed to create GitHub issue:", err);
    }
  }
);

// ── Update Bug Status (called by GitHub Actions) ────────

const webhookSecret = defineSecret("BUG_WEBHOOK_SECRET");

export const updateBugStatus = onRequest(
  { secrets: [webhookSecret] },
  async (req, res) => {
    // Verify shared secret
    const authHeader = req.headers["x-webhook-secret"];
    if (authHeader !== webhookSecret.value()) {
      res.status(403).send("Forbidden");
      return;
    }

    const { familyId, reportId, status } = req.body;
    if (!familyId || !reportId || !status) {
      res.status(400).send("Missing familyId, reportId, or status");
      return;
    }

    try {
      await db
        .collection("families")
        .doc(familyId)
        .collection("bugReports")
        .doc(reportId)
        .update({
          status,
          updatedAt: new Date(),
        });

      console.log(`Updated bug ${reportId} status to ${status}`);
      res.send("OK");
    } catch (err) {
      console.error("Failed to update bug status:", err);
      res.status(500).send("Internal error");
    }
  }
);
