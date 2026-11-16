import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const maxDocumentSize = 5 * 1024 * 1024;
const allowedImageTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

class RequestError extends Error {
  constructor(
    message: string,
    readonly status = 400,
  ) {
    super(message);
  }
}

function respond(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredText(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new RequestError(`${field} is required.`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new RequestError(`${field} is invalid.`);
  }
  return normalized;
}

function imageMime(bytes: Uint8Array): string | null {
  const isPng = bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a;
  if (isPng) return "image/png";

  const isJpeg = bytes.length >= 3 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff;
  if (isJpeg) return "image/jpeg";

  const isWebp = bytes.length >= 12 &&
    String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
    String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
  return isWebp ? "image/webp" : null;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return respond({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return respond({ error: "Sign in before submitting KYC." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Supabase function secrets are not configured.");
    return respond({ error: "KYC service is not configured." }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return respond({ error: "The authentication session is invalid." }, 401);
  }
  const user = userData.user;

  let documentPath: string | null = null;
  let existingDocumentPath: string | null = null;
  try {
    const body: unknown = await request.json();
    if (body === null || typeof body !== "object" || Array.isArray(body)) {
      throw new RequestError("The request body is invalid.");
    }
    const payload = body as Record<string, unknown>;
    documentPath = typeof payload.documentPath === "string"
      ? payload.documentPath
      : null;
    const firstName = requiredText(payload.firstName, "firstName", 80);
    const lastName = requiredText(payload.lastName, "lastName", 80);
    const birthYear = payload.birthYear;
    const currentYear = new Date().getUTCFullYear();
    if (
      typeof birthYear !== "number" ||
      !Number.isInteger(birthYear) ||
      birthYear < 1900 ||
      birthYear > currentYear
    ) {
      throw new RequestError("birthYear is invalid.");
    }
    const birthPlace = requiredText(payload.birthPlace, "birthPlace", 120);
    const city = requiredText(payload.city, "city", 120);
    const department = requiredText(payload.department, "department", 120);
    const country = requiredText(payload.country, "country", 120);
    const identityNumber = requiredText(
      payload.identityNumber,
      "identityNumber",
      80,
    );
    if (
      typeof documentPath !== "string" ||
      !documentPath.startsWith(`${user.id}/`) ||
      !new RegExp(`^${user.id}/[0-9]+-[0-9]+$`).test(documentPath)
    ) {
      throw new RequestError("Identity document path is invalid.");
    }

    const { data: existing, error: existingError } = await adminClient
      .from("kyc_submissions")
      .select("status, document_path")
      .eq("user_id", user.id)
      .maybeSingle();
    if (existingError) throw existingError;
    existingDocumentPath = existing?.document_path ?? null;
    if (existing?.status === "verified") {
      throw new RequestError("This account has already passed KYC.", 409);
    }
    if (existing?.status === "pending") {
      throw new RequestError(
        "The existing KYC submission is under review.",
        409,
      );
    }

    const { data: document, error: downloadError } = await adminClient.storage
      .from("kyc-documents")
      .download(documentPath);
    if (downloadError || !document) {
      throw downloadError ?? new Error("Identity document was not found.");
    }
    if (document.size <= 0 || document.size > maxDocumentSize) {
      throw new RequestError("Identity document must be no larger than 5 MB.");
    }
    const bytes = new Uint8Array(await document.arrayBuffer());
    const actualMime = imageMime(bytes);
    if (
      !actualMime ||
      !allowedImageTypes.has(actualMime) ||
      document.type !== actualMime
    ) {
      throw new RequestError(
        "Identity document must be a valid JPEG, PNG or WebP image.",
      );
    }

    const submission = {
      user_id: user.id,
      first_name: firstName,
      last_name: lastName,
      birth_year: birthYear,
      birth_place: birthPlace,
      city,
      department,
      country,
      identity_number: identityNumber,
      document_path: documentPath,
      status: "pending",
      submitted_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    if (existing) {
      const { data, error } = await adminClient
        .from("kyc_submissions")
        .update(submission)
        .eq("user_id", user.id)
        .eq("status", "rejected")
        .select("user_id")
        .maybeSingle();
      if (error) throw error;
      if (!data) {
        throw new RequestError(
          "The KYC submission changed; please retry.",
          409,
        );
      }
    } else {
      const { error } = await adminClient
        .from("kyc_submissions")
        .insert(submission);
      if (error) throw error;
    }

    return respond({ status: "pending" });
  } catch (error) {
    console.error("KYC submission failed.", error);
    if (
      documentPath !== null &&
      new RegExp(`^${user.id}/[0-9]+-[0-9]+$`).test(documentPath) &&
      documentPath !== existingDocumentPath
    ) {
      try {
        const { error: cleanupError } = await adminClient.storage
          .from("kyc-documents")
          .remove([documentPath]);
        if (cleanupError) {
          console.error(
            "Could not remove the unsubmitted KYC document.",
            cleanupError,
          );
        }
      } catch (cleanupError) {
        console.error(
          "Could not remove the unsubmitted KYC document.",
          cleanupError,
        );
      }
    }
    return error instanceof RequestError
      ? respond({ error: error.message }, error.status)
      : respond({ error: "KYC submission could not be completed." }, 500);
  }
});
