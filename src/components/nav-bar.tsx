"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetTrigger,
  SheetTitle,
} from "@/components/ui/sheet";
import { ThemeToggle } from "./theme-toggle";
import { cn } from "@/lib/utils";

const NAV_LINKS = [
  { href: "/", label: "Scores" },
  { href: "/conferences", label: "Conferences" },
];

function NavLink({
  href,
  label,
  active,
  onClick,
}: {
  href: string;
  label: string;
  active: boolean;
  onClick?: () => void;
}) {
  return (
    <Link
      href={href}
      onClick={onClick}
      className={cn(
        "text-sm font-medium transition-colors hover:text-foreground",
        active ? "text-foreground" : "text-muted-foreground"
      )}
    >
      {label}
    </Link>
  );
}

export function NavBar() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="mx-auto flex h-14 max-w-7xl items-center px-4 sm:h-16">
        {/* Logo */}
        <Link href="/" className="mr-6 flex items-center gap-2">
          <span className="text-lg font-bold tracking-tight">CFB Hub</span>
        </Link>

        {/* Desktop nav */}
        <nav className="hidden items-center gap-6 sm:flex">
          {NAV_LINKS.map((link) => (
            <NavLink
              key={link.href}
              href={link.href}
              label={link.label}
              active={
                link.href === "/"
                  ? pathname === "/"
                  : pathname.startsWith(link.href)
              }
            />
          ))}
        </nav>

        {/* Right side */}
        <div className="ml-auto flex items-center gap-2">
          <ThemeToggle />

          {/* Mobile hamburger */}
          <Sheet>
            <SheetTrigger asChild className="sm:hidden">
              <Button variant="ghost" size="icon" className="h-9 w-9">
                <Menu className="h-5 w-5" />
                <span className="sr-only">Menu</span>
              </Button>
            </SheetTrigger>
            <SheetContent side="right" className="w-64">
              <SheetTitle className="text-lg font-bold">CFB Hub</SheetTitle>
              <nav className="mt-6 flex flex-col gap-4">
                {NAV_LINKS.map((link) => (
                  <NavLink
                    key={link.href}
                    href={link.href}
                    label={link.label}
                    active={
                      link.href === "/"
                        ? pathname === "/"
                        : pathname.startsWith(link.href)
                    }
                  />
                ))}
              </nav>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </header>
  );
}
