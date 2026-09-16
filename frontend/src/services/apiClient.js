import {
  clearSession,
  getAccessToken,
  getRefreshToken,
  updateAccessToken,
} from "./sessionStorage.js";


function normalizeApiBaseUrl(rawValue) {
  const base = (rawValue || "http://localhost:8000").trim().replace(/\/+$/, "");
  return base.replace(/\/api$/i, "");
}

const API_BASE_URL = normalizeApiBaseUrl(import.meta.env?.VITE_API_BASE_URL);
let refreshInFlightPromise = null;

function buildUrl(endpoint) {
  if (/^https?:\/\//i.test(endpoint)) return endpoint;
  return `${API_BASE_URL}${endpoint.startsWith("/") ? endpoint : `/${endpoint}`}`;
}

async function safeParseJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

export function getApiBaseUrl() {
  return API_BASE_URL;
}

export async function request(endpoint, init = {}) {
  const headers = new Headers(init.headers || {});
  const token = getAccessToken();
  if (token && !headers.has("Authorization")) {
    headers.set("Authorization", `Bearer ${token}`);
  }
  return fetch(buildUrl(endpoint), { ...init, headers });
}

async function refreshAuthSession() {
  if (refreshInFlightPromise) return refreshInFlightPromise;
  const refresh = getRefreshToken();
  if (!refresh) throw new Error("No existe una sesión renovable.");

  refreshInFlightPromise = (async () => {
    const response = await fetch(buildUrl("/api/auth/refresh/"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh }),
    });
    const data = await safeParseJson(response);
    if (!response.ok || !data?.access) {
      clearSession();
      throw new Error(data?.detail || "No se pudo renovar la sesión.");
    }
    updateAccessToken(data.access);
    return data.access;
  })();

  try {
    return await refreshInFlightPromise;
  } finally {
    refreshInFlightPromise = null;
  }
}

export async function requestWithAuthRetry(endpoint, init = {}) {
  const response = await request(endpoint, init);
  if (response.status !== 401) return response;
  try {
    await refreshAuthSession();
  } catch {
    return response;
  }
  return request(endpoint, init);
}

export async function requestJson(endpoint, init = {}) {
  const response = await request(endpoint, init);
  const data = await safeParseJson(response);
  if (!response.ok) {
    const error = data && typeof data === "object" ? data : { detail: "No se pudo completar la solicitud." };
    error.status = response.status;
    throw error;
  }
  return data;
}

export async function requestJsonWithAuthRetry(endpoint, init = {}) {
  const response = await requestWithAuthRetry(endpoint, init);
  const data = await safeParseJson(response);
  if (!response.ok) {
    const error = data && typeof data === "object" ? data : { detail: "No se pudo completar la solicitud." };
    error.status = response.status;
    throw error;
  }
  return data;
}
