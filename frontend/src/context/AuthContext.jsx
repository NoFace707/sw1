import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import {
  clearSession,
  getCurrentUser,
  getStoredSession,
  logoutUser,
  saveSession,
  updateStoredUser,
} from "../services/authService";


const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const session = getStoredSession();
    if (!session) {
      setLoading(false);
      return;
    }
    getCurrentUser()
      .then((currentUser) => {
        updateStoredUser(currentUser);
        setUser(currentUser);
      })
      .catch(() => {
        clearSession();
        setUser(null);
      })
      .finally(() => setLoading(false));
  }, []);

  const login = useCallback((session, remember = false) => {
    saveSession(session, remember);
    setUser(session.user);
  }, []);

  const logout = useCallback(async () => {
    try {
      await logoutUser();
    } catch {
      // El cierre local siempre prevalece, incluso si el servidor no responde.
    } finally {
      clearSession();
      setUser(null);
    }
  }, []);

  const value = useMemo(() => ({ user, loading, login, logout }), [user, loading, login, logout]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth debe usarse dentro de AuthProvider");
  return context;
}
