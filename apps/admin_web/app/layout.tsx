import type { Metadata } from "next";
import { SessionProvider } from "@/components/providers/session-provider";
import "./globals.css";

export const metadata: Metadata = {
  title: "ميشوار اليمن — لوحة الإدارة",
  description: "لوحة إدارة المنصة",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
   
      <html dir="rtl" lang="ar" className="scroll-smooth">
        <head>
          <meta charSet="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <link rel="icon" href="/favicon.ico" />
        </head>
        <body className="antialiased">
          <SessionProvider>{children}</SessionProvider>
        </body>
      </html>

  );
}
