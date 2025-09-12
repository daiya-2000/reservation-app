module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
  extends: ["eslint:recommended", "google", "prettier"],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "max-len": ["error", { code: 100 }],
    "prefer-arrow-callback": "error",
    quotes: ["error", "double", { allowTemplateLiterals: true }],
    "valid-jsdoc": "off",
    "object-curly-spacing": "off",
    indent: "off",
    "operator-linebreak": "off",
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
