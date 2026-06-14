module.exports = {
  env: {
    browser: true,
    es2021: true,
    node: true,
    jest: true,
  },
  extends: ["eslint:recommended", "plugin:react/recommended"],
  parserOptions: {
    ecmaVersion: "latest",
    sourceType: "module",
    ecmaFeatures: {
      jsx: true,
    },
  },
  plugins: ["react"],
  settings: {
    react: {
      version: "detect",
    },
  },
  rules: {
    "react/prop-types": "off",
    "no-undef": "off",
    "react/react-in-jsx-scope": "off",
    "linebreak-style": "off",
    "max-len": ["error", { code: 80 }],
    "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    "react/jsx-filename-extension": [1, { extensions: [".js", ".jsx"] }],
    "react/function-component-definition": "off", // Allows both arrow and function components
    "jsx-a11y/label-has-associated-control": "off",
    "react/button-has-type": "off",
    "react/no-deprecated": "off", // Temporarily disable if React 18 warning persists during migration
  },
};
