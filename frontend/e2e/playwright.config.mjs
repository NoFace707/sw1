import { defineConfig, devices } from "@playwright/test";

const frontendPort = process.env.E2E_FRONTEND_PORT || "5181";
const backendPort = process.env.E2E_BACKEND_PORT || "8001";
const frontendUrl = `http://localhost:${frontendPort}`;
const backendUrl = `http://127.0.0.1:${backendPort}`;

export default defineConfig({
  testDir: ".",
  timeout: 120_000,
  fullyParallel: false,
  reporter: [["list"], ["html", { outputFolder: "playwright-report", open: "never" }]],
  use: {
    baseURL: frontendUrl,
    trace: "retain-on-failure",
    serviceWorkers: "allow",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
  ],
  webServer: [
    { command: `npm run preview -- --configLoader runner --host 127.0.0.1 --port ${frontendPort}`, cwd: ".", url: `${frontendUrl}/login`, reuseExistingServer: true, timeout: 120_000 },
    { command: `python manage.py runserver 127.0.0.1:${backendPort} --noreload`, cwd: "../backend/src", url: `${backendUrl}/api/health/`, reuseExistingServer: true, timeout: 120_000, env: { DJANGO_DATABASE_ENGINE: "sqlite" } },
  ],
});
