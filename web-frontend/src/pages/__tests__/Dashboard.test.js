import { render, screen, waitFor } from "@testing-library/react";
import { BrowserRouter } from "react-router-dom";
import Dashboard from "../Dashboard";

jest.mock("../../services/api", () => ({
  simulateApiCall: jest.fn((data, _delay = 0) => Promise.resolve({ data })),
}));

const MockDashboard = () => (
  <BrowserRouter>
    <Dashboard />
  </BrowserRouter>
);

describe("Dashboard Page", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("shows loading spinner initially", () => {
    render(<MockDashboard />);
    expect(screen.getByRole("progressbar")).toBeInTheDocument();
  });

  test("renders dashboard heading after load", async () => {
    render(<MockDashboard />);
    await waitFor(() => {
      expect(screen.getByText("Dashboard")).toBeInTheDocument();
    });
  });

  test("displays Available Balance card after load", async () => {
    render(<MockDashboard />);
    await waitFor(() => {
      expect(screen.getByText(/Available Balance/i)).toBeInTheDocument();
    });
  });

  test("displays Quick Stats section", async () => {
    render(<MockDashboard />);
    await waitFor(() => {
      expect(screen.getByText(/Quick Stats/i)).toBeInTheDocument();
      expect(screen.getByText(/Monthly Spending/i)).toBeInTheDocument();
      expect(screen.getByText(/Saved This Month/i)).toBeInTheDocument();
    });
  });

  test("displays Recent Transactions section", async () => {
    render(<MockDashboard />);
    await waitFor(() => {
      expect(screen.getByText(/Recent Transactions/i)).toBeInTheDocument();
    });
  });

  test("displays Send Money button", async () => {
    render(<MockDashboard />);
    await waitFor(() => {
      const sendButtons = screen.getAllByText(/Send Money/i);
      expect(sendButtons.length).toBeGreaterThan(0);
    });
  });
});
