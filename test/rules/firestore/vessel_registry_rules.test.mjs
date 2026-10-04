import {
  after,
  afterEach,
  before,
  beforeEach,
  describe,
  test,
} from 'node:test';

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId = 'epistola-vessel-registry-rules-test';

const owner = {
  uid: 'owner-1',
  email: 'owner@example.com',
};

const brigadier = {
  uid: 'brigadier-1',
  email: 'brigadier@example.com',
};

const member = {
  uid: 'member-1',
  email: 'member@example.com',
};

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: testProjectId,
    firestore: {
      rules: fs.readFileSync(
        path.join(projectRoot, 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await seedBaseline();
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Vessel registry rules', () => {
  test('allows signed-in member to read vessel', async () => {
    const db = authenticatedFirestore(member);

    await assertSucceeds(
      getDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-001',
        ),
      ),
    );
  });

  test('allows signed-in member to read line', async () => {
    const db = authenticatedFirestore(member);

    await assertSucceeds(
      getDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'lineRegistry',
          'fit',
        ),
      ),
    );
  });

  test('allows signed-in member to list vessels', async () => {
    const db = authenticatedFirestore(member);

    await assertSucceeds(
      getDocs(
        collection(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
        ),
      ),
    );
  });

  test('rejects unauthenticated vessel read', async () => {
    const db = testEnvironment
        .unauthenticatedContext()
        .firestore();

    await assertFails(
      getDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-001',
        ),
      ),
    );
  });

  test('rejects member creating vessel', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-member',
        ),
        vesselData({
          name: 'MEMBER SHIP',
          updatedBy: member.uid,
        }),
      ),
    );
  });

  test('allows brigadier creating vessel', async () => {
    const db = authenticatedFirestore(brigadier);

    await assertSucceeds(
      setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-brigadier',
        ),
        vesselData({
          name: 'BRIGADIER SHIP',
          updatedBy: brigadier.uid,
        }),
      ),
    );
  });

  test('allows owner creating vessel', async () => {
    const db = authenticatedFirestore(owner);

    await assertSucceeds(
      setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-owner',
        ),
        vesselData({
          name: 'OWNER SHIP',
          updatedBy: owner.uid,
        }),
      ),
    );
  });

  test('rejects member updating vessel', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      updateDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-001',
        ),
        {
          name: 'CHANGED BY MEMBER',
        },
      ),
    );
  });

  test('allows brigadier updating vessel', async () => {
    const db = authenticatedFirestore(brigadier);

    await assertSucceeds(
      updateDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-001',
        ),
        {
          name: 'FESCO NOVIK UPDATED',
        },
      ),
    );
  });

  test('allows owner updating line', async () => {
    const db = authenticatedFirestore(owner);

    await assertSucceeds(
      updateDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'lineRegistry',
          'fit',
        ),
        {
          defaultWorkType: 'container',
        },
      ),
    );
  });

  test('rejects member creating line', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'lineRegistry',
          'member-line',
        ),
        {
          schemaVersion: 1,
          displayName: 'MEMBER LINE',
          normalizedName: 'MEMBER LINE',
          defaultWorkType: 'other',
          isVerified: true,
          updatedBy: member.uid,
        },
      ),
    );
  });

  test('allows brigadier creating line', async () => {
    const db = authenticatedFirestore(brigadier);

    await assertSucceeds(
      setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'lineRegistry',
          'brigadier-line',
        ),
        {
          schemaVersion: 1,
          displayName: 'BRIGADIER LINE',
          normalizedName: 'BRIGADIER LINE',
          defaultWorkType: 'bulk',
          isVerified: true,
          updatedBy: brigadier.uid,
        },
      ),
    );
  });

  test('rejects brigadier deleting vessel', async () => {
    const db = authenticatedFirestore(brigadier);

    await assertFails(
      deleteDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-001',
        ),
      ),
    );
  });

  test('rejects owner deleting vessel', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      deleteDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-001',
        ),
      ),
    );
  });
});

function authenticatedFirestore(user) {
  return testEnvironment
      .authenticatedContext(
        user.uid,
        {
          email: user.email,
        },
      )
      .firestore();
}

function vesselData({
  name,
  updatedBy,
}) {
  return {
    schemaVersion: 1,
    name,
    normalizedName: name,
    lineId: 'fit',
    workType: 'container',
    isVerified: true,
    imo: null,
    lengthMeters: null,
    deadweightTons: null,
    teuCapacity: null,
    photoPath: null,
    marineTrafficUrl: null,
    updatedBy,
  };
}

async function seedBaseline() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      for (const user of [
        owner,
        brigadier,
        member,
      ]) {
        await setDoc(
          doc(db, 'users', user.uid),
          {
            uid: user.uid,
            email: user.email,
            name: user.uid,
            phone: '',
            about: '',
            avatarUrl: '',
          },
        );
      }

      await setDoc(
        doc(db, 'spaces_access', owner.uid),
        {
          role: 'owner',
        },
      );

      await setDoc(
        doc(db, 'spaces_access', brigadier.uid),
        {
          role: 'brigadier',
        },
      );

      await setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'lineRegistry',
          'fit',
        ),
        {
          schemaVersion: 1,
          displayName: 'ФИТ',
          normalizedName: 'ФИТ',
          defaultWorkType: 'container',
          isVerified: true,
          updatedBy: owner.uid,
        },
      );

      await setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'vesselRegistry',
          'vessel-001',
        ),
        vesselData({
          name: 'FESCO NOVIK',
          updatedBy: owner.uid,
        }),
      );
    },
  );
}