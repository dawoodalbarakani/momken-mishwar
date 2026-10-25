import { cookies } from "next/headers";

const TOKEN_KEY = "mishwar_admin_token";

export async function getServerToken(): Promise<string | null> {
  try {
    const cookieStore = await cookies();
    return cookieStore.get(TOKEN_KEY)?.value ?? null;
  } catch {
    return null;
  }
}
