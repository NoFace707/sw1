export default function PageLoader() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10" aria-live="polite">
      <div className="rounded-2xl bg-white px-10 py-8 text-center shadow-sm ring-1 ring-slate-200">
        <div className="mx-auto h-8 w-8 animate-spin rounded-full border-4 border-slate-200 border-t-teal-700" />
        <p className="mt-4 text-sm text-slate-500">Comprobando sesión…</p>
      </div>
    </main>
  );
}
