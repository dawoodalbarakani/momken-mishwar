import { middleware } from "./lib/middleware";

export { middleware };

export const config = {
  matcher: ["/", "/drivers/:path*", "/rides/:path*", "/pricing/:path*", "/finance/:path*", "/support/:path*", "/audit/:path*", "/login"],
};
