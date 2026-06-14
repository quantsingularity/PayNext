import { mockApiClient, useMockData } from "../lib/api-client";

jest.mock("@react-native-async-storage/async-storage", () => ({
  getItem: jest.fn(() => Promise.resolve(null)),
  setItem: jest.fn(() => Promise.resolve()),
  removeItem: jest.fn(() => Promise.resolve()),
}));

describe("mockApiClient", () => {
  it("defaults to mock data in development", () => {
    expect(useMockData).toBe(true);
  });

  it("logs in with credentials and returns a token and user", async () => {
    const res = await mockApiClient.login("alex@example.com", "secret");
    expect(res.success).toBe(true);
    expect(res.data?.token).toBeTruthy();
    expect(res.data?.user.email).toBe("alex@example.com");
  });

  it("rejects login with missing credentials", async () => {
    const res = await mockApiClient.login("", "");
    expect(res.success).toBe(false);
    expect(res.error?.message).toBeTruthy();
  });

  it("returns balance data", async () => {
    const res = await mockApiClient.getBalance();
    expect(res.success).toBe(true);
    expect(typeof res.data?.balance).toBe("number");
  });

  it("respects the transaction limit", async () => {
    const res = await mockApiClient.getTransactions(3);
    expect(res.success).toBe(true);
    expect(res.data?.length).toBe(3);
  });

  it("sends a payment and returns a transaction id", async () => {
    const res = await mockApiClient.sendPayment({
      recipient: "jordan@example.com",
      amount: 25,
      memo: "lunch",
    });
    expect(res.success).toBe(true);
    expect(res.data?.transactionId).toBeTruthy();
  });

  it("rejects a payment with no amount", async () => {
    const res = await mockApiClient.sendPayment({
      recipient: "jordan@example.com",
      amount: 0,
    });
    expect(res.success).toBe(false);
  });

  it("updates the profile and reflects the change", async () => {
    const res = await mockApiClient.updateUserProfile({ name: "New Name" });
    expect(res.success).toBe(true);
    expect(res.data?.name).toBe("New Name");
  });
});
