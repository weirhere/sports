import { NavBar } from "./nav-bar";
import { BottomTabBar } from "./bottom-tab-bar";

interface AppShellProps {
  children: React.ReactNode;
}

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="min-h-screen">
      <NavBar />
      <main className="mx-auto max-w-7xl px-4 pb-20 pt-3 sm:pb-6">
        {children}
      </main>
      <BottomTabBar />
    </div>
  );
}
