import { createClient } from "@supabase/supabase-js";

// Proyecto de Supabase del POS (proyecto-Gavilan), el mismo que usa la app del celular.
// La llave publicable está hecha para ir en el navegador: solo permite lo que RLS deja.
const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://jveklinfbptnxmtavnez.supabase.co";
const publishableKey =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_OO3GjkywdWLVJvf_rdj0Rw_GuP5-6x7";

export const supabase = createClient(url, publishableKey);
