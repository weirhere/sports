import { NavBar } from "./nav-bar";

interface AppShellProps {
  children: React.ReactNode;
}

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="min-h-screen">
      <NavBar />
      <main className="mx-auto max-w-7xl px-4 py-6">{children}</main>
    </div>
  );
}
