module.exports = {
  extends: ["expo", "prettier"],
  rules: {
    "no-console": ["warn", { allow: ["error", "warn"] }],
  },
  overrides: [
    {
      files: ["*.config.js", "metro.config.js", "babel.config.js"],
      env: { node: true },
    },
  ],
};
