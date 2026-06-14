import { render, screen } from "@testing-library/react";
import App from "../App";

describe("App Component", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  test("renders without crashing", () => {
    render(<App />);
    expect(screen.getAllByText("PayNext").length).toBeGreaterThan(0);
  });

  test("renders navbar", () => {
    render(<App />);
    expect(screen.getAllByText("Pricing")[0]).toBeInTheDocument();
    expect(screen.getAllByText("Help")[0]).toBeInTheDocument();
  });

  test("shows login/register when not authenticated", () => {
    render(<App />);
    expect(screen.getByRole("button", { name: /Login/i })).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /Register/i }),
    ).toBeInTheDocument();
  });
});
