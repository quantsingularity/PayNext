import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { BrowserRouter } from "react-router-dom";
import Register from "../Register";

jest.mock("../../services/api", () => ({
  authService: {
    register: jest.fn(),
  },
}));

const MockRegister = () => (
  <BrowserRouter>
    <Register />
  </BrowserRouter>
);

describe("Register Page", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("renders step 1 with username and email fields", () => {
    render(<MockRegister />);
    expect(screen.getByLabelText(/Username/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Email Address/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/^Password/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/^Confirm Password/i)).toBeInTheDocument();
  });

  test("shows stepper with 3 steps", () => {
    render(<MockRegister />);
    expect(screen.getByText("Account Information")).toBeInTheDocument();
    expect(screen.getByText("Personal Details")).toBeInTheDocument();
    expect(screen.getByText("Review & Confirm")).toBeInTheDocument();
  });

  test("shows validation error when required fields are empty", async () => {
    render(<MockRegister />);
    fireEvent.click(screen.getByRole("button", { name: /Next/i }));
    await waitFor(() => {
      expect(
        screen.getByText(/Please fill in all required fields/i),
      ).toBeInTheDocument();
    });
  });

  test("shows error when passwords do not match", async () => {
    render(<MockRegister />);
    fireEvent.change(screen.getByLabelText(/Username/i), {
      target: { value: "testuser" },
    });
    fireEvent.change(screen.getByLabelText(/Email Address/i), {
      target: { value: "test@example.com" },
    });
    fireEvent.change(screen.getByLabelText(/^Password/i), {
      target: { value: "password123" },
    });
    fireEvent.change(screen.getByLabelText(/^Confirm Password/i), {
      target: { value: "differentpass" },
    });
    fireEvent.click(screen.getByRole("button", { name: /Next/i }));
    await waitFor(() => {
      expect(screen.getByText(/Passwords do not match/i)).toBeInTheDocument();
    });
  });

  test("shows error when password is too short", async () => {
    render(<MockRegister />);
    fireEvent.change(screen.getByLabelText(/Username/i), {
      target: { value: "testuser" },
    });
    fireEvent.change(screen.getByLabelText(/Email Address/i), {
      target: { value: "test@example.com" },
    });
    fireEvent.change(screen.getByLabelText(/^Password/i), {
      target: { value: "short" },
    });
    fireEvent.change(screen.getByLabelText(/^Confirm Password/i), {
      target: { value: "short" },
    });
    fireEvent.click(screen.getByRole("button", { name: /Next/i }));
    await waitFor(() => {
      expect(
        screen.getByText(/Password must be at least 8 characters/i),
      ).toBeInTheDocument();
    });
  });

  test("renders sign in link", () => {
    render(<MockRegister />);
    expect(screen.getByText(/Already have an account/i)).toBeInTheDocument();
  });
});
