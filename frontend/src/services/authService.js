import { requestJson, requestJsonWithAuthRetry } from "./apiClient.js";
import {
  clearSession,
  getStoredSession,
  saveSession,
  updateStoredUser,
} from "./sessionStorage.js";


export function registerUser(payload) {
  return requestJson("/api/auth/register/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export function loginUser(payload) {
  return requestJson("/api/auth/login/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export function getCurrentUser() {
  return requestJsonWithAuthRetry("/api/auth/me/");
}

export function logoutUser() {
  return requestJson("/api/auth/logout/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
}

export {
  clearSession,
  getStoredSession,
  saveSession,
  updateStoredUser,
};
