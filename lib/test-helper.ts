import { expect, assert } from "chai";

// exception helpers

export function isException(error: Error) {
  let strError = error.toString();
  return strError.includes("invalid opcode") || strError.includes("invalid JUMP") || strError.includes("revert");
}

export function ensureException(error: Error) {
  assert(isException(error), error.toString());
}

export async function expectFailure(call: any) {
  try {
    await call;
  } catch (error) {
    return ensureException(error);
  }

  assert.fail("should fail");
}
