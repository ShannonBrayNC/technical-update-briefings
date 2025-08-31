import * as React from "react";
export function Badge({ className = "", variant = "default", ...props }: React.HTMLAttributes<HTMLSpanElement> & { variant?: "default" | "secondary" | "outline" }) {
  const byVariant = { default: "bg-violet-600 text-white", secondary: "bg-zinc-200 text-zinc-900", outline: "border border-zinc-300 text-zinc-800", }[variant];
  return <span className={"inline-flex items-center rounded-md px-2 py-0.5 text-xs " + byVariant + " " + className} {...props} />;
}
