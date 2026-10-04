import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";

const vesselCallsIngestToken =
  defineSecret("VESSEL_CALLS_INGEST_TOKEN");

interface VesselCallPayload {
  id: string;
  vesselImo: string;
  vesselName: string;
  lineName: string;
  vesselType: string;
  operationKind: string;
  lane: number;
  berthFrom: string;
  berthTo: string;
  updatedAt: string;
  source: string;
}

interface VesselMonthPayload {
  year: number;
  month: number;
  revision: number;
  publishedUntil: string | null;
  calls: VesselCallPayload[];
  sourceUpdatedAt: string;
  locallyUpdatedAt: string;
  isArchived: boolean;
}

/**
 * Checks whether a value is a plain record.
 * @param {unknown} value Candidate value.
 * @return {boolean} Whether the value is a record.
 */
function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

/**
 * Reads a bearer token from the Authorization header.
 * @param {string|undefined} authorizationHeader Raw header value.
 * @return {string|null} Bearer token or null.
 */
function readHeaderToken(
  authorizationHeader: string | undefined,
): string | null {
  if (
    typeof authorizationHeader !== "string" ||
    !authorizationHeader.startsWith("Bearer ")
  ) {
    return null;
  }

  const token = authorizationHeader
    .slice("Bearer ".length)
    .trim();

  return token.length > 0 ? token : null;
}

/**
 * Reads a required string field.
 * @param {unknown} value Candidate field value.
 * @param {string} fieldName Field name for diagnostics.
 * @return {string} Validated non-empty string.
 */
function readRequiredString(
  value: unknown,
  fieldName: string,
): string {
  if (
    typeof value !== "string" ||
    value.trim().length === 0
  ) {
    throw new Error(
      `Field ${fieldName} must be a non-empty string.`,
    );
  }

  return value;
}

/**
 * Reads an optional string field.
 * @param {unknown} value Candidate field value.
 * @param {string} fieldName Field name for diagnostics.
 * @return {string|null} Validated string or null.
 */
function readOptionalString(
  value: unknown,
  fieldName: string,
): string | null {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value !== "string") {
    throw new Error(
      `Field ${fieldName} must be a string or null.`,
    );
  }

  return value;
}

/**
 * Reads an integer field.
 * @param {unknown} value Candidate field value.
 * @param {string} fieldName Field name for diagnostics.
 * @return {number} Validated integer value.
 */
function readInteger(
  value: unknown,
  fieldName: string,
): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value)
  ) {
    throw new Error(
      `Field ${fieldName} must be an integer.`,
    );
  }

  return value;
}

/**
 * Reads a boolean field.
 * @param {unknown} value Candidate field value.
 * @param {string} fieldName Field name for diagnostics.
 * @return {boolean} Validated boolean value.
 */
function readBoolean(
  value: unknown,
  fieldName: string,
): boolean {
  if (typeof value !== "boolean") {
    throw new Error(
      `Field ${fieldName} must be a boolean.`,
    );
  }

  return value;
}

/**
 * Parses one vessel call payload.
 * @param {unknown} value Raw call payload.
 * @param {number} index Call index for diagnostics.
 * @return {VesselCallPayload} Validated vessel call.
 */
function readCall(
  value: unknown,
  index: number,
): VesselCallPayload {
  if (!isRecord(value)) {
    throw new Error(
      `Call ${index} must be an object.`,
    );
  }

  return {
    id: readRequiredString(
      value.id,
      `calls[${index}].id`,
    ),
    vesselImo: readRequiredString(
      value.vesselImo,
      `calls[${index}].vesselImo`,
    ),
    vesselName: readRequiredString(
      value.vesselName,
      `calls[${index}].vesselName`,
    ),
    lineName: readRequiredString(
      value.lineName,
      `calls[${index}].lineName`,
    ),
    vesselType: readRequiredString(
      value.vesselType,
      `calls[${index}].vesselType`,
    ),
    operationKind: readRequiredString(
      value.operationKind,
      `calls[${index}].operationKind`,
    ),
    lane: readInteger(
      value.lane,
      `calls[${index}].lane`,
    ),
    berthFrom: readRequiredString(
      value.berthFrom,
      `calls[${index}].berthFrom`,
    ),
    berthTo: readRequiredString(
      value.berthTo,
      `calls[${index}].berthTo`,
    ),
    updatedAt: readRequiredString(
      value.updatedAt,
      `calls[${index}].updatedAt`,
    ),
    source: readRequiredString(
      value.source,
      `calls[${index}].source`,
    ),
  };
}

