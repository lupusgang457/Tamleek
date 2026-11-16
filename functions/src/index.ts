import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { fileTypeFromBuffer } from "file-type";
import { error as logError } from "firebase-functions/logger";
import { HttpsError, onCall } from "firebase-functions/v2/https";

if (getApps().length === 0) {
  initializeApp();
}

const firestore = getFirestore();
const maxDocumentSize = 5 * 1024 * 1024;
const allowedImageTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

function requiredText(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return normalized;
}

export const submitKyc = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before submitting KYC.");
  }

  const firstName = requiredText(request.data?.firstName, "firstName", 80);
  const lastName = requiredText(request.data?.lastName, "lastName", 80);
  const birthYear = request.data?.birthYear;
  const currentYear = new Date().getUTCFullYear();
  if (
    !Number.isInteger(birthYear) ||
    birthYear < 1900 ||
    birthYear > currentYear
  ) {
    throw new HttpsError("invalid-argument", "birthYear is invalid.");
  }
  const birthPlace = requiredText(request.data?.birthPlace, "birthPlace", 120);
  const city = requiredText(request.data?.city, "city", 120);
  const department = requiredText(request.data?.department, "department", 120);
  const country = requiredText(request.data?.country, "country", 120);
  const identityNumber = requiredText(
    request.data?.identityNumber,
    "identityNumber",
    80,
  );
  const documentPath = request.data?.documentPath;
  const documentPrefix = `kycDocuments/${uid}/`;
  if (typeof documentPath !== "string" || !documentPath.startsWith(documentPrefix)) {
    throw new HttpsError("invalid-argument", "Identity document path is invalid.");
  }
  const documentId = documentPath.slice(documentPrefix.length);
  if (!/^[0-9]+-[0-9]+$/.test(documentId)) {
    throw new HttpsError("invalid-argument", "Identity document path is invalid.");
  }

  const document = getStorage().bucket().file(documentPath);
  const [exists] = await document.exists();
  if (!exists) {
    throw new HttpsError(
      "failed-precondition",
      "Upload the identity document before submitting KYC.",
    );
  }
  const [metadata] = await document.getMetadata();
  const documentSize = Number(metadata.size);
  const [documentBytes] = await document.download();
  const actualImageType = await fileTypeFromBuffer(documentBytes);
  if (
    !Number.isFinite(documentSize) ||
    documentSize <= 0 ||
    documentSize > maxDocumentSize ||
    !actualImageType ||
    !allowedImageTypes.has(actualImageType.mime) ||
    metadata.contentType !== actualImageType.mime
  ) {
    throw new HttpsError(
      "invalid-argument",
      "The identity document must be a JPEG, PNG or WebP image up to 5 MB.",
    );
  }

  const submission = firestore.collection("kycSubmissions").doc(uid);
  const previousDocumentPath = await firestore.runTransaction(
    async (transaction) => {
      const existing = await transaction.get(submission);
      if (existing.data()?.status === "verified") {
        throw new HttpsError(
          "failed-precondition",
          "This account has already passed KYC verification.",
        );
      }
      if (existing.data()?.status === "pending") {
        throw new HttpsError(
          "failed-precondition",
          "The existing KYC submission is still under review.",
        );
      }
      transaction.set(submission, {
        uid,
        firstName,
        lastName,
        birthYear,
        birthPlace,
        city,
        department,
        country,
        identityNumber,
        documentPath,
        status: "pending",
        submittedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return existing.data()?.documentPath;
    },
  );
  if (
    typeof previousDocumentPath === "string" &&
    previousDocumentPath.startsWith(documentPrefix) &&
    previousDocumentPath !== documentPath
  ) {
    try {
      await getStorage().bucket().file(previousDocumentPath).delete();
    } catch (error) {
      logError("Could not delete the superseded KYC identity image.", error);
    }
  }

  return { status: "pending" };
});
