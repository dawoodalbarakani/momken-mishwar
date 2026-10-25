import { parseJwt, type JwtPayload } from "./auth";

export interface ApiErrorBody {
  code: string;
  message_ar: string;
  message_en: string;
  request_id: string;
}

export class ApiResponseError extends Error {
  readonly code: string;
  readonly message_ar: string;
  readonly message_en: string;
  readonly request_id: string;
  readonly status: number;

  constructor(body: ApiErrorBody, status: number) {
    super(body.message_en || body.message_ar || "API error");
    this.name = "ApiResponseError";
    this.code = body.code;
    this.message_ar = body.message_ar;
    this.message_en = body.message_en;
    this.request_id = body.request_id;
    this.status = status;
  }
}

function getBaseUrl(): string {
  if (typeof process !== "undefined" && process.env.NEXT_PUBLIC_API_BASE_URL) {
    return process.env.NEXT_PUBLIC_API_BASE_URL.replace(/\/+$/, "");
  }
  return "http://localhost:4000/v1";
}

function headersWithAuth(options: RequestInit, token?: string | null): HeadersInit {
  const headers: Record<string, string> = {};
  if (options.headers) {
    if (options.headers instanceof Headers) {
      options.headers.forEach((v, k) => { headers[k] = v; });
    } else if (Array.isArray(options.headers)) {
      options.headers.forEach(([k, v]) => { headers[k] = v; });
    } else {
      Object.assign(headers, options.headers);
    }
  }
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  headers["Accept-Language"] = headers["Accept-Language"] || "ar";
  headers["Content-Type"] = headers["Content-Type"] || "application/json";
  return headers;
}

export async function apiRequest<T>(
  path: string,
  options: RequestInit & { idempotencyKey?: string; token?: string | null } = {}
): Promise<T> {
  const { idempotencyKey, token, ...fetchOptions } = options;
  const url = path.startsWith("http") ? path : `${getBaseUrl()}${path}`;
  const headers = headersWithAuth(fetchOptions, token);
  if (idempotencyKey) {
    (headers as Record<string, string>)["Idempotency-Key"] = idempotencyKey;
  }

  const res = await fetch(url, { ...fetchOptions, headers });

  if (!res.ok) {
    let body: ApiErrorBody = {
      code: res.statusText,
      message_ar: "خطأ في الاستجابة من الخادم",
      message_en: "Server response error",
      request_id: res.headers.get("x-request-id") ?? "",
    };
    try {
      const parsed = await res.json();
      if (parsed && parsed.error) {
        body = parsed.error;
      } else if (parsed && parsed.code) {
        body = parsed as unknown as ApiErrorBody;
      }
    } catch {
      // ignore parsing error
    }
    throw new ApiResponseError(body, res.status);
  }

  if (res.status === 204 || res.status === 205) {
    return undefined as unknown as T;
  }

  const text = await res.text();
  if (!text) {
    return undefined as unknown as T;
  }
  try {
    return JSON.parse(text) as T;
  } catch {
    return undefined as unknown as T;
  }
}

export function apiUrl(path: string): string {
  return path.startsWith("http") ? path : `${getBaseUrl()}${path}`;
}
