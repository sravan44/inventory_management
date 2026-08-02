/* eslint-env node */
module.exports = {
  root: true,
  env: { browser: true, es2021: true },
  parser: "@typescript-eslint/parser",
  parserOptions: { ecmaVersion: "latest", sourceType: "module", ecmaFeatures: { jsx: true } },
  settings: { react: { version: "16.14" } },
  extends: [
    "eslint:recommended",
    "plugin:react/recommended",
    "plugin:react-hooks/recommended",
  ],
  rules: {
    // New JSX transform (React 16.14+) — no need to import React in every file.
    "react/react-in-jsx-scope": "off",
  },
  ignorePatterns: ["dist", "node_modules"],
};
