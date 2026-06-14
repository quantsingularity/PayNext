import { render, screen } from "@testing-library/react";
import { BrowserRouter } from "react-router-dom";
import Navbar from "../Navbar";

const MockNavbar = () => (
  <BrowserRouter>
    <Navbar />
  </BrowserRouter>
);

describe("Navbar Component", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  test("renders PayNext logo", () => {
    render(<MockNavbar />);
    expect(screen.getAllByText("PayNext")[0]).toBeInTheDocument();
  });

  test("renders navigation links", () => {
    render(<MockNavbar />);
    expect(screen.getAllByText("Pricing")[0]).toBeInTheDocument();
    expect(screen.getAllByText("Help")[0]).toBeInTheDocument();
  });

  test("shows Login and Register buttons when not authenticated", () => {
    render(<MockNavbar />);
    expect(screen.getByRole("button", { name: /Login/i })).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /Register/i }),
    ).toBeInTheDocument();
  });

  test("shows Dashboard button when authenticated", () => {
    localStorage.setItem("isAuthenticated", "true");
    localStorage.setItem("token", "fake-token");
    render(<MockNavbar />);
    expect(
      screen.getByRole("button", { name: /Dashboard/i }),
    ).toBeInTheDocument();
  });

  test("does not show Login button when authenticated", () => {
    localStorage.setItem("isAuthenticated", "true");
    localStorage.setItem("token", "fake-token");
    render(<MockNavbar />);
    expect(
      screen.queryByRole("button", { name: /^Login$/i }),
    ).not.toBeInTheDocument();
  });
});
