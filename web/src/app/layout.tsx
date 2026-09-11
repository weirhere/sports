import type { Metadata, Viewport } from "next";
import { siteUrl } from "@/lib/site";
import { APP_STORE_APP_ID } from "@/lib/app-store";
import { ThemeProvider } from "@/components/providers/theme-provider";
import { FavoritesProvider } from "@/components/providers/favorites-provider";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";

export const metadata: Metadata = {
  // Absolute URLs for anything read off-site: a link preview is built by
  // the recipient's server, which can't resolve a relative og:image.
  metadataBase: siteUrl(),
  // The 1.x name and the 1.x promise: the app has covered four leagues
  // since 2.0, and the tab it was named after is the Leagues hub now.
  title: "StatSide",
  description:
    "Fast, focused scores for college football, the NFL, the NBA and the NHL. Follow your teams, tables and games.",
  openGraph: {
    siteName: "StatSide",
    type: "website",
  },
  // X builds its card from `twitter:` tags and falls back to the `og:`
  // ones for anything missing — but NOT for the card *shape*, which has no
  // og: equivalent and defaults to `summary`: the small square thumbnail a
  // post of statside.co was wearing. One line turns every route's unfurl
  // into the full-width card the image is drawn for. No `twitter:image`
  // beside it on purpose: the fallback covers it, and a second image route
  // would be the same PNG rendered under a second URL to keep in step.
  twitter: {
    card: "summary_large_image",
  },
  // Safari's Smart App Banner — `<meta name="apple-itunes-app">`, on every
  // page. It is the native answer to the same question `GetTheAppPill`
  // asks, and the one placement Apple renders itself: a dismissible strip
  // above the page that says "Open" rather than "Get" once the app is
  // installed, which no markup of ours can know.
  //
  // No `appArgument`. That field is the URL the app is handed when the
  // banner opens it, and StatSide has nowhere to hand one: the
  // `statside://` scheme is deliberately unregistered and there are no
  // universal links yet (CLAUDE.md, 2026-08-04). A banner with no argument
  // still opens the app — it just opens it at the top.
  itunes: { appId: APP_STORE_APP_ID },
};

export const viewport: Viewport = {
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="font-sans antialiased">
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          <FavoritesProvider>
            {children}
          </FavoritesProvider>
        </ThemeProvider>
        <Analytics />
      </body>
    </html>
  );
}
