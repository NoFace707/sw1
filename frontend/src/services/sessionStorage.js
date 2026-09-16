const MODE_KEY = "auth_storage_mode";
const USER_KEY = "current_user";
const ACCESS_KEY = "auth_access_token";
const REFRESH_KEY = "auth_refresh_token";

const SESSION_MODE = "session";
const PERSISTENT_MODE = "persistent";
const SESSION_KEYS = [MODE_KEY, USER_KEY, ACCESS_KEY, REFRESH_KEY];

function availableStores() {
  if (typeof window === "undefined") return [];
  return [window.localStorage, window.sessionStorage];
}

function clearStore(store) {
  SESSION_KEYS.forEach((key) => store.removeItem(key));
}

function activeStore() {
  if (typeof window === "undefined") return null;
  if (window.localStorage.getItem(MODE_KEY) === PERSISTENT_MODE) {
    clearStore(window.sessionStorage);
    return window.localStorage;
  }
  if (window.sessionStorage.getItem(MODE_KEY) === SESSION_MODE) {
    clearStore(window.localStorage);
    return window.sessionStorage;
  }

  // Las versiones anteriores no guardaban una modalidad inequívoca.
  // Se descartan sus claves para no convertirlas en una sesión recordada.
  availableStores().forEach(clearStore);
  return null;
}

export function saveSession({ user, access, refresh }, remember = false) {
  if (typeof window === "undefined") return;
  const store = remember ? window.localStorage : window.sessionStorage;
  const other = remember ? window.sessionStorage : window.localStorage;
  clearStore(other);
  clearStore(store);
  store.setItem(MODE_KEY, remember ? PERSISTENT_MODE : SESSION_MODE);
  if (user) store.setItem(USER_KEY, JSON.stringify(user));
  if (access) store.setItem(ACCESS_KEY, access);
  if (refresh) store.setItem(REFRESH_KEY, refresh);
}

export function getStoredSession() {
  const store = activeStore();
  if (!store) return null;
  const access = store.getItem(ACCESS_KEY) || "";
  const refresh = store.getItem(REFRESH_KEY) || "";
  if (!refresh) {
    clearSession();
    return null;
  }
  let user = null;
  try {
    user = JSON.parse(store.getItem(USER_KEY) || "null");
  } catch {
    clearSession();
    return null;
  }
  return {
    user,
    access,
    refresh,
    remember: store === window.localStorage,
  };
}

export function updateStoredUser(user) {
  const store = activeStore();
  if (!store) return;
  store.setItem(USER_KEY, JSON.stringify(user));
}

export function updateAccessToken(access) {
  const store = activeStore();
  if (!store || !access) return;
  store.setItem(ACCESS_KEY, access);
}

export function getAccessToken() {
  return activeStore()?.getItem(ACCESS_KEY) || "";
}

export function getRefreshToken() {
  return activeStore()?.getItem(REFRESH_KEY) || "";
}

export function clearSession() {
  availableStores().forEach(clearStore);
}
