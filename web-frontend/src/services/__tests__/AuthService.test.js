import AuthService from "../AuthService";
import api from "../api";

jest.mock("../api", () => ({
  post: jest.fn(),
  get: jest.fn(),
  put: jest.fn(),
  delete: jest.fn(),
  interceptors: {
    request: { use: jest.fn() },
    response: { use: jest.fn() },
  },
}));

describe("AuthService", () => {
  beforeEach(() => {
    localStorage.clear();
    jest.clearAllMocks();
  });

  describe("login", () => {
    it("should call the login API with correct credentials", async () => {
      const username = "testuser";
      const password = "password123";
      const mockResponse = {
        data: { token: "fake-token", username },
      };
      api.post.mockResolvedValue(mockResponse);

      await AuthService.login(username, password);

      expect(api.post).toHaveBeenCalledTimes(1);
      expect(api.post).toHaveBeenCalledWith("/users/login", {
        username,
        password,
      });
    });

    it("should store token in localStorage on successful login", async () => {
      const mockResponse = {
        data: { token: "fake-token", username: "testuser" },
      };
      api.post.mockResolvedValue(mockResponse);

      await AuthService.login("testuser", "password123");

      expect(localStorage.getItem("token")).toBe("fake-token");
      expect(localStorage.getItem("isAuthenticated")).toBe("true");
    });

    it("should return user data on successful login", async () => {
      const mockResponse = {
        data: { token: "fake-token", username: "testuser" },
      };
      api.post.mockResolvedValue(mockResponse);

      const result = await AuthService.login("testuser", "password123");

      expect(result).toEqual(mockResponse.data);
    });

    it("should throw an error on login API failure", async () => {
      const errorMessage = "Invalid credentials";
      api.post.mockRejectedValue(new Error(errorMessage));

      await expect(AuthService.login("testuser", "wrongpass")).rejects.toThrow(
        errorMessage,
      );
    });
  });

  describe("register", () => {
    it("should call the register API with correct user data", async () => {
      const username = "newuser";
      const email = "new@example.com";
      const password = "password123";
      const mockResponse = {
        data: { id: 1, username, email },
      };
      api.post.mockResolvedValue(mockResponse);

      await AuthService.register(username, email, password);

      expect(api.post).toHaveBeenCalledTimes(1);
      expect(api.post).toHaveBeenCalledWith("/users/register", {
        username,
        email,
        password,
      });
    });

    it("should return response data on successful registration", async () => {
      const mockResponse = {
        data: { id: 1, username: "newuser", email: "new@example.com" },
      };
      api.post.mockResolvedValue(mockResponse);

      const result = await AuthService.register(
        "newuser",
        "new@example.com",
        "password123",
      );

      expect(result).toEqual(mockResponse.data);
    });

    it("should throw an error on register API failure", async () => {
      const errorMessage = "Email already exists";
      api.post.mockRejectedValue(new Error(errorMessage));

      await expect(
        AuthService.register("newuser", "taken@example.com", "password123"),
      ).rejects.toThrow(errorMessage);
    });
  });

  describe("logout", () => {
    it("should clear authentication data from localStorage", () => {
      localStorage.setItem("token", "fake-token");
      localStorage.setItem("isAuthenticated", "true");
      localStorage.setItem("user", JSON.stringify({ username: "testuser" }));

      AuthService.logout();

      expect(localStorage.getItem("token")).toBeNull();
      expect(localStorage.getItem("isAuthenticated")).toBeNull();
      expect(localStorage.getItem("user")).toBeNull();
    });
  });

  describe("getCurrentUser", () => {
    it("should return parsed user from localStorage", () => {
      const user = { username: "testuser", email: "test@example.com" };
      localStorage.setItem("user", JSON.stringify(user));

      const result = AuthService.getCurrentUser();

      expect(result).toEqual(user);
    });

    it("should return null if no user in localStorage", () => {
      localStorage.clear();
      const result = AuthService.getCurrentUser();
      expect(result).toBeNull();
    });
  });

  describe("isAuthenticated", () => {
    it("should return true when token and flag are set", () => {
      localStorage.setItem("token", "fake-token");
      localStorage.setItem("isAuthenticated", "true");

      expect(AuthService.isAuthenticated()).toBe(true);
    });

    it("should return false when token is missing", () => {
      localStorage.setItem("isAuthenticated", "true");

      expect(AuthService.isAuthenticated()).toBe(false);
    });

    it("should return false when isAuthenticated flag is missing", () => {
      localStorage.setItem("token", "fake-token");

      expect(AuthService.isAuthenticated()).toBe(false);
    });
  });
});
