import { fireEvent, render, screen } from "@testing-library/react";
import { BrowserRouter } from "react-router-dom";
import SendMoney from "../SendMoney";

jest.mock("../../services/api", () => ({
  simulateApiCall: jest.fn((data) => Promise.resolve({ data })),
}));

const MockSendMoney = () => (
  <BrowserRouter>
    <SendMoney />
  </BrowserRouter>
);

describe("SendMoney Page", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("renders page title", () => {
    render(<MockSendMoney />);
    expect(screen.getByText("Send Money")).toBeInTheDocument();
  });

  test("renders recipient search field", () => {
    render(<MockSendMoney />);
    expect(
      screen.getByPlaceholderText(/Search by name or email/i),
    ).toBeInTheDocument();
  });

  test("renders list of recent recipients", () => {
    render(<MockSendMoney />);
    expect(screen.getByText("John Smith")).toBeInTheDocument();
    expect(screen.getByText("Sarah Johnson")).toBeInTheDocument();
    expect(screen.getByText("Michael Chen")).toBeInTheDocument();
  });

  test("disables Continue until a recipient is selected", async () => {
    render(<MockSendMoney />);
    // The UI guards this by disabling Continue until a recipient is chosen, so
    // the button cannot be clicked instead of surfacing an error on click.
    const continueButton = screen.getByRole("button", { name: /Continue/i });
    expect(continueButton).toBeDisabled();
  });

  test("filters recipients when searching", () => {
    render(<MockSendMoney />);
    const searchField = screen.getByPlaceholderText(/Search by name or email/i);
    // "Smith" matches only John Smith. Avoid "John", which also matches
    // "Johnson" via substring and is therefore expected, correct behavior.
    fireEvent.change(searchField, { target: { value: "Smith" } });
    expect(screen.getByText("John Smith")).toBeInTheDocument();
    expect(screen.queryByText("Sarah Johnson")).not.toBeInTheDocument();
  });

  test("shows stepper with 4 steps", () => {
    render(<MockSendMoney />);
    expect(screen.getByText("Select Recipient")).toBeInTheDocument();
    expect(screen.getByText("Enter Amount")).toBeInTheDocument();
    expect(screen.getByText("Select Payment Method")).toBeInTheDocument();
    expect(screen.getByText("Review & Confirm")).toBeInTheDocument();
  });
});
