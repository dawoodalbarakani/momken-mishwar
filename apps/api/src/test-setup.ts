if (process.env.DATABASE_TEST_URL && !process.env.DATABASE_URL) {
  process.env.DATABASE_URL = process.env.DATABASE_TEST_URL;
}
