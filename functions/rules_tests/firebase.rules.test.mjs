import { readFile } from "node:fs/promises";
import {
  after,
  before,
  describe,
  it,
} from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { ref, uploadBytes } from "firebase/storage";

let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "demo-tamleek",
    firestore: {
      rules: await readFile(new URL("../../firestore.rules", import.meta.url), "utf8"),
    },
    storage: {
      rules: await readFile(new URL("../../storage.rules", import.meta.url), "utf8"),
    },
  });
});

after(async () => {
  await environment.cleanup();
});

describe("Firestore rules", () => {
  it("limits profiles to their owner and makes email read-only", async () => {
    const alice = environment
      .authenticatedContext("alice", { email: "alice@example.com" })
      .firestore();
    const ownProfile = doc(alice, "users/alice");

    await assertSucceeds(
      setDoc(ownProfile, {
        name: "Alice",
        email: "alice@example.com",
        phone: "+12345678",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(getDoc(ownProfile));
    await assertFails(getDoc(doc(alice, "users/bob")));
    await assertFails(
      updateDoc(ownProfile, {
        email: "other@example.com",
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("allows owners to read KYC but denies client writes and cross-user reads", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "kycSubmissions/alice"), {
        uid: "alice",
        identityNumber: "private",
        status: "pending",
      });
    });

    const alice = environment
      .authenticatedContext("alice")
      .firestore();
    const ownSubmission = doc(alice, "kycSubmissions/alice");
    await assertSucceeds(getDoc(ownSubmission));
    await assertFails(getDoc(doc(alice, "kycSubmissions/bob")));
    await assertFails(
      updateDoc(ownSubmission, { status: "verified" }),
    );
    await assertFails(
      setDoc(doc(alice, "kycSubmissions/bob"), {
        uid: "alice",
        status: "verified",
      }),
    );
  });
});

describe("Storage rules", () => {
  const tinyPng = Uint8Array.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  ]);
  const imageMetadata = { contentType: "image/png" };

  it("allows a user to create one private document and denies overwrite", async () => {
    const storage = environment.authenticatedContext("alice").storage();
    const ownDocument = ref(storage, "kycDocuments/alice/123-456");

    await assertSucceeds(uploadBytes(ownDocument, tinyPng, imageMetadata));
    await assertFails(uploadBytes(ownDocument, tinyPng, imageMetadata));
  });

  it("denies uploads to another user's path and oversized images", async () => {
    const storage = environment.authenticatedContext("alice").storage();
    await assertFails(
      uploadBytes(
        ref(storage, "kycDocuments/bob/123-456"),
        tinyPng,
        imageMetadata,
      ),
    );
    await assertFails(
      uploadBytes(
        ref(storage, "kycDocuments/alice/123-457"),
        new Uint8Array(5 * 1024 * 1024 + 1),
        imageMetadata,
      ),
    );
  });
});
