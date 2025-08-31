import * as React from "react";
export function Separator({ orientation = "horizontal", className = "", ...props }: React.HTMLAttributes<HTMLDivElement> & { orientation?: "horizontal" | "vertical" }) {
  const cls = orientation === "vertical" ? "w-px h-6 bg-zinc-300" : "h-px w-full bg-zinc-300";
  return <div className={cls + " " + className} {...props} />;
}
