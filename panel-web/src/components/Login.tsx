"use client";

import Image from "next/image";
import { useState } from "react";
import { supabase } from "@/lib/supabase";

const authMessage = (m: string) => {
  const t = m.toLowerCase();
  if (t.includes("invalid login")) return "Correo o contraseña incorrectos.";
  if (t.includes("not confirmed")) return "Falta confirmar tu correo: abre el mensaje que te mandamos.";
  if (t.includes("rate limit")) return "Demasiados intentos. Espera unos minutos.";
  return "No se pudo entrar. Revisa tu internet e inténtalo otra vez.";
};

/** Entrada con la misma cuenta de la app del celular. */
export function Login({ onDemo }: { onDemo: () => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [working, setWorking] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setWorking(true);
    setError(null);
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (error) setError(authMessage(error.message));
    setWorking(false);
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="entrar w-full max-w-[400px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <Image src="/gavilan.png" alt="Gavilán" width={150} height={86} priority />
          <h1 className="mt-4 text-[28px] font-extrabold tracking-tight">Panel de Gavilán</h1>
          <p className="mt-1 text-[15px] text-tinta-suave">Tus ventas, en grande, desde la computadora.</p>
        </div>
        <form onSubmit={submit} className="rounded-2xl bg-superficie p-6 shadow-[0_3px_12px_rgba(27,26,25,0.06)]">
          <label className="mb-1 block text-[13px] font-semibold text-tinta-suave" htmlFor="email">
            Correo
          </label>
          <input
            id="email"
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mb-4 w-full rounded-xl border-[1.5px] border-linea px-3.5 py-3 text-[15px] outline-none focus:border-marca"
          />
          <label className="mb-1 block text-[13px] font-semibold text-tinta-suave" htmlFor="password">
            Contraseña
          </label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mb-5 w-full rounded-xl border-[1.5px] border-linea px-3.5 py-3 text-[15px] outline-none focus:border-marca"
          />
          {error && <p className="mb-4 rounded-xl bg-rojo-suave px-3 py-2.5 text-[14px] font-semibold text-rojo">{error}</p>}
          <button
            type="submit"
            disabled={working}
            className="w-full rounded-[14px] bg-marca py-3.5 text-[16px] font-bold text-white shadow-[0_5px_14px_rgba(226,88,43,0.28)] transition active:scale-[0.98] disabled:opacity-50"
          >
            {working ? "Entrando…" : "Entrar"}
          </button>
          <p className="mt-4 text-center text-[13px] text-tinta-suave">
            Usa la misma cuenta que en la app. Si no tienes, créala desde el celular en Más → Cuenta.
          </p>
        </form>
        <button
          onClick={onDemo}
          className="mt-4 w-full rounded-[14px] border-[1.5px] border-linea bg-superficie py-3 text-[15px] font-bold transition hover:bg-hundido active:scale-[0.98]"
        >
          Ver con datos de ejemplo
        </button>
      </div>
    </main>
  );
}
