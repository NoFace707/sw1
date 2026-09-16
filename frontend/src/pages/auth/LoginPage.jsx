import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { loginUser } from "../../services/authService";


function errorMessage(error) {
  return error?.detail || "No se pudo iniciar sesión. Revisa tus datos.";
}

export default function LoginPage() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;
    setSubmitting(true);
    setError("");
    try {
      const session = await loginUser({ email, password });
      login(session, remember);
      navigate("/", { replace: true });
    } catch (requestError) {
      setError(errorMessage(requestError));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10">
      <form onSubmit={handleSubmit} className="w-full max-w-md space-y-5 rounded-3xl bg-white p-8 shadow-sm ring-1 ring-slate-200">
        <div>
          <p className="text-sm font-semibold text-teal-700">Modelador UML</p>
          <h1 className="mt-1 text-3xl font-bold text-slate-900">Iniciar sesión</h1>
          <p className="mt-2 text-sm text-slate-500">Accede con tu correo y contraseña.</p>
        </div>
        {error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-sm text-red-700">{error}</p>}
        <label className="block text-sm font-medium text-slate-700">
          Correo electrónico
          <input className="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3" type="email" autoComplete="email" required value={email} onChange={(event) => setEmail(event.target.value)} />
        </label>
        <label className="block text-sm font-medium text-slate-700">
          Contraseña
          <input className="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} />
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input type="checkbox" checked={remember} onChange={(event) => setRemember(event.target.checked)} />
          Recordarme en este navegador
        </label>
        <button className="w-full rounded-xl bg-teal-700 px-4 py-3 font-semibold text-white disabled:opacity-60" type="submit" disabled={submitting}>
          {submitting ? "Ingresando…" : "Iniciar sesión"}
        </button>
        <p className="text-center text-sm text-slate-600">¿No tienes cuenta? <Link className="font-semibold text-teal-700" to="/register">Regístrate</Link></p>
      </form>
    </main>
  );
}
