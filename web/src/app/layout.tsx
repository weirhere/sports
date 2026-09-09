import type { Metadata, Viewport } from "next";
import { siteUrl } from "@/lib/site";
import { ThemeProvider } from "@/components/providers/theme-provider";
import { FavoritesProvider } from "@/components/providers/favorites-provider";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";

export const metadata: Metadata = {
  // Absolute URLs for anything read off-site: a link preview is built by
  // the recipient's server, which can't resolve a relative og:image.
  metadataBase: siteUrl(),
  title: "College Football Hub",
  description:
    "A modern, elegant college football scores and schedule app. Track games, conferences, and your favorite teams.",
  openGraph: {
    siteName: "StatSide",
  },
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
