/// Proyecto de Supabase del POS (proyecto-Gavilan).
///
/// La llave publicable está hecha para ir dentro de la app: solo permite lo que las
/// reglas RLS dejan hacer a cada usuario. Las llaves secretas nunca van aquí.
abstract final class SupabaseConfig {
  static const url = 'https://jveklinfbptnxmtavnez.supabase.co';
  static const publishableKey = 'sb_publishable_OO3GjkywdWLVJvf_rdj0Rw_GuP5-6x7';
}

/// Enlaces de los correos de la cuenta. Abren la app en el celular; en Supabase deben estar
/// en Authentication → URL Configuration → Redirect URLs (`mx.gavilan.gavilan://**`).
abstract final class AuthLinks {
  static const scheme = 'mx.gavilan.gavilan';
  static const host = 'auth';
  static const confirmed = '$scheme://$host/confirmado';
  static const newPassword = '$scheme://$host/nueva-clave';
}
