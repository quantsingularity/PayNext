import { render, screen, waitFor } from "@testing-library/react";
import { BrowserRouter } from "react-router-dom";
import TransactionHistory from "../TransactionHistory";
import { simulateApiCall } from "../../services/api";

jest.mock("../../services/api", () => ({
  simulateApiCall: jest.fn(),
}));

const MockTransactionHistory = () => (
  <BrowserRouter>
    <TransactionHistory />
  </BrowserRouter>
);

describe("TransactionHistory Page", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // CRA's Jest preset enables resetMocks, which clears any implementation set
    // at mock-factory time before each test. Set it here so the resolved value
    // is available when the component loads.
    simulateApiCall.mockImplementation((data) => Promise.resolve({ data }));
  });

  test("renders page title", async () => {
    render(<MockTransactionHistory />);
    await waitFor(() => {
      expect(screen.getByText("Transaction History")).toBeInTheDocument();
    });
  });

  test("renders summary cards", async () => {
    render(<MockTransactionHistory />);
    await waitFor(() => {
      expect(screen.getByText(/Total Received/i)).toBeInTheDocument();
      expect(screen.getByText(/Total Sent/i)).toBeInTheDocument();
      expect(screen.getByText(/Net Flow/i)).toBeInTheDocument();
    });
  });

  test("renders filter dropdown", async () => {
    render(<MockTransactionHistory />);
    await waitFor(() => {
      expect(screen.getByLabelText(/Filter/i)).toBeInTheDocument();
    });
  });

  test("displays transactions after loading", async () => {
    render(<MockTransactionHistory />);
    await waitFor(() => {
      expect(screen.getByText("Salary payment")).toBeInTheDocument();
      expect(screen.getByText("Coffee shop")).toBeInTheDocument();
    });
  });
});
