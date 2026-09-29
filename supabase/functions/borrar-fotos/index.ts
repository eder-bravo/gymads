// Borra fotos de clientes del almacenamiento (bucket `users`).
//
// La base de datos la llama (pg_net) cuando se borra un cliente, se cambia su
// foto, o en la limpieza diaria de fotos sin dueño. Borrar de storage.objects
// con SQL no sirve: Supabase lo bloquea y el archivo real se quedaría; solo la
// API de Storage lo borra de verdad, y para eso hace falta la llave de
// servicio, que esta función ya trae en su entorno (nunca sale de aquí).
//
// Se protege con un secreto compartido con la base de datos (vault), no con
// la sesión de nadie: la llama el propio servidor.
import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "users";

Deno.serve(async (req) => {
  const secreto = Deno.env.get("SECRETO_BORRADO_FOTOS");
  if (!secreto || req.headers.get("x-secreto") !== secreto) {
    return new Response("No autorizado", { status: 401 });
  }
  if (req.method !== "POST") {
    return new Response("Método no permitido", { status: 405 });
  }

  let rutas: unknown;
  try {
    ({ rutas } = await req.json());
  } catch {
    return new Response("Cuerpo inválido", { status: 400 });
  }
  // Solo fotos de clientes: `users/<archivo>`. Nada de subcarpetas raras ni de
  // salirse de esa carpeta.
  const validas = Array.isArray(rutas)
    ? rutas.filter((r): r is string =>
      typeof r === "string" && /^users\/[^/]+$/.test(r) &&
      !r.endsWith(".emptyFolderPlaceholder"))
    : [];
  if (validas.length === 0) {
    return Response.json({ borradas: 0 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let borradas = 0;
  for (let i = 0; i < validas.length; i += 100) {
    const { data, error } = await supabase.storage
      .from(BUCKET)
      .remove(validas.slice(i, i + 100));
    if (error) {
      console.error("No se pudieron borrar", error.message);
      return Response.json({ error: error.message, borradas }, { status: 500 });
    }
    borradas += data?.length ?? 0;
  }
  return Response.json({ borradas });
});
