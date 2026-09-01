"use client";

// The team-search field Teams, Search, and Onboarding share — the web twin
// of the iOS `SearchField` (sports/Features/Teams/SearchField.swift).
// Escape clears before it blurs; the clear button never steals focus from
// the input.

import { useRef } from "react";
import { Search, X } from "lucide-react";
import { cn } from "@/lib/utils";

interface SearchFieldProps {
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  /** The app-wide search page grabs the keyboard on open; pinned browse
   *  fields don't (their screens are for browsing first). */
  autoFocus?: boolean;
  className?: string;
}

export function SearchField({
  value,
  onChange,
  placeholder,
  autoFocus = false,
  className,
}: SearchFieldProps) {
  const inputRef = useRef<HTMLInputElement>(null);

  return (
    <div className={cn("relative", className)}>
      <Search
        aria-hidden="true"
        className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-secondary"
      />
      <input
        ref={inputRef}
        type="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Escape" && value.length > 0) {
            e.preventDefault();
            onChange("");
          }
        }}
        placeholder={placeholder}
        aria-label={placeholder}
        autoFocus={autoFocus}
        autoComplete="off"
        autoCorrect="off"
        autoCapitalize="none"
        spellCheck={false}
        enterKeyHint="search"
        className="w-full rounded-[10px] bg-bg-elevated py-2.5 pl-9 pr-9 type-chip text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-ring [&::-webkit-search-cancel-button]:hidden [&::-webkit-search-decoration]:hidden"
      />
      {value.length > 0 && (
        <button
          type="button"
          aria-label="Clear search"
          onClick={() => {
            onChange("");
            inputRef.current?.focus();
          }}
          className="absolute right-2 top-1/2 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-full text-text-secondary transition-colors hover:text-text-primary"
        >
          <X aria-hidden="true" className="h-4 w-4" />
        </button>
      )}
    </div>
  );
}
