import { formatCurrency, formatDate, getInitials } from "../lib/utils";

describe("formatCurrency", () => {
  it("formats whole and fractional amounts with two decimals", () => {
    expect(formatCurrency(0)).toBe("$0.00");
    expect(formatCurrency(5)).toBe("$5.00");
    expect(formatCurrency(1234.5)).toBe("$1,234.50");
  });

  it("adds thousands separators", () => {
    expect(formatCurrency(1000000)).toBe("$1,000,000.00");
  });

  it("handles negative amounts", () => {
    expect(formatCurrency(-54.2)).toBe("-$54.20");
  });

  it("falls back to zero for non-finite input", () => {
    expect(formatCurrency(NaN)).toBe("$0.00");
  });
});

describe("formatDate", () => {
  it("formats an ISO date as Mon D, YYYY", () => {
    expect(formatDate("2026-06-01T09:15:00Z")).toMatch(/^Jun \d{1,2}, 2026$/);
  });

  it("returns the original string for an unparseable value", () => {
    expect(formatDate("not-a-date")).toBe("not-a-date");
  });
});

describe("getInitials", () => {
  it("returns up to two uppercase initials", () => {
    expect(getInitials("Sarah Johnson")).toBe("SJ");
    expect(getInitials("madonna")).toBe("M");
    expect(getInitials("John Ronald Reuel Tolkien")).toBe("JR");
  });

  it("returns an empty string for empty input", () => {
    expect(getInitials("")).toBe("");
  });
});