/**
 * Parses one monthly vessel calls payload.
 * @param {unknown} value Raw request body.
 * @return {VesselMonthPayload} Validated month payload.
 */
function readMonthPayload(
  value: unknown,
): VesselMonthPayload {
  if (!isRecord(value)) {
    throw new Error("Request body must be an object.");
  }

  const rawCalls = value.calls;

  if (!Array.isArray(rawCalls)) {
    throw new Error("Field calls must be an array.");
  }

  const year = readInteger(
    value.year,
    "year",
  );

  const month = readInteger(
    value.month,
    "month",
  );

  const revision = readInteger(
    value.revision,
    "revision",
  );

  if (month < 1 || month > 12) {
    throw new Error(
      "Field month must be between 1 and 12.",
    );
  }

  if (revision < 0) {
    throw new Error(
      "Field revision must be non-negative.",
    );
  }

  return {
    year,
    month,
    revision,
    publishedUntil: readOptionalString(
      value.publishedUntil,
      "publishedUntil",
    ),
    calls: rawCalls.map(
      (call, index) => readCall(call, index),
    ),
    sourceUpdatedAt: readRequiredString(
      value.sourceUpdatedAt,
      "sourceUpdatedAt",
    ),
    locallyUpdatedAt: readRequiredString(
      value.locallyUpdatedAt,
      "locallyUpdatedAt",
    ),
    isArchived: readBoolean(
      value.isArchived,
      "isArchived",
    ),
  };
}

/**
 * Builds a canonical YYYY-MM month document ID.
 * @param {number} year Four-digit year.
 * @param {number} month Month number from 1 to 12.
 * @return {string} Canonical month ID.
 */
function monthIdFor(
  year: number,
  month: number,
): string {
  return (
    `${year.toString().padStart(4, "0")}-` +
    `${month.toString().padStart(2, "0")}`
  );
}

export const ingestVesselCallsMonth = onRequest(
  {
    region: "europe-west1",
    secrets: [vesselCallsIngestToken],
  },
  async (request, response) => {
    try {
      if (request.method !== "POST") {
        response.status(405).json({
          ok: false,
          error: "method-not-allowed",
        });

        return;
      }

      const receivedToken = readHeaderToken(
        request.header("authorization"),
      );

      const expectedToken =
        vesselCallsIngestToken.value();

      if (
        receivedToken === null ||
        receivedToken !== expectedToken
      ) {
        response.status(401).json({
          ok: false,
          error: "unauthorized",
        });

        return;
      }

      const payload = readMonthPayload(
        request.body,
      );

      const monthId = monthIdFor(
        payload.year,
        payload.month,
      );

      const firestore = getFirestore();

      const moduleDocument = firestore
        .collection("spaces")
        .doc("vesselCalls");

      const metaReference = moduleDocument
        .collection("monthMeta")
        .doc(monthId);

      const snapshotReference = moduleDocument
        .collection("monthSnapshots")
        .doc(monthId);

      const now = Timestamp.now();

      const metaData = {
        year: payload.year,
        month: payload.month,
        revision: payload.revision,
        callCount: payload.calls.length,
        publishedUntil: payload.publishedUntil,
        updatedAt: now,
      };

      const snapshotData = {
        year: payload.year,
        month: payload.month,
        revision: payload.revision,
        publishedUntil: payload.publishedUntil,
        calls: payload.calls,
        sourceUpdatedAt: payload.sourceUpdatedAt,
        locallyUpdatedAt: payload.locallyUpdatedAt,
        isArchived: payload.isArchived,
      };

      const batch = firestore.batch();

      batch.set(
        metaReference,
        metaData,
        {merge: true},
      );

      batch.set(
        snapshotReference,
        snapshotData,
      );

      await batch.commit();

      logger.info(
        "Vessel calls month ingested",
        {
          monthId,
          revision: payload.revision,
          calls: payload.calls.length,
        },
      );

      response.status(200).json({
        ok: true,
        monthId,
        revision: payload.revision,
        calls: payload.calls.length,
      });
    } catch (error) {
      logger.error(
        "Vessel calls month ingest failed",
        {
          error:
            error instanceof Error ?
              error.message :
              String(error),
        },
      );

      response.status(400).json({
        ok: false,
      });
    }
  },
);
