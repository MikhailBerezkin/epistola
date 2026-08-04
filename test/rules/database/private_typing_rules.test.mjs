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
import {fileURLToPath} from 'node:url';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  get,
  ref,
  remove,
  set,
} from 'firebase/database';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId =
    'demo-epistola-private-typing-rules-test';

const privateChatId = 'user-1_user-2';
const chatWithoutAccessId = 'user-1_user-3';

const sender = {
  uid: 'user-1',
  email: 'sender@example.com',
};

const peer = {
  uid: 'user-2',
  email: 'peer@example.com',
};

const outsider = {
  uid: 'user-3',
  email: 'outsider@example.com',
};

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: testProjectId,
    database: {
      rules: fs.readFileSync(
        path.join(projectRoot, 'database.rules.json'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await seedBaseline();
});

afterEach(async () => {
  await testEnvironment.clearDatabase();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Private typing rules', () => {
  test(
    'allows a private member to read peer typing state',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = get(
        ref(
          database,
          `privateTyping/${privateChatId}/${peer.uid}`,
        ),
      );

      await assertSucceeds(result);
    },
  );

  test(
    'rejects an outsider reading private typing state',
    async () => {
      const database = authenticatedDatabase(outsider);

      const result = get(
        ref(
          database,
          `privateTyping/${privateChatId}/${peer.uid}`,
        ),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects unauthenticated private typing reads',
    async () => {
      const database =
          testEnvironment
            .unauthenticatedContext()
            .database();

      const result = get(
        ref(
          database,
          `privateTyping/${privateChatId}/${peer.uid}`,
        ),
      );

      await assertFails(result);
    },
  );

  test(
    'allows a private member to write own typing state',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = set(
        ref(
          database,
          `privateTyping/${privateChatId}/${sender.uid}`,
        ),
        Date.now(),
      );

      await assertSucceeds(result);
    },
  );

  test(
    'rejects writing another member typing state',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = set(
        ref(
          database,
          `privateTyping/${privateChatId}/${peer.uid}`,
        ),
        Date.now(),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects writing typing without chat access',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = set(
        ref(
          database,
          `privateTyping/${chatWithoutAccessId}/${sender.uid}`,
        ),
        Date.now(),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an outsider writing own state into another chat',
    async () => {
      const database = authenticatedDatabase(outsider);

      const result = set(
        ref(
          database,
          `privateTyping/${privateChatId}/${outsider.uid}`,
        ),
        Date.now(),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects unauthenticated private typing writes',
    async () => {
      const database =
          testEnvironment
            .unauthenticatedContext()
            .database();

      const result = set(
        ref(
          database,
          `privateTyping/${privateChatId}/${sender.uid}`,
        ),
        Date.now(),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects a non-numeric typing value',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = set(
        ref(
          database,
          `privateTyping/${privateChatId}/${sender.uid}`,
        ),
        'typing',
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an outdated typing timestamp',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = set(
        ref(
          database,
          `privateTyping/${privateChatId}/${sender.uid}`,
        ),
        Date.now() - 61_000,
      );

      await assertFails(result);
    },
  );

  test(
    'rejects a typing timestamp too far in the future',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = set(
        ref(
          database,
          `privateTyping/${privateChatId}/${sender.uid}`,
        ),
        Date.now() + 11_000,
      );

      await assertFails(result);
    },
  );

  test(
    'allows a private member to remove own typing state',
    async () => {
      const database = authenticatedDatabase(peer);

      const result = remove(
        ref(
          database,
          `privateTyping/${privateChatId}/${peer.uid}`,
        ),
      );

      await assertSucceeds(result);
    },
  );

  test(
    'rejects removing another member typing state',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = remove(
        ref(
          database,
          `privateTyping/${privateChatId}/${peer.uid}`,
        ),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects client reads of private chat access data',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = get(
        ref(
          database,
          `privateChatAccess/${privateChatId}/${sender.uid}`,
        ),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects client writes to private chat access data',
    async () => {
      const database = authenticatedDatabase(sender);

      const result = set(
        ref(
          database,
          `privateChatAccess/${privateChatId}/${sender.uid}`,
        ),
        true,
      );

      await assertFails(result);
    },
  );
});

async function seedBaseline() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.database();

      await set(
        ref(
          database,
          `privateChatAccess/${privateChatId}`,
        ),
        {
          [sender.uid]: true,
          [peer.uid]: true,
        },
      );

      await set(
        ref(
          database,
          `privateTyping/${privateChatId}/${peer.uid}`,
        ),
        Date.now(),
      );
    },
  );
}

function authenticatedDatabase(user) {
  return testEnvironment
    .authenticatedContext(
      user.uid,
      {
        email: user.email,
      },
    )
    .database();
}