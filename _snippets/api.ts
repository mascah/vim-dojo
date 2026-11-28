type Method = "GET" | "POST" | "PUT" | "DELETE";

interface RequestOptions {
  method?: Method;
  body?: unknown;
  token?: string;
}

const BASE_URL = "https://api.example.test/v1";

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const headers: Record<string, string> = { Accept: "application/json" };
  if (options.body !== undefined) {
    headers["Content-Type"] = "application/json";
  }
  if (options.token) {
    headers["Authorization"] = `Bearer ${options.token}`;
  }
  const response = await fetch(BASE_URL + path, {
    method: options.method ?? "GET",
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  if (!response.ok) {
    throw new Error(`request to ${path} failed with ${response.status}`);
  }
  return (await response.json()) as T;
}

export const listUsers = () => request<{ id: number; name: string }[]>("/users");
export const createUser = (name: string, token: string) =>
  request<{ id: number }>("/users", { method: "POST", body: { name }, token });
