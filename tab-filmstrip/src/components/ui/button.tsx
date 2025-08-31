import * as React from "react";
type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "default" | "secondary" | "outline" | "ghost";
  size?: "sm" | "icon" | "md";
  asChild?: boolean;
};
export function Button({ variant = "default", size = "md", className = "", asChild, ...props }: ButtonProps) {
  const base = "inline-flex items-center justify-center rounded-lg transition";
  const byVariant = { default: "bg-violet-600 text-white hover:bg-violet-700", secondary: "bg-zinc-100 hover:bg-zinc-200 text-zinc-900", outline: "border border-zinc-300 hover:bg-zinc-100", ghost: "hover:bg-zinc-100", }[variant];
  const bySize = { sm: "h-8 px-2 text-sm", icon: "h-9 w-9", md: "h-10 px-4" }[size];
  if (asChild) return <span className={base + " " + byVariant + " " + bySize + " " + className} {...(props as any)} />;
  return <button className={base + " " + byVariant + " " + bySize + " " + className} {...props} />;
}
