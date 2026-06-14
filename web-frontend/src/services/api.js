import axios from "axios";

const api = axios.create({
  baseURL: "/api",
  headers: {
    "Content-Type": "application/json",
  },
});

api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("token");
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error),
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      if (error.response.status === 401) {
        localStorage.removeItem("token");
        localStorage.removeItem("isAuthenticated");
        localStorage.removeItem("user");
        if (window.location.pathname !== "/login") {
          window.location.href = "/login";
        }
      }
    }
    return Promise.reject(error);
  },
);

export const authService = {
  login: async (username, password) => {
    const response = await api.post("/users/login", { username, password });
    if (response.data.token) {
      localStorage.setItem("token", response.data.token);
      localStorage.setItem("isAuthenticated", "true");
    }
    return response.data;
  },

  register: async (userData) => {
    const response = await api.post("/users/register", userData);
    return response.data;
  },

  logout: () => {
    localStorage.removeItem("token");
    localStorage.removeItem("isAuthenticated");
    localStorage.removeItem("user");
  },

  getCurrentUser: async () => {
    const response = await api.get("/users/me");
    return response.data;
  },

  isAuthenticated: () => {
    return (
      localStorage.getItem("isAuthenticated") === "true" &&
      !!localStorage.getItem("token")
    );
  },
};

export const userService = {
  getUserProfile: async () => {
    const response = await api.get("/users/profile");
    return response.data;
  },

  updateProfile: async (userData) => {
    const response = await api.put("/users/profile", userData);
    return response.data;
  },

  getTransactionHistory: async (params) => {
    const response = await api.get("/payments", { params });
    return response.data;
  },
};

export const paymentService = {
  sendMoney: async (paymentData) => {
    const response = await api.post("/payments", paymentData);
    return response.data;
  },

  getPaymentHistory: async () => {
    const response = await api.get("/payments");
    return response.data;
  },

  getBalance: async () => {
    const response = await api.get("/payments/balance");
    return response.data;
  },

  getPaymentById: async (id) => {
    const response = await api.get(`/payments/${id}`);
    return response.data;
  },

  getPaymentMethods: async () => {
    const response = await api.get("/payments/methods");
    return response.data;
  },

  addPaymentMethod: async (methodData) => {
    const response = await api.post("/payments/methods", methodData);
    return response.data;
  },
};

export const simulateApiCall = (data, delay = 1000, shouldFail = false) => {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      if (shouldFail) {
        reject(new Error("Simulated API error"));
      } else {
        resolve({ data });
      }
    }, delay);
  });
};

export default api;
