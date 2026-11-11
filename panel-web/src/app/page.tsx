"use client";

import type { Session } from "@supabase/supabase-js";
import { useEffect, useState } from "react";
import { Dashboard } from "@/components/Dashboard";
import { Login } from "@/components/Login";
import { type Business, myBusiness } from "@/lib/data";
import { supabase } from "@/lib/supabase";

type State =
  | { kind: "loading" }
  | { kind: "signedOut" }
  | { kind: "demo" }
  | { kind: "noBusiness"; email: string }
  | { kind: "notAllowed"; business: Business }
  | { kind: "ready"; business: Business };

/** Solo el dueño y los administradores ven los reportes. */
const canSeeReports = (role: string) => role === "owner" || role === "admin";

export default function Home() {
  const [state, setState] = useState<State>({ kind: "loading" });

  useEffect(() => {
    async function follow(session: Session | null) {
      if (!session) {
        setState((s) => (s.kind === "demo" ? s : { kind: "signedOut" }));
        return;
      }
      try {
        const business = await myBusiness(supabase);
        if (!business) setState({ kind: "noBusiness", email: session.user.email ?? "" });
        else setState(canSeeReports(business.role) ? { kind: "ready", business } : { kind: "notAllowed", business });
      } catch {
        setState({ kind: "signedOut" });
      }
    }
    supabase.auth.getSession().then(({ data }) => follow(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      // Fuera del aviso: Supabase pide no llamar a la base dentro de este callback.
      setTimeout(() => follow(session), 0);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  switch (state.kind) {
    case "loading":
      return <Centered>Cargando…</Centered>;
    case "signedOut":
      return <Login onDemo={() => setState({ kind: "demo" })} />;
    case "demo":
      return <Dashboard business={null} onExit={() => setState({ kind: "signedOut" })} />;
    case "ready":
      return <Dashboard business={state.business} onExit={() => supabase.auth.signOut()} />;
    case "noBusiness":
      return (
        <Centered>
          <p className="mb-4">
            La cuenta {state.email} todavía no tiene un negocio. Ábrelo en la app del celular y enlázalo en Más → Cuenta.
          </p>
          <SignOut />
        </Centered>
      );
    case "notAllowed":
      return (
        <Centered>
          <p className="mb-4">
            Los reportes de {state.business.name} solo los ven el dueño y los administradores.
          </p>
          <SignOut />
        </Centered>
      );
  }
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <main className="flex min-h-screen items-center justify-center px-6 text-center text-[16px] text-tinta-suave">
      <div className="max-w-[420px]">{children}</div>
    </main>
  );
}

function SignOut() {
  return (
    <button
      onClick={() => supabase.auth.signOut()}
      className="rounded-full border-[1.5px] border-linea bg-superficie px-5 py-2.5 font-bold text-tinta hover:bg-hundido"
    >
      Cerrar sesión
    </button>
  );
}
