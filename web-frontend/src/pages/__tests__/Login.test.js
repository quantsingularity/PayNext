import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { BrowserRouter } from "react-router-dom";
import Login from "../Login";

jest.mock("../../services/api", () => ({
  authService: {
    login: jest.fn(),
  },
}));

const MockLogin = () => (
  <BrowserRouter>
    <Login onLogin={() => {}} />
  </BrowserRouter>
);

describe("Login Page", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    localStorage.clear();
  });

  test("renders login form with username field", () => {
    render(<MockLogin />);
    expect(screen.getByLabelText(/Username/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/^Password/i)).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /Sign In/i }),
    ).toBeInTheDocument();
  });

  test("shows validation error for empty fields", async () => {
    render(<MockLogin />);
    const submitButton = screen.getByRole("button", { name: /Sign In/i });
    fireEvent.click(submitButton);
    await waitFor(() => {
      expect(
        screen.getByText(/Please fill in all fields/i),
      ).toBeInTheDocument();
    });
  });

  test("shows validation error when only username is provided", async () => {
    render(<MockLogin />);
    fireEvent.change(screen.getByLabelText(/Username/i), {
      target: { value: "testuser" },
    });
    fireEvent.click(screen.getByRole("button", { name: /Sign In/i }));
    await waitFor(() => {
      expect(
        screen.getByText(/Please fill in all fields/i),
      ).toBeInTheDocument();
    });
  });

  test("renders forgot password link", () => {
    render(<MockLogin />);
    expect(screen.getByText(/Forgot password/i)).toBeInTheDocument();
  });

  test("renders sign up link", () => {
    render(<MockLogin />);
    expect(screen.getByText(/Don't have an account/i)).toBeInTheDocument();
  });

  test("password visibility toggle works", () => {
    render(<MockLogin />);
    const passwordField = screen.getByLabelText(/^Password/i);
    expect(passwordField).toHaveAttribute("type", "password");
    const toggleButton = screen.getByRole("button", {
      name: /toggle password visibility/i,
    });
    fireEvent.click(toggleButton);
    expect(passwordField).toHaveAttribute("type", "text");
  });
});
