import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { registerUser } from "../../services/authService";


function errorMessage(error) {
  if (error?.detail) return error.detail;
  if (error && typeof error === "object") {
    return Object.entries(error)
      .map(([field, messages]) => `${field}: ${Array.isArray(messages) ? messages.join(" ") : messages}`)
      .join(" ");
  }
  return "No se pudo crear la cuenta.";
}

export default function RegisterPage() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [form, setForm] = useState({ first_name: "", last_name: "", email: "", password: "" });
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  function update(field) {
    return (event) => setForm((current) => ({ ...current, [field]: event.target.value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;
    setSubmitting(true);
    setError("");
    try {
      const session = await registerUser(form);
      login(session, false);
      navigate("/", { replace: true });
    } catch (requestError) {
      setError(errorMessage(requestError));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10">
      <form onSubmit={handleSubmit} className="w-full max-w-lg space-y-5 rounded-3xl bg-white p-8 shadow-sm ring-1 ring-slate-200">
        <div>
          <p className="text-sm font-semibold text-teal-700">Modelador UML</p>
          <h1 className="mt-1 text-3xl font-bold text-slate-900">Crear cuenta</h1>
          <p className="mt-2 text-sm text-slate-500">Entrarás directamente al inicio al completar el registro.</p>
        </div>
        {error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-sm text-red-700">{error}</p>}
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="text-sm font-medium text-slate-700">Nombre<input className="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3" required value={form.first_name} onChange={update("first_name")} /></label>
          <label className="text-sm font-medium text-slate-700">Apellido<input className="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3" required value={form.last_name} onChange={update("last_name")} /></label>
        </div>
        <label className="block text-sm font-medium text-slate-700">Correo electrónico<input className="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3" type="email" autoComplete="email" required value={form.email} onChange={update("email")} /></label>
        <label className="block text-sm font-medium text-slate-700">Contraseña<input className="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3" type="password" minLength="8" autoComplete="new-password" required value={form.password} onChange={update("password")} /></label>
        <button className="w-full rounded-xl bg-teal-700 px-4 py-3 font-semibold text-white disabled:opacity-60" type="submit" disabled={submitting}>{submitting ? "Creando…" : "Crear cuenta"}</button>
        <p className="text-center text-sm text-slate-600">¿Ya tienes cuenta? <Link className="font-semibold text-teal-700" to="/login">Inicia sesión</Link></p>
      </form>
    </main>
  );
}
